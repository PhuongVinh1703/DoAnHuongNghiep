"""
train_model.py  v3.0
Train 2 model phát hiện gian lận nhà hàng:
  1. Binary classifier  : Normal vs Anomaly
  2. Multiclass classifier: Phân loại 6 loại bất thường

FEATURES (9 đặc trưng — thêm items_removed_after_confirm so với v2):
  session_duration, num_items_ordered, cancel_rate, transaction_hour,
  checkout_time_sec, void_count, discount_percent, add_remove_ratio,
  items_removed_after_confirm
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, roc_auc_score
import pickle
import json

print("=" * 60)
print("  TRAINING ANOMALY DETECTION MODEL v3.0 (6 LOẠI)")
print("=" * 60)

# ── 1. Load dữ liệu ───────────────────────────────────────────
print("\n[1/6] Load dữ liệu...")
df = pd.read_csv("training_data.csv")
print(f"     Tổng: {len(df)} mẫu")
print(df["anomaly_type"].value_counts())

FEATURES = [
    "session_duration",
    "num_items_ordered",
    "cancel_rate",
    "transaction_hour",
    "checkout_time_sec",
    "void_count",
    "discount_percent",
    "add_remove_ratio",
    "items_removed_after_confirm",   # Feature mới — phân biệt CancelAfterPayment
]

# Kiểm tra tất cả feature tồn tại
missing = [f for f in FEATURES if f not in df.columns]
if missing:
    raise ValueError(f"Thiếu feature trong CSV: {missing}\n"
                     f"Hãy chạy lại GenerateTrainingData.py trước!")

X            = df[FEATURES]
y_binary     = df["label"]
y_multiclass = df["anomaly_type"]

# ── 2. Scale ──────────────────────────────────────────────────
print("\n[2/6] Chuẩn hóa dữ liệu...")
scaler   = StandardScaler()
X_scaled = scaler.fit_transform(X)

# ── 3. Train Binary (Normal vs Anomaly) ───────────────────────
print("\n[3/6] Training Binary Classifier...")
X_tr, X_te, y_tr, y_te = train_test_split(
    X_scaled, y_binary, test_size=0.2, random_state=42, stratify=y_binary)

binary_model = RandomForestClassifier(
    n_estimators=200,
    max_depth=12,
    min_samples_leaf=5,
    class_weight="balanced",
    random_state=42,
    n_jobs=-1,
)
binary_model.fit(X_tr, y_tr)

y_pred  = binary_model.predict(X_te)
y_proba = binary_model.predict_proba(X_te)[:, 1]
auc     = roc_auc_score(y_te, y_proba)
cv      = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
cv_f1   = cross_val_score(binary_model, X_scaled, y_binary,
                          cv=cv, scoring="f1").mean()

print(classification_report(y_te, y_pred, target_names=["Normal", "Anomaly"]))
print(f"AUC-ROC : {auc:.4f}")
print(f"CV F1   : {cv_f1:.4f}")

# ── 4. Train Multiclass (6 loại anomaly) ──────────────────────
print("\n[4/6] Training Multiclass Classifier (6 loại)...")

df_anomaly    = df[df["label"] == 1].copy()
X_anomaly     = scaler.transform(df_anomaly[FEATURES])
y_anomaly     = df_anomaly["anomaly_type"]

le            = LabelEncoder()
y_anomaly_enc = le.fit_transform(y_anomaly)

print(f"     Các lớp: {list(le.classes_)}")
print(f"     Phân phối:\n{pd.Series(y_anomaly).value_counts()}")

X_tr2, X_te2, y_tr2, y_te2 = train_test_split(
    X_anomaly, y_anomaly_enc,
    test_size=0.2, random_state=42, stratify=y_anomaly_enc)

multi_model = RandomForestClassifier(
    n_estimators=300,
    max_depth=15,
    min_samples_leaf=3,
    class_weight="balanced",
    random_state=42,
    n_jobs=-1,
)
multi_model.fit(X_tr2, y_tr2)

y_pred2 = multi_model.predict(X_te2)
print(classification_report(y_te2, y_pred2, target_names=le.classes_))

# ── 5. Feature importance ─────────────────────────────────────
print("\n[5/6] Mức độ quan trọng các đặc trưng (binary model):")
imp = sorted(zip(FEATURES, binary_model.feature_importances_),
             key=lambda x: x[1], reverse=True)
for feat, score in imp:
    bar = "█" * int(score * 50)
    print(f"  {feat:<32} {score:.4f}  {bar}")

# ── 6. Lưu model ──────────────────────────────────────────────
print("\n[6/6] Lưu model...")

with open("binary_model.pkl",  "wb") as f: pickle.dump(binary_model, f)
with open("multi_model.pkl",   "wb") as f: pickle.dump(multi_model,  f)
with open("scaler.pkl",        "wb") as f: pickle.dump(scaler,       f)
with open("label_encoder.pkl", "wb") as f: pickle.dump(le,           f)
with open("anomaly_model.pkl", "wb") as f: pickle.dump(binary_model, f)  # tương thích ngược

config = {
    "features":                  FEATURES,
    "anomaly_threshold":         0.5,
    "high_risk":                 0.75,
    "anomaly_types":             list(le.classes_),
    "model_version":             "3.0",
    "auc_score":                 round(auc,   4),
    "cv_f1_mean":                round(cv_f1, 4),
    "training_samples":          len(df),
    "anomaly_samples":           int((y_binary == 1).sum()),
}
with open("model_config.json", "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("✅ binary_model.pkl")
print("✅ multi_model.pkl")
print("✅ scaler.pkl")
print("✅ label_encoder.pkl")
print("✅ model_config.json")

print("\n" + "=" * 60)
print("  TRAINING HOÀN THÀNH!")
print(f"  Binary AUC  : {auc:.4f}")
print(f"  Binary CV F1: {cv_f1:.4f}")
print(f"  Anomaly types: {list(le.classes_)}")
print("=" * 60)
