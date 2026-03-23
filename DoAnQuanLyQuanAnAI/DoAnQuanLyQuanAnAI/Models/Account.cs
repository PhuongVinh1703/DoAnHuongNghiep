using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DoAnQuanLyQuanAnAI.Models
{
    [Table("Accounts")]
    public class Account
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AccountId { get; set; }

        [Required, MaxLength(50)]
        public string Username { get; set; } = string.Empty;

        [Required, MaxLength(255)]
        public string PasswordHash { get; set; } = string.Empty;

        [Required]
        public AccountRole Role { get; set; } = AccountRole.Staff;

        [Required, MaxLength(100)]
        public string FullName { get; set; } = string.Empty;

        [MaxLength(20)]
        public string? Phone { get; set; }

        [MaxLength(150)]
        public string? Email { get; set; }

        [MaxLength(10)]
        public string Avatar { get; set; } = "👤";

        public Gender Gender { get; set; } = Gender.Other;

        public int? BranchId { get; set; }

        [ForeignKey("BranchId")]
        public Branch? Branch { get; set; }

        public bool IsActive { get; set; } = true;

        public DateTime JoinDate { get; set; } = DateTime.Today;

        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public DateTime? UpdatedAt { get; set; }

        // Navigation
        public ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();
        public ICollection<ActionLog> ActionLogs { get; set; } = new List<ActionLog>();
    }

    public enum AccountRole
    {
        Owner = 0,  // Chủ sở hữu — quyền cao nhất
        Staff = 1,  // Nhân viên thu ngân
        Manager = 2   // Quản lý chi nhánh
    }

    public enum Gender
    {
        Male = 0,
        Female = 1,
        Other = 2
    }
}