using DoAnQuanLyQuanAnAI.Models;
using System;
using System.Text.Json;
using System.Threading.Tasks;
using DoAnQuanLyQuanAnAI.Data;

namespace DoAnQuanLyQuanAnAI.Helpers
{
    public static class ActionLogHelper
    {
        public static async Task LogAsync(
            AppDbContext db,
            int accountId,
            ActionType actionType,
            object? detail = null,
            int? orderId = null,
            int? invoiceId = null)
        {
            var log = new ActionLog
            {
                AccountId = accountId,
                ActionType = actionType,
                OrderId = orderId,
                InvoiceId = invoiceId,
                Description = detail != null ? JsonSerializer.Serialize(detail) : null,
                Timestamp = DateTime.Now
            };
            db.ActionLogs.Add(log);
            await db.SaveChangesAsync();
        }
    }
}
