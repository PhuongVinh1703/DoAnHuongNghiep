from flask import Flask, request, jsonify
import pickle
import numpy as np
import os
import subprocess
import threading

app = Flask(__name__)

# ── Cấu hình giờ làm việc (sửa tại đây nếu quán đổi giờ) ──────
# Thay vì hardcode 2 nơi (training + API), chỉ khai báo 1 lần ở đây
UNUSUAL_HOURS     = set(list(range(0, 8)) + [23])   # giờ bất thường: 0-7h và 23h
EXCESSIVE_DISCOUNT_THRESHOLD = 25.0                  # giảm giá > 25% là bất thường

# ── Load model ─────────────────────────────────────────────────
def load_models():
    global binary_model, multi_model, scaler, label_encoder
    try:
        with open("binary_model.pkl",  "rb") as f: binary_model  = pickle.load(f)
        with open("multi_model.pkl",   "rb") as f: multi_model   = pickle.load(f)
        with open("scaler.pkl",        "rb") as f: scaler        = pickle.load(f)
        with open("label_encoder.pkl", "rb") as f: label_encoder = pickle.load(f)
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
    "CancelAfterPayment":   "Hủy sau khi khách trả tiền",
    "ExcessiveDiscount":    "Lạm dụng giảm giá",
    "SpeedAnomaly":         "Thanh toán siêu tốc",
    "UnusualHours":         "Giao dịch ngoài giờ",
    "FrequentCancellation": "Hủy bill liên tục",
    "AddRemoveAnomaly":     "Thêm/xóa món bất thường",
    "Normal":               "Bình thường",
}

print("✅ API đang chạy tại http://localhost:5050")
print("   Giữ cửa sổ này mở khi dùng app POS\n")


# ── /health ────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":        "ok",
        "model_version": "3.0",
        "features":      FEATURES,
        "anomaly_types": list(label_encoder.classes_) if label_encoder else [],
        # Trả về config giờ để client có thể hiển thị đúng
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

        tx_hour      = float(data.get("transaction_hour", 12))
        discount_pct = float(data.get("discount_percent", 0))

        fv = [[
            float(data.get("session_duration",            0)),
            float(data.get("num_items_ordered",           1)),
            float(data.get("cancel_rate",                 0)),
            tx_hour,
            float(data.get("checkout_time_sec",           300)),
            float(data.get("void_count",                  0)),
            discount_pct,
            float(data.get("add_remove_ratio",            0)),
            float(data.get("items_removed_after_confirm", 0)),
        ]]

        X_scaled = scaler.transform(fv)

        # ── Bước 1: Binary — có bất thường không? ──────────────
        is_anomaly = int(binary_model.predict(X_scaled)[0]) == 1
        proba      = float(binary_model.predict_proba(X_scaled)[0][1])
        risk       = "HIGH"   if proba >= 0.75 else \
                     "MEDIUM" if proba >= 0.50 else "LOW"

        # ── Bước 2: Multi-class — AI phân loại loại lỗi ────────
        anomalies   = []
        multi_proba = None

        if is_anomaly and hasattr(multi_model, 'predict_proba'):
            multi_proba = multi_model.predict_proba(X_scaled)[0]
            for idx, p in enumerate(multi_proba):
                if p > 0.25:
                    anomaly_type = label_encoder.inverse_transform([idx])[0]
                    anomalies.append({
                        "type":     anomaly_type,
                        "type_vn":  ANOMALY_TYPE_VN.get(anomaly_type, anomaly_type),
                        "score":    round(float(p), 4),
                        "source":   "ai",       # đánh dấu nguồn gốc: AI tự phát hiện
                    })

        # ── Bước 3: Fallback nếu AI không tìm được loại ────────
        if not anomalies and is_anomaly:
            type_idx     = int(multi_model.predict(X_scaled)[0])
            anomaly_type = label_encoder.inverse_transform([type_idx])[0]
            anomalies.append({
                "type":    anomaly_type,
                "type_vn": ANOMALY_TYPE_VN.get(anomaly_type, anomaly_type),
                "score":   round(float(multi_proba[type_idx]), 4) if multi_proba is not None else 0.0,
                "source":  "ai",
            })

        # ── Bước 4: Hybrid Rule-Based (Luật Thép) ──────────────
        # Xử lý các trường hợp AI bị "chia xác suất" khi combo nhiều lỗi.
        # Rule không ghi đè score AI, không làm méo audit log.
        rules_triggered = []

        # Rule 4.1: Giao dịch ngoài giờ làm việc
        if int(tx_hour) in UNUSUAL_HOURS:
            is_anomaly = True
            rules_triggered.append("UnusualHours")

            # Chỉ thêm vào list nếu AI chưa phát hiện (tránh trùng)
            if not any(a["type"] == "UnusualHours" for a in anomalies):
                anomalies.append({
                    "type":    "UnusualHours",
                    "type_vn": ANOMALY_TYPE_VN["UnusualHours"],
                    # Score theo mức độ nguy hiểm thực tế của từng giờ:
                    # 0h-4h và 23h nguy hiểm hơn 5h-7h (sắp mở cửa)
                    "score":   0.95 if int(tx_hour) in {0, 1, 2, 3, 4, 23} else 0.75,
                    "source":  "rule",   # đánh dấu nguồn gốc: luật thép
                })

            # Nâng risk tối thiểu lên MEDIUM (không ép HIGH vì 23h có thể dọn dẹp quán)
            if risk == "LOW":
                risk = "MEDIUM"

        # Rule 4.2: Giảm giá vượt ngưỡng
        if discount_pct >= EXCESSIVE_DISCOUNT_THRESHOLD:
            is_anomaly = True
            rules_triggered.append("ExcessiveDiscount")

            if not any(a["type"] == "ExcessiveDiscount" for a in anomalies):
                # Score tỷ lệ thuận với mức discount: 25%→0.75, 50%→0.875, 100%→0.99
                rule_score = min(0.99, round(0.75 + (discount_pct - 25) / 300, 4))
                anomalies.append({
                    "type":    "ExcessiveDiscount",
                    "type_vn": ANOMALY_TYPE_VN["ExcessiveDiscount"],
                    "score":   rule_score,
                    "source":  "rule",
                })

            if risk == "LOW":
                risk = "MEDIUM"

        # ── Bước 5: Tính proba cuối để trả về ──────────────────
        # Giữ nguyên AI score (proba) làm điểm chính cho audit log.
        # Nếu rule can thiệp mà AI không phát hiện (proba thấp),
        # lấy score của rule cao nhất nhưng KHÔNG vượt quá 0.74
        # (để phân biệt với HIGH-risk thật sự từ AI).
        final_proba = proba
        if rules_triggered and proba < 0.50:
            rule_scores = [a["score"] for a in anomalies if a.get("source") == "rule"]
            if rule_scores:
                # Cap ở 0.60: đủ để hiển thị MEDIUM, không giả mạo HIGH
                final_proba = min(0.60, max(rule_scores))

        staff_id = data.get("staff_id", "?")
        print(
            f"[Predict] Staff={staff_id} | AI_Score={proba:.4f} | "
            f"Risk={risk} | Anomalies={len(anomalies)} | Rules={rules_triggered}"
        )

        return jsonify({
            "is_anomaly":    is_anomaly,
            "anomaly_score": round(final_proba, 4),
            "ai_score":      round(proba, 4),       # score thuần AI, dùng cho audit
            "risk_level":    risk,
            "anomalies":     anomalies,             # mỗi phần tử có thêm "source": "ai"/"rule"
            "rules_triggered": rules_triggered,     # danh sách rule đã kích hoạt
            "status":        "ok",
        })

    except Exception as ex:
        print(f"[Error] {ex}")
        return jsonify({"status": "error", "message": str(ex)}), 500


# ── /feedback ─────────────────────────────────────────────────
@app.route("/feedback", methods=["POST"])
def feedback():
    """
    Owner xác nhận/bác bỏ cảnh báo → lưu vào file để retrain sau.
    Input:
    {
      "features":     { <9 feature như /predict> },
      "actual_label": 1,
      "actual_type":  "SpeedAnomaly"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"status": "error", "message": "Body rỗng"}), 400

        import csv
        file_exists = os.path.exists("feedback_data.csv")
        fieldnames  = FEATURES + ["label", "anomaly_type"]

        with open("feedback_data.csv", "a", newline="", encoding="utf-8") as f:
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
        global binary_model, multi_model, scaler, label_encoder
        try:
            _retrain_status["status"]  = "running"
            _retrain_status["message"] = "Đang gộp dữ liệu..."

            import pandas as pd

            if os.path.exists("feedback_data.csv"):
                df_old      = pd.read_csv("training_data.csv")
                df_feedback = pd.read_csv("feedback_data.csv")
                df_new      = pd.concat([df_old, df_feedback], ignore_index=True)
                df_new.to_csv("training_data.csv", index=False)
                os.remove("feedback_data.csv")
                print(f"[Retrain] Gộp {len(df_feedback)} feedback mới")

            _retrain_status["message"] = "Đang train..."
            subprocess.run(["python", "train_model.py"], check=True)

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
    app.run(host="localhost", port=5050, debug=False)