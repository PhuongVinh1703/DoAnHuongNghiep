using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Helpers;
using DoAnQuanLyQuanAnAI.Models;

using ModelMenuItem = DoAnQuanLyQuanAnAI.Models.MenuItem;

namespace DoAnQuanLyQuanAnAI
{
    public class OrderItemViewModel
    {
        public int OrderItemId { get; set; }  // ID trong DB
        public int ItemId { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public decimal UnitPrice { get; set; }
        public int Quantity { get; set; }
        public decimal LineTotal => UnitPrice * Quantity;
    }

    public class TableViewModel
    {
        public int TableId { get; set; }
        public string TableName { get; set; } = string.Empty;
        public TableStatus Status { get; set; }

        public string StatusText => Status switch
        {
            TableStatus.Available => "✅ Trống",
            TableStatus.Occupied => "🔴 Đang dùng",
            _ => "🟡 Đã đặt"
        };

        public SolidColorBrush StatusBrush => Status switch
        {
            TableStatus.Available => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#16a34a")),
            TableStatus.Occupied => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#dc2626")),
            _ => new SolidColorBrush((Color)ColorConverter.ConvertFromString("#d97706"))
        };
    }

    public partial class StaffPOSWindow : Window
    {
        private readonly Account _currentUser;
        private DiningTable? _selectedTable;
        private Order? _currentOrder;

        private readonly ObservableCollection<OrderItemViewModel> _orderItems = new();
        private List<ModelMenuItem> _allMenuItems = new();
        private int _selectedCategoryId = 0;
        private string _searchKeyword = "";

        // ── Bộ đếm cho AI ────────────────────────────────────────────────────
        private int _canceledItemCount = 0;
        private int _totalItemsAdded = 0;
        private int _voidCount = 0;

        // ĐÃ THÊM: Theo dõi tổng thời gian từ lúc mở phiên làm việc
        private readonly DateTime _sessionStartTime = DateTime.Now;

        // ── Banner cảnh báo ───────────────────────────────────────────────────
        private DispatcherTimer? _alertTimer;
        private int _alertCountdown = 8;

        public StaffPOSWindow(Account user)
        {
            InitializeComponent();
            _currentUser = user;
            TxtStaffName.Text = $"{_currentUser.Avatar} {_currentUser.FullName}";
            OrderList.ItemsSource = _orderItems;
            _orderItems.CollectionChanged += (s, e) => RefreshTotal();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            LoadTables();
            LoadCategories();
            LoadMenu();
        }

        // ── LOAD ─────────────────────────────────────────────────────────────

        private void LoadTables()
        {
            using var db = new AppDbContext();
            TableList.ItemsSource = db.DiningTables.ToList().Select(t => new TableViewModel
            {
                TableId = t.TableId,
                TableName = t.TableName,
                Status = t.Status
            }).ToList();
        }

        private void LoadCategories()
        {
            CategoryBar.Children.Clear();
            var btnAll = CreateCategoryButton("🌟 Tất cả", 0);
            btnAll.Background = (SolidColorBrush)Application.Current.Resources["PrimaryColor"];
            btnAll.Foreground = Brushes.White;
            CategoryBar.Children.Add(btnAll);

            using var db = new AppDbContext();
            foreach (var cat in db.MenuCategories.OrderBy(c => c.DisplayOrder).ToList())
                CategoryBar.Children.Add(CreateCategoryButton($"{cat.Icon} {cat.Name}", cat.CategoryId));
        }

        private Button CreateCategoryButton(string text, int tagId)
        {
            var btn = new Button
            {
                Content = text,
                Tag = tagId,
                Margin = new Thickness(0, 0, 10, 0),
                Padding = new Thickness(15, 8, 15, 8),
                Background = (SolidColorBrush)Application.Current.Resources["SurfaceAltColor"],
                Foreground = (SolidColorBrush)Application.Current.Resources["TextSubColor"],
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            btn.Click += BtnCategory_Click;
            return btn;
        }

        private void LoadMenu()
        {
            using var db = new AppDbContext();
            _allMenuItems = db.MenuItems.Where(m => m.IsAvailable).ToList();
            FilterMenu();
        }

        private void FilterMenu()
        {
            var filtered = _selectedCategoryId == 0
                ? _allMenuItems
                : _allMenuItems.Where(m => m.CategoryId == _selectedCategoryId).ToList();

            if (!string.IsNullOrWhiteSpace(_searchKeyword))
            {
                filtered = filtered
                    .Where(m => m.Name.Contains(_searchKeyword, StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }

            MenuList.ItemsSource = filtered;
        }

        private void LoadOrderItemsFromDb()
        {
            _orderItems.Clear();
            if (_currentOrder == null) return;

            using var db = new AppDbContext();
            var items = db.OrderItems
                .Where(oi => oi.OrderId == _currentOrder.OrderId)
                .ToList();

            foreach (var item in items)
            {
                var menuInfo = db.MenuItems.Find(item.ItemId);
                if (menuInfo != null)
                    _orderItems.Add(new OrderItemViewModel
                    {
                        OrderItemId = item.OrderItemId,
                        ItemId = item.ItemId,
                        ItemName = menuInfo.Name,
                        UnitPrice = item.UnitPrice,
                        Quantity = item.Quantity
                    });
            }
            RefreshTotal();
        }

        // ── SỰ KIỆN CLICK ────────────────────────────────────────────────────

        private void TxtSearchMenu_TextChanged(object sender, TextChangedEventArgs e)
        {
            _searchKeyword = TxtSearchMenu.Text.Trim();
            FilterMenu();
        }

        private void BtnCategory_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button;
            if (btn == null) return;

            _selectedCategoryId = (int)btn.Tag;

            foreach (Button b in CategoryBar.Children)
            {
                b.Background = (SolidColorBrush)Application.Current.Resources["SurfaceAltColor"];
                b.Foreground = (SolidColorBrush)Application.Current.Resources["TextSubColor"];
            }
            btn.Background = (SolidColorBrush)Application.Current.Resources["PrimaryColor"];
            btn.Foreground = Brushes.White;
            FilterMenu();
        }

        private void BtnTable_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as TableViewModel;
            if (vm == null) return;

            using var db = new AppDbContext();
            _selectedTable = db.DiningTables.Find(vm.TableId);
            if (_selectedTable == null) return;

            TxtSelectedTable.Text = $"📍 {_selectedTable.TableName}";

            _canceledItemCount = 0;
            _totalItemsAdded = 0;
            // KHÔNG RESET _voidCount Ở ĐÂY NỮA!

            _currentOrder = db.Orders.FirstOrDefault(
                o => o.TableId == vm.TableId && o.Status == OrderStatus.Open);

            LoadOrderItemsFromDb();
        }

        private void BtnAddItem_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedTable == null)
            {
                MessageBox.Show("Vui lòng chọn một bàn trước khi gọi món!",
                    "Cảnh báo", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var menu = (sender as Button)?.Tag as ModelMenuItem;
            if (menu == null) return;

            using var db = new AppDbContext();

            if (_currentOrder == null)
            {
                _currentOrder = new Order
                {
                    TableId = _selectedTable.TableId,
                    AccountId = _currentUser.AccountId,
                    Status = OrderStatus.Open,
                    OpenedAt = DateTime.Now
                };
                db.Orders.Add(_currentOrder);

                var table = db.DiningTables.Find(_selectedTable.TableId);
                if (table != null) table.Status = TableStatus.Occupied;

                db.SaveChanges();
            }

            var existingDbItem = db.OrderItems.FirstOrDefault(
                oi => oi.OrderId == _currentOrder.OrderId && oi.ItemId == menu.ItemId);

            if (existingDbItem != null)
            {
                existingDbItem.Quantity++;
                db.SaveChanges();
            }
            else
            {
                var newOrderItem = new OrderItem
                {
                    OrderId = _currentOrder.OrderId,
                    ItemId = menu.ItemId,
                    Quantity = 1,
                    UnitPrice = menu.Price
                };
                db.OrderItems.Add(newOrderItem);
                db.SaveChanges();
            }

            _totalItemsAdded++;
            LoadOrderItemsFromDb();
            LoadTables();
        }

        private void BtnIncQty_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as OrderItemViewModel;
            if (vm == null || _currentOrder == null) return;

            using var db = new AppDbContext();
            var dbItem = db.OrderItems.FirstOrDefault(
                oi => oi.OrderId == _currentOrder.OrderId && oi.ItemId == vm.ItemId);

            if (dbItem != null)
            {
                dbItem.Quantity++;
                db.SaveChanges();
            }

            _totalItemsAdded++;
            LoadOrderItemsFromDb();
        }

        private void BtnDecQty_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as OrderItemViewModel;
            if (vm == null || _currentOrder == null) return;

            using var db = new AppDbContext();
            var dbItem = db.OrderItems.FirstOrDefault(
                oi => oi.OrderId == _currentOrder.OrderId && oi.ItemId == vm.ItemId);

            if (dbItem == null) return;

            if (dbItem.Quantity > 1)
            {
                dbItem.Quantity--;
                db.SaveChanges();
                _canceledItemCount++;
            }
            else
            {
                db.OrderItems.Remove(dbItem);
                db.SaveChanges();
                _canceledItemCount++;
            }

            LoadOrderItemsFromDb();
        }

        private void BtnRemoveItem_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as OrderItemViewModel;
            if (vm == null || _currentOrder == null) return;

            using var db = new AppDbContext();
            var dbItem = db.OrderItems.FirstOrDefault(
                oi => oi.OrderId == _currentOrder.OrderId && oi.ItemId == vm.ItemId);

            if (dbItem != null)
            {
                _canceledItemCount += dbItem.Quantity;
                db.OrderItems.Remove(dbItem);
                db.SaveChanges();
            }

            LoadOrderItemsFromDb();
        }

        private void BtnClearOrder_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedTable == null || !_orderItems.Any()) return;

            var result = MessageBox.Show(
                "Bạn có chắc chắn muốn hủy toàn bộ đơn hàng này?",
                "Xác nhận hủy", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (result == MessageBoxResult.Yes)
            {
                using var db = new AppDbContext();
                if (_currentOrder != null)
                {
                    var itemsToDelete = db.OrderItems
                        .Where(oi => oi.OrderId == _currentOrder.OrderId).ToList();
                    db.OrderItems.RemoveRange(itemsToDelete);

                    var o = db.Orders.Find(_currentOrder.OrderId);
                    if (o != null) o.Status = OrderStatus.Cancelled;

                    var t = db.DiningTables.Find(_selectedTable.TableId);
                    if (t != null) t.Status = TableStatus.Available;

                    db.SaveChanges();
                }

                _voidCount++;
                _orderItems.Clear();
                _currentOrder = null;
                _selectedTable = null;
                TxtSelectedTable.Text = "📍 Chưa chọn bàn";
                LoadTables();
                RefreshTotal();
            }
        }

        // ── THANH TOÁN + AI ──────────────────────────────────────────────────

        private async void BtnCheckout_Click(object sender, RoutedEventArgs e)
        {
            if (_selectedTable == null || !_orderItems.Any() || _currentOrder == null)
            {
                MessageBox.Show("Đơn hàng rỗng hoặc chưa chọn bàn!",
                    "Lỗi", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            var orderSnapshot = _currentOrder;
            var tableSnapshot = _selectedTable;
            var itemsSnapshot = _orderItems.ToList();

            var subtotal = itemsSnapshot.Sum(i => i.LineTotal);
            var vat = subtotal * 0.08m;
            var total = subtotal + vat;

            var confirm = MessageBox.Show(
                $"Thanh toán hóa đơn: {total:N0} đ?",
                "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Information);
            if (confirm != MessageBoxResult.Yes) return;

            string invoiceNo = "HD" + DateTime.Now.ToString("yyMMddHHmmss");

            if (RbQR.IsChecked == true)
            {
                var qrWindow = new QRPaymentWindow(total, invoiceNo);
                qrWindow.ShowDialog();
            }

            // ── GỌI AI ───────────────────────────────────────────────────────

            // ĐÃ SỬA: Tính session dựa trên thời gian thực tế nhân viên bắt đầu phiên làm việc
            double sessionSec = (DateTime.Now - _sessionStartTime).TotalSeconds;

            int totalQty = itemsSnapshot.Sum(i => i.Quantity);
            int totalOps = _totalItemsAdded + _canceledItemCount;
            double cancelRate = totalOps > 0 ? (double)_canceledItemCount / totalOps : 0;
            double addRemRatio = _totalItemsAdded > 0 ? (double)_canceledItemCount / _totalItemsAdded : 0;

            AnomalyResult anomaly;
            try
            {
                anomaly = await AnomalyDetector.PredictAsync(
                    staffId: _currentUser.AccountId,
                    sessionDuration: sessionSec,
                    numItemsOrdered: totalQty,
                    cancelRate: cancelRate,
                    transactionHour: DateTime.Now.Hour,
                    checkoutTimeSec: Math.Min(sessionSec, 999),
                    voidCount: _voidCount,
                    discountPercent: 0,
                    addRemoveRatio: addRemRatio
                );
            }
            catch
            {
                anomaly = new AnomalyResult
                {
                    IsAnomaly = false,
                    AnomalyScore = 0,
                    RiskLevel = "LOW"
                };
            }

            using (var db = new AppDbContext())
            {
                var invoice = new Invoice
                {
                    InvoiceNo = invoiceNo,
                    OrderId = orderSnapshot.OrderId,
                    TableId = tableSnapshot.TableId,
                    AccountId = _currentUser.AccountId,
                    Subtotal = subtotal,
                    VatAmount = vat,
                    TotalAmount = total,
                    PaymentMethod = RbCash.IsChecked == true ? PaymentMethod.Cash
                                  : RbCard.IsChecked == true ? PaymentMethod.Card
                                  : PaymentMethod.Transfer,
                    PaidAt = DateTime.Now
                };
                db.Invoices.Add(invoice);

                var orderDb = db.Orders.Find(orderSnapshot.OrderId);
                if (orderDb != null) orderDb.Status = OrderStatus.Paid;

                var tableDb = db.DiningTables.Find(tableSnapshot.TableId);
                if (tableDb != null) tableDb.Status = TableStatus.Available;

                db.ActionLogs.Add(new ActionLog
                {
                    AccountId = _currentUser.AccountId,
                    OrderId = orderSnapshot.OrderId,
                    ActionType = ActionType.Checkout,
                    Description = $"Thanh toán {invoiceNo} | Score: {anomaly.AnomalyScore:F4} | Risk: {anomaly.RiskLevel} | Type: {anomaly.AnomalyType}",
                    AnomalyScore = (decimal)anomaly.AnomalyScore,
                    IsFlagged = anomaly.IsAnomaly,
                    Timestamp = DateTime.Now
                });

                if (anomaly.IsAnomaly)
                {
                    db.Alerts.Add(new Alert
                    {
                        AccountId = _currentUser.AccountId,
                        OrderId = orderSnapshot.OrderId,
                        AlertType = anomaly.ToAlertType(),
                        Severity = anomaly.RiskLevel == "HIGH"
                                       ? AlertSeverity.High
                                       : AlertSeverity.Medium,
                        Message = $"[{anomaly.AnomalyTypeVN}] Bất thường khi thanh toán [{invoiceNo}] — NV: {_currentUser.FullName}",
                        Detail = $"Score: {anomaly.AnomalyScore:F4} | Risk: {anomaly.RiskLevel} | Type: {anomaly.AnomalyType}",
                        AnomalyScore = (decimal)anomaly.AnomalyScore,
                        IsResolved = false,
                        CreatedAt = DateTime.Now
                    });
                }

                db.SaveChanges();
            }

            if (anomaly.IsAnomaly)
            {
                string msg = anomaly.RiskLevel == "HIGH"
                    ? $"[{anomaly.AnomalyTypeVN}] Rủi ro CAO ({anomaly.AnomalyScore:P0}) — đã báo cáo quản lý"
                    : $"[{anomaly.AnomalyTypeVN}] Dấu hiệu bất thường ({anomaly.AnomalyScore:P0}) — đã ghi nhận";
                ShowAlertBanner(msg);
            }

            MessageBox.Show(
                $"Thanh toán thành công!\nSố hóa đơn: {invoiceNo}",
                "Thành công", MessageBoxButton.OK, MessageBoxImage.Information);

            // Reset phiên hóa đơn
            _orderItems.Clear();
            _currentOrder = null;
            _selectedTable = null;
            _canceledItemCount = 0;
            _totalItemsAdded = 0;
            _voidCount = 0;
            TxtSearchMenu.Text = "";
            TxtSelectedTable.Text = "📍 Chưa chọn bàn";
            LoadTables();
            RefreshTotal();
        }

        // ── BANNER CẢNH BÁO ──────────────────────────────────────────────────

        private void ShowAlertBanner(string message)
        {
            TxtAlertBanner.Text = message;
            AlertBanner.Visibility = Visibility.Visible;
            _alertCountdown = 8;
            TxtAlertCountdown.Text = $"Tự đóng sau {_alertCountdown}s";

            _alertTimer?.Stop();
            _alertTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _alertTimer.Tick += (s, e) =>
            {
                _alertCountdown--;
                TxtAlertCountdown.Text = $"Tự đóng sau {_alertCountdown}s";
                if (_alertCountdown <= 0)
                {
                    AlertBanner.Visibility = Visibility.Collapsed;
                    _alertTimer?.Stop();
                }
            };
            _alertTimer.Start();
        }

        private void BtnDismissAlert_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            AlertBanner.Visibility = Visibility.Collapsed;
            _alertTimer?.Stop();
        }

        // ── TỔNG TIỀN & ĐĂNG XUẤT ────────────────────────────────────────────

        private void RefreshTotal()
        {
            decimal subtotal = _orderItems.Sum(i => i.LineTotal);
            decimal vat = subtotal * 0.08m;
            TxtSubtotal.Text = $"{subtotal:N0} đ";
            TxtVat.Text = $"{vat:N0} đ";
            TxtTotal.Text = $"{subtotal + vat:N0} đ";
        }

        private void BtnLogout_Click(object sender, RoutedEventArgs e)
        {
            if (_orderItems.Any())
            {
                var res = MessageBox.Show(
                    "Đang có đơn hàng chưa thanh toán. Bạn có chắc chắn muốn đăng xuất?",
                    "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Warning);
                if (res == MessageBoxResult.No) return;
            }

            // ĐÃ THÊM: Reset toàn bộ log để không ảnh hưởng tới user sau
            _voidCount = 0;
            _canceledItemCount = 0;
            _totalItemsAdded = 0;

            new MainWindow().Show();
            this.Close();
        }
    }
}