using DoAnQuanLyQuanAnAI.Models;
using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("OrderItems")]
    public class OrderItem
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int OrderItemId { get; set; }

        [Required]
        public int OrderId { get; set; }

        [Required]
        public int ItemId { get; set; }

        [Required]
        public int Quantity { get; set; } = 1;

        [Required]
        [Column(TypeName = "decimal(18,0)")]
        public decimal UnitPrice { get; set; }   // Giá tại thời điểm gọi

        [MaxLength(300)]
        public string? Note { get; set; }         // "không cay", "ít muối"

        public DateTime AddedAt { get; set; } = DateTime.Now;

        public bool IsDeleted { get; set; } = false;  // Soft delete để log bất thường

        // Navigation
        [ForeignKey("OrderId")]
        public Order Order { get; set; } = null!;

        [ForeignKey("ItemId")]
        public MenuItem MenuItem { get; set; } = null!;

        [NotMapped]
        public decimal LineTotal => UnitPrice * Quantity;
    }
}