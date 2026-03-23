using Microsoft.EntityFrameworkCore;
using DoAnQuanLyQuanAnAI.Helpers;
using DoAnQuanLyQuanAnAI.Models;

namespace DoAnQuanLyQuanAnAI.Data
{
    public class AppDbContext : DbContext
    {
        public DbSet<Account> Accounts { get; set; }
        public DbSet<Branch> Branches { get; set; }
        public DbSet<DiningTable> DiningTables { get; set; }
        public DbSet<MenuCategory> MenuCategories { get; set; }
        public DbSet<MenuItem> MenuItems { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderItem> OrderItems { get; set; }
        public DbSet<Invoice> Invoices { get; set; }
        public DbSet<InvoiceItem> InvoiceItems { get; set; }
        public DbSet<ActionLog> ActionLogs { get; set; }
        public DbSet<Alert> Alerts { get; set; }

        public AppDbContext() { }
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        protected override void OnConfiguring(DbContextOptionsBuilder options)
        {
            if (!options.IsConfigured)
                options.UseSqlServer(ConfigHelper.ConnectionString);
        }
    }
}