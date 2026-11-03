# DESIGN SYSTEM & VOCABULARY: NHÀ HÀNG & QUÁN ĂN AI

> **Tài liệu quy chuẩn thiết kế UI/UX theo triết lý Impeccable (pbakaus) & Taste-Skill (Leonxlnx)**  
> Ứng dụng: `DoAnQuanLyQuanAnAI_MobileApp`  
> Phiên bản: 2.0 (Chuẩn Nhà Hàng Vận Hành)

---

## 1. TRIẾT LÝ NGHỆ THUẬT THEO ĐẶC THÙ NGÀNH (F&B ART DIRECTION)

Không dùng các mẫu thiết kế chung chung (Anti-AI-Slop). Ứng dụng phục vụ 3 nhóm người dùng với 3 bối cảnh thực tế khác biệt:

### ① Màn hình Bếp KDS (Kitchen Display System) — *Bold & Ergonomic*
- **Bối cảnh:** Môi trường bếp nóng, nhiều khói, ánh đèn vàng/trắng mạnh, đầu bếp tay dính dầu mỡ, nhìn màn hình từ khoảng cách 1 – 2 mét.
- **Nguyên tắc:**
  - **Tương phản cực cao (High Contrast):** Nền trắng/xám sáng, viền đậm dứt khoát.
  - **Typography to, rõ:** Tên bàn, số lượng món (`2x`, `3x`) dùng font weight `800+`, cỡ tối thiểu `15–18sp`.
  - **Ghi chú dị ứng/món ăn phải nổi bật (Critical Highlighting):** Thẻ màu vàng/cam đậm cho các ghi chú *"Không hành"*, *"Dị ứng đậu phộng"*, *"Ít cay"*.
  - **Touch Target:** Vùng bấm báo xong món tối thiểu **48x48dp**, có phản hồi xúc giác mạnh (`AppHaptics.heavy()`).
  - **Cảnh báo thời gian:** Đơn chờ > 15 phút phải có thẻ báo động thời gian màu cam/đỏ.

### ② Màn hình Vận hành Quầy & Bàn (Staff POS / Thu ngân / Phục vụ) — *Dense & Fast*
- **Bối cảnh:** Nhân viên di chuyển liên tục, thao tác một tay trên điện thoại khi đứng tại bàn khách.
- **Nguyên tắc:**
  - **Tối ưu một tay (One-handed Ergonomics):** Các nút hành động chính (Gọi thêm món, Báo tính tiền, Đổi bàn) đặt ở nửa dưới màn hình hoặc Bottom Sheet cố định.
  - **Sơ đồ bàn:** Trạng thái bàn (Trống, Đang có khách, Đã đặt) nhận biết ngay qua màu sắc và icon thời gian ngồi.
  - **Định dạng tiền tệ:** Luôn có dấu phân cách hàng nghìn và hậu tố `đ` (vd: `150.000đ`), cỡ chữ giá tiền phân cấp rõ ràng.

### ③ Màn hình Quản lý & Cảnh báo AI Anomaly — *Distilled & Decisive*
- **Bối cảnh:** Chủ quán / Quản lý chi nhánh cần phát hiện gian lận và sự cố trong vòng 3 giây.
- **Nguyên tắc:**
  - **Tinh giản (Distilled):** Không nhồi nhét log kỹ thuật. Nổi bật 3 thông tin cốt lõi: **Loại gian lận** (Speed Anomaly / Hủy món / Giảm giá quá mức), **Mức độ rủi ro** (HIGH / MEDIUM / LOW), và **Bàn / Hóa đơn** liên quan.
  - **Thanh đo độ tin cậy (Confidence Meter):** Đo lường trực quan % rủi ro kèm màu cảnh báo ngữ nghĩa.

---

## 2. BỘ TỪ VỰNG CHỈ ĐẠO (AGENT STEERING VOCABULARY)

Khi yêu cầu AI chỉnh sửa giao diện, sử dụng các từ vựng chuẩn xác sau:

- **`/bolder`:** Tăng cường độ tương phản, làm dày font chữ, phóng to số lượng món, đẩy mạnh màu sắc viền thẻ để nhìn rõ từ xa.
- **`/quieter`:** Giảm độ chói, gỡ bỏ các gradient màu mè không cần thiết, làm mềm nền thẻ phụ để tập trung vào nội dung chính.
- **`/distill`:** Cắt tỉa chi tiết rườm rà trên thẻ thống kê/cảnh báo, gom nhóm dữ liệu liên quan, đưa con số quan trọng nhất lên đầu.
- **`/polish`:** Chuẩn hóa bo góc (`BorderRadius.circular(12|16)`), cân chỉnh padding (8, 12, 16, 24), thêm hiệu ứng rung phản hồi (`AppHaptics`).
- **`/audit`:** Rà soát tiêu chuẩn tiếp cận: kích thước vùng bấm (Touch Target ≥ 48dp), tỉ lệ tương phản màu (Contrast Ratio ≥ 4.5:1), trạng thái rỗng (`_EmptyState`) và hiệu ứng loading shimmer.

---

## 3. ANTI-SLOP RULES (NHỮNG ĐIỀU TUYỆT ĐỐI TRÁNH)

1. ❌ **Cấm dùng Gradient tím-xanh rập khuôn của AI:** Bảng màu nhà hàng là Đỏ Cam ấm (`AppColors.primary`), Xanh lá hoàn thành (`#16A34A`), Vàng cảnh báo (`#D97706`), Xám bề mặt sạch sẽ.
2. ❌ **Cấm thẻ lồng thẻ vô nghĩa (Card Nesting Soup):** Không bọc thẻ trong thẻ quá 2 lớp; sử dụng viền nhẹ và khoảng cách dòng thay vì thêm box nền.
3. ❌ **Cấm phím bấm nhỏ dưới 48dp:** Mọi nút bấm trong giao diện vận hành nhân viên phải có chiều cao tối thiểu 44–48dp để tránh bấm nhầm lúc vội.
4. ❌ **Cấm bỏ quên trạng thái rỗng / lỗi:** Mọi danh sách (bàn, đơn, cảnh báo) luôn có giao diện Empty State thân thiện kèm icon minh họa.
