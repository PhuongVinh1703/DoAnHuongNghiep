import os
import pandas as pd
import numpy as np
import random
from collections import Counter

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

random.seed(42)
np.random.seed(42)

records = []

# ─────────────────────────────────────────────────────────────
# NORMAL (7000 mẫu — 59%)
# ─────────────────────────────────────────────────────────────
print("Sinh dữ liệu bình thường (7000 mẫu)...")
for _ in range(7000):
    session = round(max(120, random.gauss(1500, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.30), 1)

    is_perfect = random.random() < 0.85
    cancel = 0.0 if is_perfect else round(random.uniform(0, 0.10), 4)
    add_rem = 0.0 if is_perfect else round(random.uniform(0, 0.15), 4)
    discount = 0.0 if random.random() < 0.7 else round(random.uniform(1, 15), 2)

    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(2, 10),
        "cancel_rate":                 cancel,
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  0 if random.random() < 0.9 else 1,
        "discount_percent":            discount,
        "add_remove_ratio":            add_rem,
        "items_removed_after_confirm": 0,
        "label":                       0,
        "anomaly_type":                "Normal",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 1: CancelAfterPayment (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh CancelAfterPayment (800 mẫu)...")
for _ in range(800):
    session = round(max(600, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(3, 10),
        "cancel_rate":                 round(random.uniform(0.15, 0.60), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  random.randint(0, 2),
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.1, 0.4), 4),
        "items_removed_after_confirm": random.randint(1, 5),
        "label":                       1,
        "anomaly_type":                "CancelAfterPayment",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 2: ExcessiveDiscount (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh ExcessiveDiscount (800 mẫu)...")
for _ in range(800):
    session = round(max(300, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.25), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(2, 8),
        "cancel_rate":                 0.0 if random.random() < 0.5 else round(random.uniform(0, 0.10), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  0,
        "discount_percent":            round(random.uniform(25, 100), 2),
        "add_remove_ratio":            0.0 if random.random() < 0.5 else round(random.uniform(0, 0.12), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "ExcessiveDiscount",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 3: SpeedAnomaly (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh SpeedAnomaly (800 mẫu)...")
for _ in range(800):
    speed = round(random.uniform(5, 119.0), 1)
    checkout = round(random.uniform(speed * 0.5, speed * 0.95), 1)
    is_perfect = random.random() < 0.85
    records.append({
        "session_duration":            speed,
        "num_items_ordered":           random.randint(4, 12),
        "cancel_rate":                 0.0 if is_perfect else round(random.uniform(0, 0.08), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  0,
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            0.0 if is_perfect else round(random.uniform(0, 0.08), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "SpeedAnomaly",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 4: UnusualHours (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh UnusualHours (800 mẫu)...")
unusual_hours   = [0, 1, 2, 3, 4, 5, 6, 7, 23]
unusual_weights = [3, 3, 3, 3, 3, 1, 1, 1,  4]
total_w = sum(unusual_weights)
unusual_probs = [w / total_w for w in unusual_weights]

for i in range(800):
    session  = round(max(60, random.gauss(1200, 400)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.30), 1)
    hour     = int(np.random.choice(unusual_hours, p=unusual_probs))

    if i >= 700:
        cancel  = round(random.uniform(0.15, 0.45), 4)
        add_rem = round(random.uniform(0.20, 0.50), 4)
        void    = random.randint(1, 3)
    else:
        cancel  = 0.0 if random.random() < 0.6 else round(random.uniform(0, 0.12), 4)
        add_rem = 0.0 if random.random() < 0.6 else round(random.uniform(0, 0.15), 4)
        void    = random.randint(0, 1)

    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(1, 6),
        "cancel_rate":                 cancel,
        "transaction_hour":            hour,
        "checkout_time_sec":           checkout,
        "void_count":                  void,
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            add_rem,
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "UnusualHours",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 5: FrequentCancellation (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh FrequentCancellation (800 mẫu)...")
for _ in range(800):
    session = round(max(300, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(2, 10),
        "cancel_rate":                 round(random.uniform(0.50, 1.0), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  random.randint(5, 15),
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.30, 0.65), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "FrequentCancellation",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 6: AddRemoveAnomaly (800 mẫu)
# ─────────────────────────────────────────────────────────────
print("Sinh AddRemoveAnomaly (800 mẫu)...")
for _ in range(800):
    session = round(max(600, random.gauss(3000, 800)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    removed_after = 0 if random.random() < 0.70 else random.randint(1, 2)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(3, 10),
        "cancel_rate":                 round(random.uniform(0.25, 0.45), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  0,
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.70, 1.0), 4),
        "items_removed_after_confirm": removed_after,
        "label":                       1,
        "anomaly_type":                "AddRemoveAnomaly",
    })

# ─────────────────────────────────────────────────────────────
# BỔ SUNG: Cross-hour anomaly samples (160 mẫu)
# ─────────────────────────────────────────────────────────────
print("Bổ sung cross-hour samples (160 mẫu)...")
unusual_hours_cross = [0, 1, 2, 3, 4, 5, 6, 7, 23]

for _ in range(80):
    session  = round(max(600, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(3, 10),
        "cancel_rate":                 round(random.uniform(0.15, 0.60), 4),
        "transaction_hour":            random.choice(unusual_hours_cross),
        "checkout_time_sec":           checkout,
        "void_count":                  random.randint(0, 2),
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.1, 0.4), 4),
        "items_removed_after_confirm": random.randint(1, 5),
        "label":                       1,
        "anomaly_type":                "CancelAfterPayment",
    })

for _ in range(80):
    session  = round(max(300, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.25), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(2, 8),
        "cancel_rate":                 0.0 if random.random() < 0.5 else round(random.uniform(0, 0.10), 4),
        "transaction_hour":            random.choice(unusual_hours_cross),
        "checkout_time_sec":           checkout,
        "void_count":                  0,
        "discount_percent":            round(random.uniform(25, 100), 2),
        "add_remove_ratio":            0.0 if random.random() < 0.5 else round(random.uniform(0, 0.12), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "ExcessiveDiscount",
    })

df = pd.DataFrame(records)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)
out_csv = os.path.join(BASE_DIR, "training_data.csv")
df.to_csv(out_csv, index=False)

print(f"\n✅ Tổng: {len(df)} mẫu — Đã lưu tại {out_csv}")