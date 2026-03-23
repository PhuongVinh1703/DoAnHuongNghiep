using DoAnQuanLyQuanAnAI.Models;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("Invoices")]
    public class Invoice
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int InvoiceId { get; set; }

        [Required, MaxLength(20)]
        public string InvoiceNo { get; set; } = string.Empty;  // "HD741230"

        [Required]
        public int OrderId { get; set; }

        [Required]
        public int TableId { get; set; }

        [Required]
        public int AccountId { get; set; }   // Thu ngân

        [Required]
        [Column(TypeName = "decimal(18,0)")]
        public decimal Subtotal { get; set; }

        [MaxLength(20)]
        public string? DiscountCode { get; set; }

        [Column(TypeName = "decimal(5,2)")]
        public decimal DiscountPercent { get; set; } = 0;

        [Column(TypeName = "decimal(18,0)")]
        public decimal DiscountAmount { get; set; } = 0;

        [Column(TypeName = "decimal(5,2)")]
        public decimal VatPercent { get; set; } = 8;

        [Column(TypeName = "decimal(18,0)")]
        public decimal VatAmount { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,0)")]
        public decimal TotalAmount { get; set; }

        public PaymentMethod PaymentMethod { get; set; } = PaymentMethod.Cash;

        public DateTime PaidAt { get; set; } = DateTime.Now;

        // Navigation
        [ForeignKey("OrderId")]
        public Order Order { get; set; } = null!;

        [ForeignKey("TableId")]
        public DiningTable Table { get; set; } = null!;

        [ForeignKey("AccountId")]
        public Account Account { get; set; } = null!;

        public ICollection<InvoiceItem> InvoiceItems { get; set; } = new List<InvoiceItem>();
    }

    public enum PaymentMethod
    {
        Cash = 0,
        Card = 1,
        Transfer = 2
    }
}