using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;


namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("DiningTables")]
    public class DiningTable
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TableId { get; set; }

        [Required, MaxLength(50)]
        public string TableName { get; set; } = string.Empty;   // "Bàn 1", "Bàn VIP"

        public int Capacity { get; set; } = 4;

        public TableStatus Status { get; set; } = TableStatus.Available;

        public bool IsActive { get; set; } = true;

        // Navigation
        public ICollection<Order> Orders { get; set; } = new List<Order>();
        public ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();
    }

    public enum TableStatus
    {
        Available = 0,   // Trống
        Occupied = 1,   // Đang dùng
        Reserved = 2    // Đặt trước
    }
}