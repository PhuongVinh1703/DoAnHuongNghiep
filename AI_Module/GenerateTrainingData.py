"""
GenerateTrainingData.py  v4.1 — Fixed UnusualHours + Cross-hour Anomalies
Sửa đổi so với v3.0:
  1. Tách session_duration và checkout_time_sec thành 2 feature độc lập
  2. Giảm overlap FrequentCancellation vs AddRemoveAnomaly bằng void_count
  3. AddRemoveAnomaly: 30% mẫu có items_removed_after_confirm > 0
  4. FrequentCancellation: void_count min 5, cancel_rate min 0.50
  5. AddRemoveAnomaly: cancel_rate max 0.45, void_count = 0
Sửa riêng UnusualHours (v4.1):
  6. Weighted sampling: ưu tiên 0-4h và 23h hơn 5-7h
  7. 100/800 mẫu combo UnusualHours + hành vi bất thường khác
  8. CancelAfterPayment và ExcessiveDiscount: 10% mẫu có giờ bất thường
     → model học multi-label thay vì shortcut "giờ lạ = chỉ UnusualHours"
"""

import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

records = []

# ─────────────────────────────────────────────────────────────
# NORMAL (7000 mẫu — 59%)
# session_duration: thời gian từ lúc mở bàn đến thanh toán
# checkout_time_sec: thời gian riêng để hoàn tất giao dịch (luôn nhỏ hơn session)
# ─────────────────────────────────────────────────────────────
print("Sinh dữ liệu bình thường (7000 mẫu)...")
for _ in range(7000):
    session = round(max(120, random.gauss(1500, 600)), 1)
    # checkout_time_sec: thời gian bấm thanh toán, chỉ chiếm 5-30% session
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
# Đặc trưng BẢN CHẤT: items_removed_after_confirm > 0
# Nhân viên xóa món SAU khi khách đã confirm/thanh toán → ăn tiền chênh lệch
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
        "items_removed_after_confirm": random.randint(1, 5),  # KEY FEATURE
        "label":                       1,
        "anomaly_type":                "CancelAfterPayment",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 2: ExcessiveDiscount (800 mẫu)
# Đặc trưng BẢN CHẤT: discount_percent > 25%
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
        "discount_percent":            round(random.uniform(25, 100), 2),  # KEY FEATURE
        "add_remove_ratio":            0.0 if random.random() < 0.5 else round(random.uniform(0, 0.12), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "ExcessiveDiscount",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 3: SpeedAnomaly (800 mẫu)
# Đặc trưng BẢN CHẤT: session_duration < 30 giây VÀ checkout_time_sec < 30 giây
# Toàn bộ session quá nhanh (mở bàn → chọn món → thanh toán chỉ vài giây)
# ─────────────────────────────────────────────────────────────
print("Sinh SpeedAnomaly (800 mẫu)...")
for _ in range(800):
    speed = round(random.uniform(5, 29), 1)
    # checkout cũng rất nhanh (phần lớn thời gian session)
    checkout = round(random.uniform(speed * 0.5, speed * 0.95), 1)
    is_perfect = random.random() < 0.85
    records.append({
        "session_duration":            speed,   # KEY FEATURE: < 30s
        "num_items_ordered":           random.randint(4, 12),
        "cancel_rate":                 0.0 if is_perfect else round(random.uniform(0, 0.08), 4),
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,  # KEY FEATURE: cũng rất nhỏ
        "void_count":                  0,
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            0.0 if is_perfect else round(random.uniform(0, 0.08), 4),
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "SpeedAnomaly",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 4: UnusualHours (800 mẫu)
# Đặc trưng BẢN CHẤT: transaction_hour trong 0-7 hoặc 23
#
# FIX v4.1:
# - Tách 800 mẫu thành 2 nhóm để phản ánh thực tế:
#     + 700 mẫu ONLY UnusualHours: các feature khác bình thường
#     + 100 mẫu combo UnusualHours + hành vi khác (cancel/add_rem bất thường)
#   Điều này giúp model detect UnusualHours kể cả khi đi kèm anomaly khác.
# - Dùng np.random.choice với weights để ưu tiên giờ đêm sâu (0-4h)
#   vì thực tế gian lận ban đêm hay xảy ra lúc nửa đêm hơn là 7h sáng.
# ─────────────────────────────────────────────────────────────
print("Sinh UnusualHours (800 mẫu)...")

# Giờ bất thường: 0-7 và 23. Ưu tiên giờ đêm sâu (0-4h) và 23h hơn sáng sớm (5-7h)
unusual_hours   = [0, 1, 2, 3, 4, 5, 6, 7, 23]
unusual_weights = [3, 3, 3, 3, 3, 1, 1, 1,  4]   # 23h và 0-4h xuất hiện nhiều hơn 5-7h
total_w = sum(unusual_weights)
unusual_probs = [w / total_w for w in unusual_weights]

for i in range(800):
    session  = round(max(60, random.gauss(1200, 400)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.30), 1)
    hour     = int(np.random.choice(unusual_hours, p=unusual_probs))

    # 100 mẫu cuối: combo với hành vi bất thường khác (thực tế hay xảy ra)
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
        "transaction_hour":            hour,          # KEY FEATURE
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
# Đặc trưng BẢN CHẤT: void_count CAO (5-15) VÀ cancel_rate CAO (0.50-1.0)
# Hủy cả đơn nhiều lần trong ca, thêm lại rồi hủy → quay vòng hóa đơn
# FIX v4.0: tăng void_count min lên 5, tăng cancel_rate min lên 0.50
#            giới hạn add_remove_ratio max xuống 0.65 để tránh overlap ARA
# ─────────────────────────────────────────────────────────────
print("Sinh FrequentCancellation (800 mẫu)...")
for _ in range(800):
    session = round(max(300, random.gauss(2400, 600)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(2, 10),
        "cancel_rate":                 round(random.uniform(0.50, 1.0), 4),   # FIX: min 0.50
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  random.randint(5, 15),                  # FIX: min 5, max 15
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.30, 0.65), 4),   # FIX: max 0.65
        "items_removed_after_confirm": 0,
        "label":                       1,
        "anomaly_type":                "FrequentCancellation",
    })

# ─────────────────────────────────────────────────────────────
# ANOMALY 6: AddRemoveAnomaly (800 mẫu)
# Đặc trưng BẢN CHẤT: add_remove_ratio CAO (0.70-1.0), void_count = 0
# Thêm rồi xóa từng món liên tục để quay vòng bill, KHÔNG hủy cả đơn
# FIX v4.0: void_count = 0 (luôn), tăng add_remove_ratio min lên 0.70
#            cancel_rate max 0.45, 30% mẫu có items_removed_after_confirm > 0
# ─────────────────────────────────────────────────────────────
print("Sinh AddRemoveAnomaly (800 mẫu)...")
for _ in range(800):
    session = round(max(600, random.gauss(3000, 800)), 1)
    checkout = round(random.uniform(session * 0.05, session * 0.20), 1)
    # 30% mẫu ARA cũng xóa sau confirm (overlap có kiểm soát với CancelAfterPayment)
    removed_after = 0 if random.random() < 0.70 else random.randint(1, 2)
    records.append({
        "session_duration":            session,
        "num_items_ordered":           random.randint(3, 10),
        "cancel_rate":                 round(random.uniform(0.25, 0.45), 4),   # FIX: max 0.45
        "transaction_hour":            random.randint(8, 22),
        "checkout_time_sec":           checkout,
        "void_count":                  0,                                       # FIX: luôn = 0
        "discount_percent":            0.0 if random.random() < 0.5 else round(random.uniform(1, 10), 2),
        "add_remove_ratio":            round(random.uniform(0.70, 1.0), 4),    # FIX: min 0.70
        "items_removed_after_confirm": removed_after,
        "label":                       1,
        "anomaly_type":                "AddRemoveAnomaly",
    })


# ─────────────────────────────────────────────────────────────
# BỔ SUNG: Cross-hour anomaly samples (FIX v4.1)
# CancelAfterPayment và ExcessiveDiscount cũng xảy ra ngoài giờ (10% mẫu)
# Giúp model học: giờ bất thường KHÔNG nhất thiết = UnusualHours duy nhất
# ─────────────────────────────────────────────────────────────
print("Bổ sung cross-hour samples (160 mẫu)...")
unusual_hours_cross = [0, 1, 2, 3, 4, 5, 6, 7, 23]

# 80 mẫu CancelAfterPayment lúc giờ bất thường
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
        "anomaly_type":                "CancelAfterPayment",  # label chính, không phải UH
    })

# 80 mẫu ExcessiveDiscount lúc giờ bất thường
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
        "anomaly_type":                "ExcessiveDiscount",   # label chính
    })

df = pd.DataFrame(records)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)
df.to_csv("training_data.csv", index=False)

print(f"\n✅ Tổng: {len(df)} mẫu")
print(df["anomaly_type"].value_counts())

print("\n--- Kiểm tra overlap sau khi sửa ---")
fc  = df[df["anomaly_type"] == "FrequentCancellation"]
ara = df[df["anomaly_type"] == "AddRemoveAnomaly"]

overlap_cancel = ((fc["cancel_rate"] >= 0.45) & (fc["cancel_rate"] <= 0.50)).sum()
overlap_addrem = ((ara["add_remove_ratio"] >= 0.65) & (ara["add_remove_ratio"] <= 0.70)).sum()
fc_void_ok  = (fc["void_count"] >= 5).mean() * 100
ara_void_ok = (ara["void_count"] == 0).mean() * 100

print(f"FC  cancel_rate ≥ 0.50 (không overlap ARA): {(fc['cancel_rate'] >= 0.50).mean()*100:.1f}%")
print(f"ARA cancel_rate ≤ 0.45 (không overlap FC) : {(ara['cancel_rate'] <= 0.45).mean()*100:.1f}%")
print(f"FC  void_count ≥ 5: {fc_void_ok:.1f}%")
print(f"ARA void_count = 0: {ara_void_ok:.1f}%")
print(f"ARA add_remove_ratio ≥ 0.70: {(ara['add_remove_ratio'] >= 0.70).mean()*100:.1f}%")

session_eq_checkout = (df["session_duration"] == df["checkout_time_sec"]).sum()
print(f"\nsession_duration == checkout_time_sec: {session_eq_checkout}/{len(df)} ({session_eq_checkout/len(df)*100:.1f}%)")
print("✅ Lý tưởng là 0% (hai feature độc lập)")


print("\n--- Kiểm tra UnusualHours phân phối giờ ---")
uh = df[df["anomaly_type"] == "UnusualHours"]
from collections import Counter
hour_dist = Counter(uh["transaction_hour"].tolist())
for h in sorted(hour_dist.keys()):
    pct = hour_dist[h] / len(uh) * 100
    print(f"  Giờ {h:2d}h: {hour_dist[h]:3d} mẫu ({pct:.1f}%)")

print("\n--- Kiểm tra cross-hour samples ---")
cap_unusual = df[(df["anomaly_type"]=="CancelAfterPayment") & (df["transaction_hour"].isin(unusual_hours_cross))]
exc_unusual = df[(df["anomaly_type"]=="ExcessiveDiscount")  & (df["transaction_hour"].isin(unusual_hours_cross))]
print(f"  CancelAfterPayment ở giờ bất thường: {len(cap_unusual)} mẫu")
print(f"  ExcessiveDiscount  ở giờ bất thường: {len(exc_unusual)} mẫu")

print("\n✅ Đã lưu training_data.csv")