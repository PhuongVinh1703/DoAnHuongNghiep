using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("Orders")]
    public class Order
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int OrderId { get; set; }

        [Required]
        public int TableId { get; set; }

        [Required]
        public int AccountId { get; set; }  // Nhân viên phụ trách

        public OrderStatus Status { get; set; } = OrderStatus.Open;

        public DateTime OpenedAt { get; set; } = DateTime.Now;

        public DateTime? ClosedAt { get; set; }

        [MaxLength(500)]
        public string? Note { get; set; }

        // Navigation
        [ForeignKey("TableId")]
        public DiningTable Table { get; set; } = null!;

        [ForeignKey("AccountId")]
        public Account Account { get; set; } = null!;

        public ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();

        public Invoice? Invoice { get; set; }
    }

    public enum OrderStatus
    {
        Open = 0,   // Đang gọi món
        Printed = 1,   // Đã in tạm tính
        Cancelled = 2,   // Đã hủy
        Paid = 3    // Đã thanh toán
    }
}