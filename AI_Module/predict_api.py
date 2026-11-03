from flask import Flask, request, jsonify
import pickle
import numpy as np
import os
import sys
import subprocess
import threading

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Cấu hình ngưỡng nghiệp vụ (đồng bộ giữa AI Module và Mobile App) ──────
UNUSUAL_HOURS                = set(list(range(0, 8)) + [23])  # giờ bất thường: 0-7h và 23h
EXCESSIVE_DISCOUNT_THRESHOLD = 25.0                           # giảm giá >= 25% là bất thường
SPEED_ANOMALY_SEC            = 120.0                          # mở bàn -> thanh toán < 120s
FREQUENT_VOID_MIN            = 5                              # số lần hủy món >= 5
FREQUENT_CANCEL_RATE_MIN     = 0.50                           # tỷ lệ hủy đơn >= 50%
ADD_REMOVE_RATIO_MIN         = 0.70                           # tỷ lệ thêm/xóa >= 70%


# ── Load model ─────────────────────────────────────────────────
def load_models():
    global binary_model, multi_model, scaler, label_encoder
    try:
        with open(os.path.join(BASE_DIR, "binary_model.pkl"),  "rb") as f:
            binary_model = pickle.load(f)
        with open(os.path.join(BASE_DIR, "multi_model.pkl"),   "rb") as f:
            multi_model = pickle.load(f)
        with open(os.path.join(BASE_DIR, "scaler.pkl"),        "rb") as f:
            scaler = pickle.load(f)
        with open(os.path.join(BASE_DIR, "label_encoder.pkl"), "rb") as f:
            label_encoder = pickle.load(f)
        print(f"✅ Models đã load xong! (version: {getattr(binary_model, 'n_estimators', '?')} trees)")
        return True
    except Exception as ex:
        print(f"❌ Lỗi load model: {ex}")
        return False


binary_model  = None
multi_model   = None
scaler        = None
label_encoder = None

if not load_models():
    print("Chạy GenerateTrainingData.py rồi train_model.py trước!")
    exit(1)

# 9 features — thứ tự phải khớp chính xác với train_model.py
FEATURES = [
    "session_duration",
    "num_items_ordered",
    "cancel_rate",
    "transaction_hour",
    "checkout_time_sec",
    "void_count",
    "discount_percent",
    "add_remove_ratio",
    "items_removed_after_confirm",
]

# Ánh xạ tên tiếng Anh → tiếng Việt để hiển thị cho user
ANOMALY_TYPE_VN = {
    "CancelAfterPayment":   "Hủy món sau xác nhận",
    "ExcessiveDiscount":    "Lạm dụng giảm giá",
    "SpeedAnomaly":         "Thanh toán siêu tốc",
    "UnusualHours":         "Giao dịch ngoài giờ",
    "FrequentCancellation": "Hủy bill liên tục",
    "AddRemoveAnomaly":     "Thêm/xóa món bất thường",
    "Normal":               "Bình thường",
}

print("✅ API sẵn sàng phục vụ (Port 5050)")


# ── /health ────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":        "ok",
        "model_version": "3.1",
        "features":      FEATURES,
        "anomaly_types": list(label_encoder.classes_) if label_encoder else [],
        "unusual_hours": sorted(list(UNUSUAL_HOURS)),
        "excessive_discount_threshold": EXCESSIVE_DISCOUNT_THRESHOLD,
    })


# ── /predict ───────────────────────────────────────────────────
@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"status": "error", "message": "Body rỗng"}), 400

        session_duration            = float(data.get("session_duration",            0))
        num_items_ordered           = float(data.get("num_items_ordered",           1))
        cancel_rate                 = float(data.get("cancel_rate",                 0))
        tx_hour                     = float(data.get("transaction_hour",           12))
        checkout_time_sec           = float(data.get("checkout_time_sec",         300))
        void_count                  = float(data.get("void_count",                  0))
        discount_pct                = float(data.get("discount_percent",            0))
        add_remove_ratio            = float(data.get("add_remove_ratio",            0))
        items_removed_after_confirm = float(data.get("items_removed_after_confirm", 0))

        fv = [[
            session_duration,
            num_items_ordered,
            cancel_rate,
            tx_hour,
            checkout_time_sec,
            void_count,
            discount_pct,
            add_remove_ratio,
            items_removed_after_confirm,
        ]]

        X_scaled = scaler.transform(fv)

        # ── Bước 1: Binary — có bất thường không? ──────────────
        is_anomaly = int(binary_model.predict(X_scaled)[0]) == 1
        proba      = float(binary_model.predict_proba(X_scaled)[0][1])

        # ── Bước 2: Multi-class — AI phân loại loại lỗi ────────
        anomalies   = []
        multi_proba = None

        if is_anomaly and hasattr(multi_model, "predict_proba"):
            multi_proba = multi_model.predict_proba(X_scaled)[0]
            for idx, p in enumerate(multi_proba):
                if p > 0.25:
                    anomaly_type = label_encoder.inverse_transform([idx])[0]
                    anomalies.append({
                        "type":    anomaly_type,
                        "type_vn": ANOMALY_TYPE_VN.get(anomaly_type, anomaly_type),
                        "score":   round(float(p), 4),
                        "source":  "ai",
                    })

        # ── Bước 3: Fallback nếu AI không tìm được loại vượt 0.25 ──
        if not anomalies and is_anomaly:
            type_idx     = int(multi_model.predict(X_scaled)[0])
            anomaly_type = label_encoder.inverse_transform([type_idx])[0]
            anomalies.append({
                "type":    anomaly_type,
                "type_vn": ANOMALY_TYPE_VN.get(anomaly_type, anomaly_type),
                "score":   round(float(multi_proba[type_idx]), 4) if multi_proba is not None else round(proba, 4),
                "source":  "ai",
            })

        # ── Bước 4: Hybrid Rule-Based (Đủ 6 Luật Thép Nghiệp Vụ) ──
        rules_triggered = []

        def upsert_rule_anomaly(anom_type: str, rule_score: float):
            for existing in anomalies:
                if existing["type"] == anom_type:
                    if rule_score > existing["score"]:
                        existing["score"] = round(rule_score, 4)
                    return
            anomalies.append({
                "type":    anom_type,
                "type_vn": ANOMALY_TYPE_VN.get(anom_type, anom_type),
                "score":   round(rule_score, 4),
                "source":  "rule",
            })

        # Rule 4.1: Hủy/xóa món sau khi đã xác nhận gửi bếp (CancelAfterPayment)
        if items_removed_after_confirm > 0:
            is_anomaly = True
            rules_triggered.append("CancelAfterPayment")
            rule_score = min(0.99, 0.92 + 0.02 * min(items_removed_after_confirm, 3))
            upsert_rule_anomaly("CancelAfterPayment", rule_score)

        # Rule 4.2: Thanh toán siêu tốc (Session duration < 120 giây)
        if 0 < session_duration < SPEED_ANOMALY_SEC:
            is_anomaly = True
            rules_triggered.append("SpeedAnomaly")
            upsert_rule_anomaly("SpeedAnomaly", 0.95)

        # Rule 4.3: Giảm giá vượt ngưỡng (>= 25%)
        if discount_pct >= EXCESSIVE_DISCOUNT_THRESHOLD:
            is_anomaly = True
            rules_triggered.append("ExcessiveDiscount")
            rule_score = min(0.99, round(0.85 + (discount_pct - 25.0) / 500.0, 4))
            upsert_rule_anomaly("ExcessiveDiscount", rule_score)

        # Rule 4.4: Giao dịch ngoài giờ làm việc (0h-7h hoặc 23h)
        if int(tx_hour) in UNUSUAL_HOURS:
            is_anomaly = True
            rules_triggered.append("UnusualHours")
            rule_score = 0.92 if int(tx_hour) in {0, 1, 2, 3, 4, 23} else 0.78
            upsert_rule_anomaly("UnusualHours", rule_score)

        # Rule 4.5: Hủy bill / hủy món liên tục (void_count >= 5 và cancel_rate >= 50%)
        if void_count >= FREQUENT_VOID_MIN and cancel_rate >= FREQUENT_CANCEL_RATE_MIN:
            is_anomaly = True
            rules_triggered.append("FrequentCancellation")
            upsert_rule_anomaly("FrequentCancellation", 0.90)

        # Rule 4.6: Thêm/xóa món bất thường (add_remove_ratio >= 70%)
        if add_remove_ratio >= ADD_REMOVE_RATIO_MIN:
            is_anomaly = True
            rules_triggered.append("AddRemoveAnomaly")
            upsert_rule_anomaly("AddRemoveAnomaly", 0.85)

        # Sắp xếp danh sách bất thường theo điểm số giảm dần để lỗi nghiêm trọng nhất đứng đầu
        anomalies.sort(key=lambda a: a["score"], reverse=True)

        # ── Bước 5: Tính điểm bất thường tổng hợp & phân loại mức độ rủi ro ──
        max_rule_score = max((a["score"] for a in anomalies), default=0.0)
        final_proba    = max(proba, max_rule_score) if is_anomaly else proba

        if not is_anomaly:
            risk = "LOW"
        elif final_proba >= 0.75:
            risk = "HIGH"
        elif final_proba >= 0.50:
            risk = "MEDIUM"
        else:
            risk = "LOW"

        staff_id = data.get("staff_id", "?")
        print(
            f"[Predict] Staff={staff_id} | AI_Score={proba:.4f} | Final_Score={final_proba:.4f} | "
            f"Risk={risk} | Anomalies={len(anomalies)} | Rules={rules_triggered}"
        )

        return jsonify({
            "is_anomaly":      is_anomaly,
            "anomaly_score":   round(final_proba, 4),
            "ai_score":        round(proba, 4),
            "risk_level":      risk,
            "anomalies":       anomalies,
            "rules_triggered": rules_triggered,
            "status":          "ok",
        })

    except Exception as ex:
        print(f"[Error] {ex}")
        return jsonify({"status": "error", "message": str(ex)}), 500


# ── /feedback ─────────────────────────────────────────────────
@app.route("/feedback", methods=["POST"])
def feedback():
    """
    Owner/Manager xác nhận hoặc bác bỏ cảnh báo → lưu vào feedback_data.csv để retrain sau.
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"status": "error", "message": "Body rỗng"}), 400

        import csv
        feedback_path = os.path.join(BASE_DIR, "feedback_data.csv")
        file_exists   = os.path.exists(feedback_path)
        fieldnames    = FEATURES + ["label", "anomaly_type"]

        with open(feedback_path, "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            if not file_exists:
                writer.writeheader()

            features = data.get("features", {})
            row = {feat: features.get(feat, 0) for feat in FEATURES}
            row["label"]        = data.get("actual_label", 0)
            row["anomaly_type"] = data.get("actual_type",  "Normal")
            writer.writerow(row)

        return jsonify({"status": "ok", "message": "Đã lưu feedback"})

    except Exception as ex:
        return jsonify({"status": "error", "message": str(ex)}), 500


# ── /retrain ──────────────────────────────────────────────────
_retrain_lock   = threading.Lock()
_retrain_status = {"status": "idle", "message": ""}


@app.route("/retrain", methods=["POST"])
def retrain():
    """
    Gộp feedback_data.csv vào training_data.csv rồi train lại model.
    Chạy ngầm trong background thread, không block API.
    """
    if not _retrain_lock.acquire(blocking=False):
        return jsonify({"status": "busy", "message": "Đang retrain, vui lòng đợi..."})

    def do_retrain():
        try:
            _retrain_status["status"]  = "running"
            _retrain_status["message"] = "Đang gộp dữ liệu..."

            import pandas as pd

            feedback_path = os.path.join(BASE_DIR, "feedback_data.csv")
            training_path = os.path.join(BASE_DIR, "training_data.csv")

            if os.path.exists(feedback_path):
                df_old      = pd.read_csv(training_path)
                df_feedback = pd.read_csv(feedback_path)
                df_new      = pd.concat([df_old, df_feedback], ignore_index=True)
                df_new.to_csv(training_path, index=False)
                os.remove(feedback_path)
                print(f"[Retrain] Gộp {len(df_feedback)} feedback mới")

            _retrain_status["message"] = "Đang train..."
            subprocess.run(
                [sys.executable, os.path.join(BASE_DIR, "train_model.py")],
                cwd=BASE_DIR,
                check=True,
            )

            load_models()
            _retrain_status["status"]  = "done"
            _retrain_status["message"] = "Retrain thành công!"
            print("[Retrain] Hoàn thành!")

        except Exception as ex:
            _retrain_status["status"]  = "error"
            _retrain_status["message"] = str(ex)
            print(f"[Retrain] Lỗi: {ex}")
        finally:
            _retrain_lock.release()

    threading.Thread(target=do_retrain, daemon=True).start()
    return jsonify({"status": "started", "message": "Đang retrain trong nền..."})


@app.route("/retrain/status", methods=["GET"])
def retrain_status():
    return jsonify(_retrain_status)


# ── Run ───────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5050))
    app.run(host="0.0.0.0", port=port, debug=False)