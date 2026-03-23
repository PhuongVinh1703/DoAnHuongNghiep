using System.Linq;
using System.Windows;
using DoAnQuanLyQuanAnAI.Data;

namespace DoAnQuanLyQuanAnAI
{
    public class InvoiceItemRow
    {
        public string ItemName { get; set; } = "";
        public string UnitPrice { get; set; } = "";
        public int Quantity { get; set; }
        public string LineTotal { get; set; } = "";
    }

    public partial class InvoiceDetailDialog : Window
    {
        public InvoiceDetailDialog(int invoiceId)
        {
            InitializeComponent();
            LoadDetail(invoiceId);
        }

        private void LoadDetail(int invoiceId)
        {
            using var db = new AppDbContext();
            var inv = db.Invoices.Find(invoiceId);
            if (inv == null) return;

            var table = db.DiningTables.Find(inv.TableId);
            var staff = db.Accounts.Find(inv.AccountId);
            var branch = staff?.BranchId.HasValue == true
                         ? db.Branches.Find(staff.BranchId.Value) : null;

            TxtInvoiceNo.Text = $"🧾 {inv.InvoiceNo}";
            TxtTableName.Text = $"🪑 Bàn: {table?.TableName ?? "—"}";
            TxtStaffName.Text = $"👤 Nhân viên: {staff?.FullName ?? "—"}";
            TxtPaidAt.Text = $"🕐 {inv.PaidAt:HH:mm  dd/MM/yyyy}";
            TxtBranchName.Text = $"🏢 {branch?.Name ?? "—"}";
            TxtPayMethod.Text = inv.PaymentMethod switch
            {
                Models.PaymentMethod.Cash => "💵 Tiền mặt",
                Models.PaymentMethod.Card => "💳 Thẻ",
                Models.PaymentMethod.Transfer => "📱 Chuyển khoản",
                _ => inv.PaymentMethod.ToString()
            };

            // Load items từ OrderItems
            var order = db.Orders.Find(inv.OrderId);
            if (order != null)
            {
                DgItems.ItemsSource = db.OrderItems
                    .Where(oi => oi.OrderId == order.OrderId)
                    .ToList()
                    .Select(oi =>
                    {
                        var menu = db.MenuItems.Find(oi.ItemId);
                        return new InvoiceItemRow
                        {
                            ItemName = $"{menu?.Emoji} {menu?.Name ?? "—"}",
                            UnitPrice = $"{oi.UnitPrice:N0} đ",
                            Quantity = oi.Quantity,
                            LineTotal = $"{oi.UnitPrice * oi.Quantity:N0} đ"
                        };
                    }).ToList();
            }

            TxtSubtotal.Text = $"{inv.Subtotal:N0} đ";
            TxtVat.Text = $"{inv.VatAmount:N0} đ";
            TxtTotal.Text = $"{inv.TotalAmount:N0} đ";
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e) => Close();
    }
}