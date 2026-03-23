using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("Alerts")]
    public class Alert
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AlertId { get; set; }

        public int? AccountId { get; set; }   // Nhân viên bị cảnh báo

        public int? OrderId { get; set; }

        [Required]
        public AlertType AlertType { get; set; }

        [Required]
        public AlertSeverity Severity { get; set; } = AlertSeverity.Medium;

        [Required, MaxLength(500)]
        public string Message { get; set; } = string.Empty;

        [MaxLength(2000)]
        public string? Detail { get; set; }   // JSON từ AI model

        [Column(TypeName = "decimal(5,4)")]
        public decimal AnomalyScore { get; set; }

        public bool IsResolved { get; set; } = false;

        [MaxLength(500)]
        public string? ResolvedNote { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public DateTime? ResolvedAt { get; set; }

        // Navigation
        [ForeignKey("AccountId")]
        public Account? Account { get; set; }
    }

    public enum AlertType
    {
        CancelAfterPayment = 0,  // Hủy sau khi khách đưa tiền
        ExcessiveDiscount = 1,  // Lạm dụng mã giảm giá
        FrequentCancellation = 2,  // Hủy bill liên tục
        UnusualHours = 3,  // Giao dịch giờ bất thường
        CashDrawerMismatch = 4,  // Mở két bất thường
        SpeedAnomaly = 5   // Thanh toán quá nhanh
    }

    public enum AlertSeverity
    {
        Low = 0,
        Medium = 1,
        High = 2
    }
}