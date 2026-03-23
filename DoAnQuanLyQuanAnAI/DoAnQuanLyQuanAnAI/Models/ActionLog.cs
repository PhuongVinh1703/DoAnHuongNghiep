using DoAnQuanLyQuanAnAI.Models;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("ActionLogs")]
    public class ActionLog
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int LogId { get; set; }

        [Required]
        public int AccountId { get; set; }

        public int? OrderId { get; set; }

        public int? InvoiceId { get; set; }

        [Required]
        public ActionType ActionType { get; set; }

        [MaxLength(1000)]
        public string? Description { get; set; }  // JSON chi tiết: {"itemId":4,"qty":2}

        [MaxLength(50)]
        public string? IpAddress { get; set; }

        public DateTime Timestamp { get; set; } = DateTime.Now;

        // Anomaly score từ ML (sẽ dùng sau)
        [Column(TypeName = "decimal(5,4)")]
        public decimal? AnomalyScore { get; set; }

        public bool IsFlagged { get; set; } = false;

        // Navigation
        [ForeignKey("AccountId")]
        public Account Account { get; set; } = null!;
    }

    public enum ActionType
    {
        Login = 0,
        Logout = 1,
        OpenTable = 2,
        AddItem = 3,
        RemoveItem = 4,
        UpdateQuantity = 5,
        AddNote = 6,
        ApplyDiscount = 7,
        PrintPreview = 8,
        CancelOrder = 9,
        Checkout = 10,
        OpenCashDrawer = 11,   // ⚠️ Quan trọng cho phát hiện gian lận
        CreateAccount = 20,
        UpdateAccount = 21,
        DeactivateAccount = 22
    }
}