using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("InvoiceItems")]
    public class InvoiceItem
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int InvoiceItemId { get; set; }

        [Required]
        public int InvoiceId { get; set; }

        [Required]
        public int ItemId { get; set; }

        [Required, MaxLength(150)]
        public string ItemName { get; set; } = string.Empty;  // Snapshot tên lúc bán

        [Required]
        public int Quantity { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,0)")]
        public decimal UnitPrice { get; set; }     // Snapshot giá lúc bán

        [MaxLength(300)]
        public string? Note { get; set; }

        // Navigation
        [ForeignKey("InvoiceId")]
        public Invoice Invoice { get; set; } = null!;

        [ForeignKey("ItemId")]
        public MenuItem MenuItem { get; set; } = null!;

        [NotMapped]
        public decimal LineTotal => UnitPrice * Quantity;
    }
}
