"""
predict_api.py v2.0
- Trả về đúng loại bất thường trong số 6 loại
- Có endpoint /retrain để train lại khi có dữ liệu mới
"""

from flask import Flask, request, jsonify
import pickle
import numpy as np
import os
import subprocess
import threading

app = Flask(__name__)

# ── Load model ────────────────────────────────────────────────
def load_models():
    global binary_model, multi_model, scaler, label_encoder
    try:
        with open("binary_model.pkl",  "rb") as f: binary_model  = pickle.load(f)
        with open("multi_model.pkl",   "rb") as f: multi_model   = pickle.load(f)
        with open("scaler.pkl",        "rb") as f: scaler        = pickle.load(f)
        with open("label_encoder.pkl", "rb") as f: label_encoder = pickle.load(f)
        print("✅ Models đã load xong!")
        return True
    except Exception as ex:
        print(f"❌ Lỗi load model: {ex}")
        return False

binary_model  = None
multi_model   = None
scaler        = None
label_encoder = None

if not load_models():
    print("Chạy train_model.py trước!")
    exit(1)

FEATURES = [
    "session_duration", "num_items_ordered", "cancel_rate",
    "transaction_hour", "checkout_time_sec", "void_count",
    "discount_percent", "add_remove_ratio"
]

print("✅ API đang chạy tại http://localhost:5050")
print("   Giữ cửa sổ này mở khi dùng app POS\n")


# ── /health ──────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":        "ok",
        "model_version": "2.0",
        "anomaly_types": list(label_encoder.classes_) if label_encoder else []
    })


# ── /predict ─────────────────────────────────────────────────
@app.route("/predict", methods=["POST"])
def predict():
    """
    Input JSON:
    {
      "staff_id": 3,
      "session_duration": 1200,
      "num_items_ordered": 5,
      "cancel_rate": 0.1,
      "transaction_hour": 14,
      "checkout_time_sec": 180,
      "void_count": 0,
      "discount_percent": 0,
      "add_remove_ratio": 0.05
    }

    Output JSON:
    {
      "is_anomaly": true,
      "anomaly_score": 0.87,
      "risk_level": "HIGH",
      "anomaly_type": "SpeedAnomaly",
      "status": "ok"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"status": "error", "message": "Body rỗng"}), 400

        fv = [[
            float(data.get("session_duration",   0)),
            float(data.get("num_items_ordered",  1)),
            float(data.get("cancel_rate",        0)),
            float(data.get("transaction_hour",   12)),
            float(data.get("checkout_time_sec",  180)),
            float(data.get("void_count",         0)),
            float(data.get("discount_percent",   0)),
            float(data.get("add_remove_ratio",   0)),
        ]]

        X_scaled   = scaler.transform(fv)

        # Bước 1: Binary — có bất thường không?
        is_anomaly = int(binary_model.predict(X_scaled)[0]) == 1
        proba      = float(binary_model.predict_proba(X_scaled)[0][1])
        risk       = "HIGH"   if proba >= 0.75 else \
                     "MEDIUM" if proba >= 0.50 else "LOW"

        # Bước 2: Multiclass — loại bất thường nào?
        anomaly_type = "Normal"
        if is_anomaly:
            type_idx     = int(multi_model.predict(X_scaled)[0])
            anomaly_type = label_encoder.inverse_transform([type_idx])[0]

        staff_id = data.get("staff_id", "?")
        print(f"[Predict] Staff={staff_id} | Score={proba:.4f} | "
              f"Risk={risk} | Type={anomaly_type}")

        return jsonify({
            "is_anomaly":   is_anomaly,
            "anomaly_score": round(proba, 4),
            "risk_level":   risk,
            "anomaly_type": anomaly_type,
            "status":       "ok"
        })

    except Exception as ex:
        print(f"[Error] {ex}")
        return jsonify({"status": "error", "message": str(ex)}), 500


# ── /feedback — lưu feedback của Owner để retrain sau ────────
@app.route("/feedback", methods=["POST"])
def feedback():
    """
    Owner xác nhận/bác bỏ cảnh báo → lưu vào file để retrain
    Input:
    {
      "features": {...},
      "actual_label": 1,
      "actual_type": "SpeedAnomaly"
    }
    """
    try:
        data = request.get_json()

        import csv, os
        file_exists = os.path.exists("feedback_data.csv")
        with open("feedback_data.csv", "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=FEATURES + ["label", "anomaly_type"])
            if not file_exists:
                writer.writeheader()

            features = data.get("features", {})
            row = {feat: features.get(feat, 0) for feat in FEATURES}
            row["label"]        = data.get("actual_label", 0)
            row["anomaly_type"] = data.get("actual_type", "Normal")
            writer.writerow(row)

        return jsonify({"status": "ok", "message": "Đã lưu feedback"})
    except Exception as ex:
        return jsonify({"status": "error", "message": str(ex)}), 500


# ── /retrain — train lại model với dữ liệu mới ───────────────
_retrain_lock   = threading.Lock()
_retrain_status = {"status": "idle", "message": ""}

@app.route("/retrain", methods=["POST"])
def retrain():
    """
    Gộp feedback_data.csv vào training_data.csv rồi train lại
    Chạy ngầm, không block API
    """
    if not _retrain_lock.acquire(blocking=False):
        return jsonify({"status": "busy", "message": "Đang retrain, vui lòng đợi..."})

    def do_retrain():
        global binary_model, multi_model, scaler, label_encoder
        try:
            _retrain_status["status"]  = "running"
            _retrain_status["message"] = "Đang gộp dữ liệu..."

            import pandas as pd

            # Gộp feedback nếu có
            if os.path.exists("feedback_data.csv"):
                df_old      = pd.read_csv("training_data.csv")
                df_feedback = pd.read_csv("feedback_data.csv")
                df_new      = pd.concat([df_old, df_feedback], ignore_index=True)
                df_new.to_csv("training_data.csv", index=False)
                os.remove("feedback_data.csv")
                print(f"[Retrain] Gộp {len(df_feedback)} feedback mới")

            _retrain_status["message"] = "Đang train..."
            subprocess.run(["python", "train_model.py"], check=True)

            # Reload model sau khi train xong
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


# ── Run ──────────────────────────────────────────────────────
if __name__ == "__main__":
    app.run(host="localhost", port=5050, debug=False)
