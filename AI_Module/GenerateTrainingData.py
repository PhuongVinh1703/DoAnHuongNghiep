"""
GenerateTrainingData.py
Sinh dữ liệu training với 6 loại bất thường khớp với AlertType trong C#:
  0 = Normal (Bình thường)
  1 = CancelAfterPayment  (Hủy sau khi khách đưa tiền)
  2 = ExcessiveDiscount   (Lạm dụng giảm giá)
  3 = SpeedAnomaly        (Thanh toán quá nhanh)
  4 = UnusualHours        (Giao dịch giờ bất thường)
  5 = FrequentCancellation(Hủy bill liên tục)
  6 = AddRemoveAnomaly    (Thêm xóa món bất thường → map vào FrequentCancellation)
"""

import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

records = []

# ── NORMAL (70%) ──────────────────────────────────────────────────────────────
print("Sinh dữ liệu bình thường (7000 mẫu)...")
for _ in range(7000):
    records.append({
        "session_duration":  max(60,  random.gauss(1200, 300)),
        "num_items_ordered": random.randint(2, 8),
        "cancel_rate":       round(random.uniform(0, 0.10), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        random.randint(0, 1),
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0, 0.15), 4),
        "label":             0,   # Normal
        "anomaly_type":      "Normal"
    })

# ── ANOMALY TYPE 1: CancelAfterPayment (Hủy sau thanh toán) ──────────────────
print("Sinh CancelAfterPayment (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  max(60, random.gauss(1200, 300)),
        "num_items_ordered": random.randint(2, 8),
        "cancel_rate":       round(random.uniform(0.5, 1.0), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        random.randint(3, 10),
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0, 0.2), 4),
        "label":             1,
        "anomaly_type":      "CancelAfterPayment"
    })

# ── ANOMALY TYPE 2: ExcessiveDiscount (Lạm dụng giảm giá) ────────────────────
print("Sinh ExcessiveDiscount (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  max(60, random.gauss(1200, 300)),
        "num_items_ordered": random.randint(2, 8),
        "cancel_rate":       round(random.uniform(0, 0.1), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        0,
        "discount_percent":  round(random.uniform(30, 100), 2),
        "add_remove_ratio":  round(random.uniform(0, 0.15), 4),
        "label":             1,
        "anomaly_type":      "ExcessiveDiscount"
    })

# ── ANOMALY TYPE 3: SpeedAnomaly (Thanh toán quá nhanh) ───────────────────────
print("Sinh SpeedAnomaly (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  round(random.uniform(3, 25), 1),
        "num_items_ordered": random.randint(1, 3),
        "cancel_rate":       round(random.uniform(0, 0.1), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": round(random.uniform(3, 20), 1),
        "void_count":        0,
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0, 0.1), 4),
        "label":             1,
        "anomaly_type":      "SpeedAnomaly"
    })

# ── ANOMALY TYPE 4: UnusualHours (Giao dịch ngoài giờ) ───────────────────────
print("Sinh UnusualHours (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  max(60, random.gauss(1200, 300)),
        "num_items_ordered": random.randint(1, 5),
        "cancel_rate":       round(random.uniform(0, 0.1), 4),
        "transaction_hour":  random.choice(list(range(0, 7)) + [23]),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        0,
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0, 0.15), 4),
        "label":             1,
        "anomaly_type":      "UnusualHours"
    })

# ── ANOMALY TYPE 5: FrequentCancellation (Hủy bill liên tục) ─────────────────
print("Sinh FrequentCancellation (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  max(60, random.gauss(1200, 300)),
        "num_items_ordered": random.randint(2, 8),
        "cancel_rate":       round(random.uniform(0.5, 1.0), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        random.randint(4, 10),
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0, 0.2), 4),
        "label":             1,
        "anomaly_type":      "FrequentCancellation"
    })

# ── ANOMALY TYPE 6: AddRemoveAnomaly (Thêm xóa món liên tục) ─────────────────
print("Sinh AddRemoveAnomaly (500 mẫu)...")
for _ in range(500):
    records.append({
        "session_duration":  max(60, random.gauss(1200, 300)),
        "num_items_ordered": random.randint(2, 8),
        "cancel_rate":       round(random.uniform(0.4, 0.9), 4),
        "transaction_hour":  random.randint(9, 22),
        "checkout_time_sec": max(30, random.gauss(180, 60)),
        "void_count":        random.randint(0, 2),
        "discount_percent":  0,
        "add_remove_ratio":  round(random.uniform(0.6, 1.0), 4),
        "label":             1,
        "anomaly_type":      "FrequentCancellation"  # map vào FrequentCancellation
    })

# ── Shuffle và lưu ────────────────────────────────────────────────────────────
df = pd.DataFrame(records)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)
df.to_csv("training_data.csv", index=False)

print(f"\n✅ Tổng: {len(df)} mẫu")
print(df["anomaly_type"].value_counts())
print("\n✅ Đã lưu training_data.csv")
