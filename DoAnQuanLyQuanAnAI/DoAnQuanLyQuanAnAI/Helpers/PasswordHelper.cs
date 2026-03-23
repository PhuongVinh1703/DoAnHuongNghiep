using System;

namespace DoAnQuanLyQuanAnAI.Helpers
{
    /// <summary>
    /// Xử lý mật khẩu an toàn bằng BCrypt
    /// - Salt ngẫu nhiên riêng cho mỗi user (không hardcode)
    /// - Work factor 12 (2^12 = 4096 vòng lặp) — cân bằng bảo mật/tốc độ
    /// </summary>
    public static class PasswordHelper
    {
        private const int WorkFactor = 12;

        /// <summary>
        /// Hash mật khẩu bằng BCrypt với salt ngẫu nhiên
        /// Mỗi lần gọi cho ra hash khác nhau (salt nhúng trong chuỗi kết quả)
        /// </summary>
        public static string Hash(string password)
        {
            if (string.IsNullOrEmpty(password))
                throw new ArgumentException("Mật khẩu không được để trống!");

            return BCrypt.Net.BCrypt.HashPassword(password, WorkFactor);
        }

        /// <summary>
        /// Kiểm tra mật khẩu khớp với hash đã lưu
        /// BCrypt tự trích xuất salt từ chuỗi hash để so sánh
        /// </summary>
        public static bool Verify(string password, string hash)
        {
            if (string.IsNullOrEmpty(password) || string.IsNullOrEmpty(hash))
                return false;

            try
            {
                // Hỗ trợ cả hash BCrypt mới lẫn SHA256 cũ (migration tương thích ngược)
                if (hash.StartsWith("$2"))
                    return BCrypt.Net.BCrypt.Verify(password, hash);

                // Hash cũ dạng SHA256 — chấp nhận để không khoá tài khoản cũ
                return LegacySha256Verify(password, hash);
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Kiểm tra xem hash này có phải BCrypt không
        /// Dùng để biết có cần upgrade hash khi user đăng nhập không
        /// </summary>
        public static bool NeedsUpgrade(string hash)
            => !hash.StartsWith("$2");

        // ── SHA256 cũ (chỉ dùng khi migrate) ────────────────────────────────
        private static string LegacySha256Hash(string password)
        {
            using var sha256 = System.Security.Cryptography.SHA256.Create();
            byte[] bytes = sha256.ComputeHash(
                System.Text.Encoding.UTF8.GetBytes(password + "POS_SALT_2024"));
            return Convert.ToBase64String(bytes);
        }

        private static bool LegacySha256Verify(string password, string hash)
            => LegacySha256Hash(password) == hash;
    }
}