using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using DoAnQuanLyQuanAnAI.Helpers;

namespace DoAnQuanLyQuanAnAI.Data
{
    /// <summary>
    /// Chỉ dùng khi chạy lệnh Migration (dotnet ef migrations add ...)
    /// Runtime app dùng AppDbContext() trực tiếp qua ConfigHelper
    /// </summary>
    public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
            optionsBuilder.UseSqlServer(ConfigHelper.ConnectionString);
            return new AppDbContext(optionsBuilder.Options);
        }
    }
}