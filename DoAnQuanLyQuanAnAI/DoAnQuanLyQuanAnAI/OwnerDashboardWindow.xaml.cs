using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using Microsoft.EntityFrameworkCore;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Helpers;
using DoAnQuanLyQuanAnAI.Models;
using ModelMenuItem = DoAnQuanLyQuanAnAI.Models.MenuItem;

namespace DoAnQuanLyQuanAnAI
{
    // ── ViewModels ────────────────────────────────────────────────────────────

    public class InvoiceViewModel
    {
        public int InvoiceId { get; set; }
        public string InvoiceNo { get; set; } = "";
        public string TableName { get; set; } = "";
        public string StaffName { get; set; } = "";
        public string BranchName { get; set; } = "";
        public string Subtotal { get; set; } = "";
        public string VatAmount { get; set; } = "";
        public string TotalAmount { get; set; } = "";
        public string PayMethod { get; set; } = "";
        public string PaidAt { get; set; } = "";
    }

    public class StaffViewModel
    {
        public int AccountId { get; set; }
        public string Avatar { get; set; } = "";
        public string FullName { get; set; } = "";
        public string Username { get; set; } = "";
        public string Phone { get; set; } = "";
        public string RoleText { get; set; } = "";
        public string GenderText { get; set; } = "";
        public int GenderValue { get; set; }
        public string BranchName { get; set; } = "";
        public int? BranchId { get; set; }
        public string JoinDate { get; set; } = "";
        public bool IsActive { get; set; }

        public string StatusText => IsActive ? "Hoạt động" : "Đã khóa";
        public SolidColorBrush StatusBg => IsActive
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#dcfce7"))
            : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#fee2e2"));
        public SolidColorBrush StatusFg => IsActive
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#16a34a"))
            : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#ef4444"));
        public string ToggleText => IsActive ? "🔒 Khóa" : "🔓 Mở";
        public SolidColorBrush ToggleBg => IsActive
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#ef4444"))
            : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#16a34a"));
    }

    public class MenuItemViewModel
    {
        public int ItemId { get; set; }
        public string Emoji { get; set; } = "";
        public string Name { get; set; } = "";
        public string CategoryName { get; set; } = "";
        public string PriceText { get; set; } = "";
        public string Description { get; set; } = "";
        public bool IsAvailable { get; set; }
        public string AvailableText => IsAvailable ? "✅ Phục vụ" : "⛔ Tạm ẩn";
        public SolidColorBrush AvailableBg => IsAvailable
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#dcfce7"))
            : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#f1f5f9"));
        public SolidColorBrush AvailableFg => IsAvailable
            ? new SolidColorBrush((Color)ColorConverter.ConvertFromString("#16a34a"))
            : new SolidColorBrush((Color)ColorConverter.ConvertFromString("#94a3b8"));
    }

    public class TopMenuViewModel
    {
        public string Rank { get; set; } = "";
        public string Emoji { get; set; } = "";
        public string Name { get; set; } = "";
        public string CountText { get; set; } = "";
        public double BarWidth { get; set; }
    }

    public class AlertViewModel
    {
        public int AlertId { get; set; }
        public string AlertTypeText { get; set; } = "";
        public string SeverityText { get; set; } = "";
        public string StaffName { get; set; } = "";
        public string BranchName { get; set; } = "";
        public string Message { get; set; } = "";
        public string CreatedAt { get; set; } = "";
    }

    public class LogViewModel
    {
        public string StaffName { get; set; } = "";
        public string BranchName { get; set; } = "";
        public string ActionTypeText { get; set; } = "";
        public string Description { get; set; } = "";
        public string Timestamp { get; set; } = "";
    }

    // ── Window ────────────────────────────────────────────────────────────────

    public partial class OwnerDashboardWindow : Window
    {
        private readonly Account _currentUser;
        private readonly DispatcherTimer _clockTimer;
        private List<StaffViewModel> _allStaff = new();

        public OwnerDashboardWindow(Account user)
        {
            InitializeComponent();
            _currentUser = user;
            TxtOwnerName.Text = $"{_currentUser.Avatar} {_currentUser.FullName}";

            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _clockTimer.Tick += (s, e) =>
                TxtDateTime.Text = DateTime.Now.ToString("HH:mm:ss  dd/MM/yyyy");
            _clockTimer.Start();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            // Khởi tạo branch filters TRƯỚC, nhưng suspend event handlers
            InitBranchFilters();

            // Sau đó load data
            LoadDashboard();
            LoadStaff();
            LoadMenuItems();
            LoadMenuFilter();
            LoadInvoiceFilter();
            LoadInvoices();
            LoadAlerts();
            LoadLogs();
            InitLogFilters();
            InitChartDates();
            LoadCharts();
        }

        // ── BRANCH FILTER HELPERS ─────────────────────────────────────────────

        private void InitBranchFilters()
        {
            using var db = new AppDbContext();
            var branches = db.Branches.Where(b => b.IsActive).OrderBy(b => b.Name).ToList();

            var items = new List<BranchItem>
                { new BranchItem { BranchId = 0, Name = "Tất cả chi nhánh" } };
            items.AddRange(branches.Select(b =>
                new BranchItem { BranchId = b.BranchId, Name = b.Name }));

            // Gán cho tất cả ComboBox — dùng ItemsSource trực tiếp,
            // KHÔNG attach SelectionChanged trước khi set SelectedIndex
            // để tránh trigger Load khi UI chưa sẵn sàng
            var allCbs = new[] { CbBranchDashboard, CbBranchChart,
                                  CbBranchStaff, CbBranchInvoice, CbBranchAlert };

            foreach (var cb in allCbs)
            {
                cb.ItemsSource = items.ToList();
                cb.DisplayMemberPath = "DisplayName";
                cb.SelectedIndex = 0;
            }

            // Manager → khóa chi nhánh
            if (_currentUser.Role == AccountRole.Manager && _currentUser.BranchId.HasValue)
            {
                var myBranch = items.FirstOrDefault(b => b.BranchId == _currentUser.BranchId.Value);
                foreach (var cb in allCbs)
                {
                    if (myBranch != null) cb.SelectedItem = myBranch;
                    cb.IsEnabled = false;
                }
            }
        }

        private int? GetSelectedBranchId(ComboBox cb)
        {
            if (cb == null) return null;
            var item = cb.SelectedItem as BranchItem;
            return item?.BranchId == 0 ? null : item?.BranchId;
        }

        // ── TAB 1: TỔNG QUAN ─────────────────────────────────────────────────

        private void LoadDashboard()
        {
            if (CbBranchDashboard == null || DgRecentInvoices == null) return;

            int? branchId = GetSelectedBranchId(CbBranchDashboard);
            using var db = new AppDbContext();
            var today = DateTime.Today;

            List<int>? accountIds = branchId.HasValue
                ? db.Accounts.Where(a => a.BranchId == branchId).Select(a => a.AccountId).ToList()
                : null;

            var invoiceQ = db.Invoices.Where(i => i.PaidAt >= today && i.PaidAt < today.AddDays(1));
            if (accountIds != null)
                invoiceQ = invoiceQ.Where(i => accountIds.Contains(i.AccountId));

            var invoices = invoiceQ.ToList();
            decimal revenue = invoices.Sum(i => i.TotalAmount);
            int count = invoices.Count;
            decimal avg = count > 0 ? revenue / count : 0;

            TxtTodayRevenue.Text = $"{revenue:N0} đ";
            TxtTodayInvoices.Text = count.ToString();
            TxtInvoiceAvg.Text = $"Trung bình: {avg:N0} đ";

            int total = db.DiningTables.Count(t => t.IsActive);
            int occupied = db.DiningTables.Count(t => t.IsActive && t.Status == TableStatus.Occupied);
            TxtOccupiedTables.Text = $"{occupied} / {total}";

            var alertQ = db.Alerts.Where(a => !a.IsResolved);
            if (accountIds != null)
                alertQ = alertQ.Where(a => a.AccountId.HasValue && accountIds.Contains(a.AccountId.Value));
            TxtPendingAlerts.Text = alertQ.Count().ToString();

            var recentQ = db.Invoices.OrderByDescending(i => i.PaidAt).AsQueryable();
            if (accountIds != null)
                recentQ = recentQ.Where(i => accountIds.Contains(i.AccountId));

            DgRecentInvoices.ItemsSource = recentQ.Take(20).ToList().Select(i =>
            {
                var staff = db.Accounts.Find(i.AccountId);
                var branch = staff?.BranchId.HasValue == true
                             ? db.Branches.Find(staff.BranchId.Value) : null;
                return new InvoiceViewModel
                {
                    InvoiceId = i.InvoiceId,
                    InvoiceNo = i.InvoiceNo,
                    TableName = db.DiningTables.Find(i.TableId)?.TableName ?? "—",
                    StaffName = staff?.FullName ?? "—",
                    BranchName = branch?.Name ?? "—",
                    TotalAmount = $"{i.TotalAmount:N0} đ",
                    PayMethod = PayMethodText(i.PaymentMethod),
                    PaidAt = i.PaidAt.ToString("HH:mm  dd/MM/yyyy")
                };
            }).ToList();
        }

        private void CbBranchDashboard_Changed(object sender, SelectionChangedEventArgs e)
            => LoadDashboard();

        private void BtnRefreshDashboard_Click(object sender, RoutedEventArgs e)
        {
            LoadDashboard(); LoadAlerts(); LoadLogs();
        }

        // ── TAB 2: THỐNG KÊ + BIỂU ĐỒ ───────────────────────────────────────

        private void InitChartDates()
        {
            DpChartFrom.SelectedDate = DateTime.Today.AddDays(-13);
            DpChartTo.SelectedDate = DateTime.Today;
        }

        private void DpChart_Changed(object sender, SelectionChangedEventArgs e) { }
        private void CbBranchChart_Changed(object sender, SelectionChangedEventArgs e) { }

        private void BtnRefreshChart_Click(object sender, RoutedEventArgs e) => LoadCharts();

        private void LoadCharts()
        {
            if (ChartCanvas == null || CbBranchChart == null) return;

            var from = DpChartFrom.SelectedDate ?? DateTime.Today.AddDays(-13);
            var to = DpChartTo.SelectedDate ?? DateTime.Today;
            if (from > to) { MessageBox.Show("Ngày bắt đầu phải trước ngày kết thúc!"); return; }

            DrawRevenueChart(from, to);
            LoadTopMenuItems(from, to);
        }

        private void DrawRevenueChart(DateTime from, DateTime to)
        {
            if (ChartCanvas == null) return;
            ChartCanvas.Children.Clear();
            ChartLegend.Children.Clear();

            int? branchId = GetSelectedBranchId(CbBranchChart);
            using var db = new AppDbContext();

            List<int>? accountIds = branchId.HasValue
                ? db.Accounts.Where(a => a.BranchId == branchId).Select(a => a.AccountId).ToList()
                : null;

            var days = new List<(DateTime Date, decimal Revenue)>();
            for (var d = from.Date; d <= to.Date; d = d.AddDays(1))
            {
                var q = db.Invoices.Where(i => i.PaidAt >= d && i.PaidAt < d.AddDays(1));
                if (accountIds != null) q = q.Where(i => accountIds.Contains(i.AccountId));
                days.Add((d, q.Sum(i => (decimal?)i.TotalAmount) ?? 0));
            }

            if (!days.Any()) return;

            decimal maxRev = days.Max(d => d.Revenue);
            if (maxRev == 0) maxRev = 1;

            double paddingLeft = 50, paddingRight = 16, paddingTop = 20, chartH = 220;
            double slotW = (700.0 - paddingLeft - paddingRight) / days.Count;
            double barW = Math.Max(24, Math.Min(56, slotW * 0.65));
            double totalW = Math.Max(500, days.Count * slotW + paddingLeft + paddingRight);

            ChartCanvas.Width = totalW;
            ChartCanvas.Height = chartH + paddingTop + 28;

            for (int i = 0; i <= 4; i++)
            {
                double y = paddingTop + chartH - chartH * i / 4.0;
                ChartCanvas.Children.Add(new Line
                {
                    X1 = paddingLeft,
                    X2 = totalW - paddingRight,
                    Y1 = y,
                    Y2 = y,
                    Stroke = new SolidColorBrush((Color)ColorConverter.ConvertFromString(
                        i == 0 ? "#cbd5e1" : "#f1f5f9")),
                    StrokeThickness = i == 0 ? 1.5 : 1
                });
                decimal lv = maxRev * i / 4;
                string lt = lv >= 1_000_000 ? $"{lv / 1_000_000:N1}M"
                           : lv >= 1_000 ? $"{lv / 1_000:N0}K" : "0";
                var yLbl = new System.Windows.Controls.TextBlock
                {
                    Text = lt,
                    FontSize = 10,
                    Width = paddingLeft - 6,
                    TextAlignment = TextAlignment.Right,
                    Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#94a3b8"))
                };
                Canvas.SetLeft(yLbl, 0); Canvas.SetTop(yLbl, y - 8);
                ChartCanvas.Children.Add(yLbl);
            }

            for (int i = 0; i < days.Count; i++)
            {
                double cx = paddingLeft + i * slotW + slotW / 2.0;
                double bl = cx - barW / 2.0;
                double bh = (double)(days[i].Revenue / maxRev) * chartH;
                double bt = paddingTop + chartH - bh;
                string col = days[i].Revenue == maxRev && maxRev > 0 ? "#3b82f6" : "#93c5fd";

                var rect = new Rectangle
                {
                    Width = barW,
                    Height = Math.Max(2, bh),
                    Fill = new SolidColorBrush((Color)ColorConverter.ConvertFromString(col)),
                    RadiusX = 4,
                    RadiusY = 4,
                    Opacity = 0
                };
                Canvas.SetLeft(rect, bl); Canvas.SetTop(rect, bt);
                ChartCanvas.Children.Add(rect);

                int delay = i * 60;
                rect.BeginAnimation(UIElement.OpacityProperty,
                    new System.Windows.Media.Animation.DoubleAnimation
                    {
                        From = 0,
                        To = 1,
                        Duration = TimeSpan.FromMilliseconds(400),
                        BeginTime = TimeSpan.FromMilliseconds(delay),
                        EasingFunction = new System.Windows.Media.Animation.CubicEase
                        { EasingMode = System.Windows.Media.Animation.EasingMode.EaseOut }
                    });

                if (days[i].Revenue > 0)
                {
                    string vt = days[i].Revenue >= 1_000_000
                        ? $"{days[i].Revenue / 1_000_000:N1}M"
                        : $"{days[i].Revenue / 1_000:N0}K";
                    var vl = new System.Windows.Controls.TextBlock
                    {
                        Text = vt,
                        FontSize = 10,
                        FontWeight = FontWeights.SemiBold,
                        Width = barW + 20,
                        TextAlignment = TextAlignment.Center,
                        Opacity = 0,
                        Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#1e293b"))
                    };
                    Canvas.SetLeft(vl, bl - 10);
                    Canvas.SetTop(vl, Math.Max(paddingTop, bt - 16));
                    ChartCanvas.Children.Add(vl);
                    vl.BeginAnimation(UIElement.OpacityProperty,
                        new System.Windows.Media.Animation.DoubleAnimation
                        {
                            From = 0,
                            To = 1,
                            Duration = TimeSpan.FromMilliseconds(300),
                            BeginTime = TimeSpan.FromMilliseconds(delay + 200)
                        });
                }

                var dl = new System.Windows.Controls.TextBlock
                {
                    Text = days[i].Date.ToString("dd/MM"),
                    FontSize = 11,
                    Width = slotW,
                    TextAlignment = TextAlignment.Center,
                    Opacity = 0,
                    Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#64748b"))
                };
                Canvas.SetLeft(dl, paddingLeft + i * slotW);
                Canvas.SetTop(dl, paddingTop + chartH + 6);
                ChartCanvas.Children.Add(dl);
                dl.BeginAnimation(UIElement.OpacityProperty,
                    new System.Windows.Media.Animation.DoubleAnimation
                    {
                        From = 0,
                        To = 1,
                        Duration = TimeSpan.FromMilliseconds(300),
                        BeginTime = TimeSpan.FromMilliseconds(delay + 100)
                    });
            }
        }

        private void LoadTopMenuItems(DateTime from, DateTime to)
        {
            if (TopMenuList == null) return;

            int? branchId = GetSelectedBranchId(CbBranchChart);
            using var db = new AppDbContext();

            List<int>? accountIds = branchId.HasValue
                ? db.Accounts.Where(a => a.BranchId == branchId).Select(a => a.AccountId).ToList()
                : null;

            var orderQ = db.Orders.Where(o => o.OpenedAt >= from && o.OpenedAt < to.AddDays(1));
            if (accountIds != null) orderQ = orderQ.Where(o => accountIds.Contains(o.AccountId));
            var orderIds = orderQ.Select(o => o.OrderId).ToList();

            var topItems = db.OrderItems
                .Where(oi => orderIds.Contains(oi.OrderId))
                .GroupBy(oi => oi.ItemId)
                .Select(g => new { ItemId = g.Key, Total = g.Sum(x => x.Quantity) })
                .OrderByDescending(x => x.Total).Take(10).ToList();

            int maxCount = topItems.Any() ? topItems.Max(x => x.Total) : 1;

            TopMenuList.ItemsSource = topItems.Select((x, idx) =>
            {
                var m = db.MenuItems.Find(x.ItemId);
                return new TopMenuViewModel
                {
                    Rank = $"#{idx + 1}",
                    Emoji = m?.Emoji ?? "🍽️",
                    Name = m?.Name ?? "—",
                    CountText = $"{x.Total} lần",
                    BarWidth = maxCount > 0 ? (double)x.Total / maxCount * 200 : 0
                };
            }).ToList();
        }

        // ── TAB 3: NHÂN VIÊN ─────────────────────────────────────────────────

        private void LoadStaff()
        {
            // Guard: UI chưa khởi tạo xong
            if (DgStaff == null || TxtSearchStaff == null || CbBranchStaff == null) return;

            string nameFilter = TxtSearchStaff.Text.Trim();
            int? branchId = GetSelectedBranchId(CbBranchStaff);
            string roleFilter = (CbRoleFilter?.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "";

            using var db = new AppDbContext();
            var query = db.Accounts.Include(a => a.Branch).AsQueryable();

            if (!string.IsNullOrWhiteSpace(nameFilter))
                query = query.Where(a =>
                    a.FullName.Contains(nameFilter) ||
                    a.Username.Contains(nameFilter) ||
                    (a.Phone != null && a.Phone.Contains(nameFilter)));

            if (branchId.HasValue)
                query = query.Where(a => a.BranchId == branchId);

            if (!string.IsNullOrEmpty(roleFilter) && int.TryParse(roleFilter, out int roleInt))
                query = query.Where(a => (int)a.Role == roleInt);

            _allStaff = query.OrderBy(a => a.Role).ThenBy(a => a.FullName).ToList()
                .Select(a => new StaffViewModel
                {
                    AccountId = a.AccountId,
                    Avatar = a.Avatar,
                    FullName = a.FullName,
                    Username = a.Username,
                    Phone = a.Phone ?? "—",
                    RoleText = a.Role switch
                    {
                        AccountRole.Owner => "👑 Owner",
                        AccountRole.Manager => "🏢 Quản lý",
                        _ => "👤 Nhân viên"
                    },
                    GenderValue = (int)a.Gender,
                    GenderText = a.Gender switch
                    {
                        Gender.Male => "👨 Nam",
                        Gender.Female => "👩 Nữ",
                        _ => "🧑 Khác"
                    },
                    BranchName = a.Branch?.Name ?? "—",
                    BranchId = a.BranchId,
                    JoinDate = a.JoinDate.ToString("dd/MM/yyyy"),
                    IsActive = a.IsActive
                }).ToList();

            DgStaff.ItemsSource = _allStaff;
            TxtStaffCount.Text = $"{_allStaff.Count} người";
        }

        private void TxtSearchStaff_TextChanged(object sender, TextChangedEventArgs e) => LoadStaff();
        private void CbBranchStaff_Changed(object sender, SelectionChangedEventArgs e) => LoadStaff();
        private void CbRoleFilter_Changed(object sender, SelectionChangedEventArgs e) => LoadStaff();

        private void BtnAddAccount_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new AddAccountDialog(_currentUser) { Owner = this };
            if (dialog.ShowDialog() == true) LoadStaff();
        }

        private void BtnEditStaff_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as StaffViewModel;
            if (vm == null) return;
            var dialog = new EditAccountDialog(vm, _currentUser) { Owner = this };
            if (dialog.ShowDialog() == true) LoadStaff();
        }

        private void BtnResetPassword_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as StaffViewModel;
            if (vm == null) return;

            string newPass = Microsoft.VisualBasic.Interaction.InputBox(
                $"Nhập mật khẩu mới cho [{vm.FullName}]:", "Đặt lại mật khẩu", "");
            if (string.IsNullOrWhiteSpace(newPass)) return;
            if (newPass.Length < 6) { MessageBox.Show("Mật khẩu phải ít nhất 6 ký tự!"); return; }

            using var db = new AppDbContext();
            var acc = db.Accounts.Find(vm.AccountId);
            if (acc != null)
            {
                acc.PasswordHash = PasswordHelper.Hash(newPass);
                acc.UpdatedAt = DateTime.Now;
                db.SaveChanges();
                MessageBox.Show("Đặt lại mật khẩu thành công!", "Thành công",
                    MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void BtnToggleActive_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as StaffViewModel;
            if (vm == null) return;

            if (vm.IsActive && vm.RoleText.Contains("Owner"))
            {
                using var dbCheck = new AppDbContext();
                if (dbCheck.Accounts.Count(a => a.Role == AccountRole.Owner && a.IsActive) <= 1)
                {
                    MessageBox.Show("Không thể khóa — đây là Owner duy nhất!",
                        "Không được phép", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
            }

            string action = vm.IsActive ? "khóa" : "mở khóa";
            var res = MessageBox.Show($"Bạn có chắc muốn {action} tài khoản [{vm.FullName}]?",
                "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (res != MessageBoxResult.Yes) return;

            using var db = new AppDbContext();
            var acc = db.Accounts.Find(vm.AccountId);
            if (acc != null)
            {
                acc.IsActive = !acc.IsActive;
                acc.UpdatedAt = DateTime.Now;
                db.SaveChanges();
            }
            LoadStaff();
        }

        private void BtnDeleteStaff_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as StaffViewModel;
            if (vm == null) return;

            if (vm.RoleText.Contains("Owner"))
            {
                using var dbCheck = new AppDbContext();
                if (dbCheck.Accounts.Count(a => a.Role == AccountRole.Owner) <= 1)
                {
                    MessageBox.Show("Không thể xóa — đây là Owner duy nhất!",
                        "Không được phép", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
            }

            using var db = new AppDbContext();
            bool hasInvoice = db.Invoices.Any(i => i.AccountId == vm.AccountId);
            if (hasInvoice)
            {
                var res2 = MessageBox.Show(
                    $"Tài khoản [{vm.FullName}] đã có hóa đơn.\nKhóa tài khoản thay vì xóa?",
                    "Gợi ý", MessageBoxButton.YesNo, MessageBoxImage.Question);
                if (res2 == MessageBoxResult.Yes)
                {
                    var accL = db.Accounts.Find(vm.AccountId);
                    if (accL != null) { accL.IsActive = false; accL.UpdatedAt = DateTime.Now; db.SaveChanges(); }
                    LoadStaff();
                }
                return;
            }

            if (MessageBox.Show($"XÓA [{vm.FullName}]? Không thể hoàn tác!",
                "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
                return;

            var accDel = db.Accounts.Find(vm.AccountId);
            if (accDel != null) { db.Accounts.Remove(accDel); db.SaveChanges(); }
            LoadStaff();
        }

        // ── TAB 4: QUẢN LÝ MÓN ĂN ────────────────────────────────────────────

        private void LoadMenuFilter()
        {
            using var db = new AppDbContext();
            var items = new List<object> { new { CategoryId = 0, Name = "— Tất cả danh mục —" } };
            items.AddRange(db.MenuCategories.OrderBy(c => c.DisplayOrder).ToList().Cast<object>());
            CbMenuFilter.ItemsSource = items;
            CbMenuFilter.DisplayMemberPath = "Name";
            CbMenuFilter.SelectedIndex = 0;
        }

        private void LoadMenuItems(int categoryId = 0)
        {
            if (DgMenuItems == null) return;

            using var db = new AppDbContext();
            var query = db.MenuItems.AsQueryable();
            if (categoryId > 0) query = query.Where(m => m.CategoryId == categoryId);
            var cats = db.MenuCategories.ToList();

            DgMenuItems.ItemsSource = query.OrderBy(m => m.CategoryId).ThenBy(m => m.Name)
                .ToList().Select(m => new MenuItemViewModel
                {
                    ItemId = m.ItemId,
                    Emoji = m.Emoji ?? "🍽️",
                    Name = m.Name,
                    CategoryName = cats.FirstOrDefault(c => c.CategoryId == m.CategoryId)?.Name ?? "—",
                    PriceText = $"{m.Price:N0} đ",
                    Description = m.Description ?? "—",
                    IsAvailable = m.IsAvailable
                }).ToList();

            TxtMenuCount.Text = $"{DgMenuItems.Items.Count} món";
        }

        private void CbMenuFilter_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (CbMenuFilter.SelectedItem == null) return;
            dynamic sel = CbMenuFilter.SelectedItem;
            try { LoadMenuItems((int)sel.CategoryId); } catch { LoadMenuItems(); }
        }

        private void BtnAddMenuItem_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new MenuItemDialog { Owner = this };
            if (dialog.ShowDialog() == true) LoadMenuItems();
        }

        private void BtnEditMenuItem_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as MenuItemViewModel;
            if (vm == null) return;
            using var db = new AppDbContext();
            var item = db.MenuItems.Find(vm.ItemId);
            if (item == null) return;
            var dialog = new MenuItemDialog(item) { Owner = this };
            if (dialog.ShowDialog() == true) LoadMenuItems();
        }

        private void BtnDeleteMenuItem_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as MenuItemViewModel;
            if (vm == null) return;
            if (MessageBox.Show($"Xóa món [{vm.Emoji} {vm.Name}]?", "Xác nhận",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;

            using var db = new AppDbContext();
            var item = db.MenuItems.Find(vm.ItemId);
            if (item == null) return;

            if (db.OrderItems.Any(oi => oi.ItemId == vm.ItemId))
            {
                item.IsAvailable = false;
                db.SaveChanges();
                MessageBox.Show("Món đã có trong đơn cũ nên được ẩn thay vì xóa.",
                    "Thông báo", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                db.MenuItems.Remove(item); db.SaveChanges();
            }
            LoadMenuItems();
        }

        // ── TAB 5: HÓA ĐƠN ──────────────────────────────────────────────────

        private void LoadInvoiceFilter()
        {
            ReloadInvoiceStaffFilter();
            DpFrom.SelectedDate = DateTime.Today.AddDays(-30);
            DpTo.SelectedDate = DateTime.Today;
        }

        /// <summary>Reload danh sách nhân viên trong combobox theo chi nhánh đang chọn</summary>
        private void ReloadInvoiceStaffFilter()
        {
            if (CbFilterStaff == null) return;
            int? branchId = GetSelectedBranchId(CbBranchInvoice);

            using var db = new AppDbContext();
            var staffQuery = db.Accounts
                .Where(a => a.Role == AccountRole.Staff || a.Role == AccountRole.Manager);

            if (branchId.HasValue)
                staffQuery = staffQuery.Where(a => a.BranchId == branchId);

            var staffItems = new List<object>
                { new { AccountId = 0, FullName = "— Tất cả nhân viên —" } };
            staffItems.AddRange(staffQuery.OrderBy(a => a.FullName).ToList().Cast<object>());

            CbFilterStaff.ItemsSource = staffItems;
            CbFilterStaff.DisplayMemberPath = "FullName";
            CbFilterStaff.SelectedIndex = 0;
        }

        private void LoadInvoices()
        {
            if (DgInvoices == null || CbBranchInvoice == null) return;

            using var db = new AppDbContext();
            var from = DpFrom.SelectedDate ?? DateTime.Today.AddDays(-30);
            var to = (DpTo.SelectedDate ?? DateTime.Today).AddDays(1);
            int? branchId = GetSelectedBranchId(CbBranchInvoice);
            int staffId = 0;

            if (CbFilterStaff.SelectedItem != null)
            {
                dynamic sel = CbFilterStaff.SelectedItem;
                try { staffId = (int)sel.AccountId; } catch { }
            }

            var query = db.Invoices.Where(i => i.PaidAt >= from && i.PaidAt < to).AsQueryable();

            if (branchId.HasValue)
            {
                var accountIds = db.Accounts.Where(a => a.BranchId == branchId)
                                  .Select(a => a.AccountId).ToList();
                query = query.Where(i => accountIds.Contains(i.AccountId));
            }

            if (staffId > 0)
                query = query.Where(i => i.AccountId == staffId);

            var list = query.OrderByDescending(i => i.PaidAt).ToList();

            TxtFilterTotal.Text = $"{list.Sum(i => i.TotalAmount):N0} đ";
            TxtInvoiceCount.Text = $"{list.Count} hóa đơn";

            DgInvoices.ItemsSource = list.Select(i =>
            {
                var staff = db.Accounts.Find(i.AccountId);
                var branch = staff?.BranchId.HasValue == true
                             ? db.Branches.Find(staff.BranchId.Value) : null;
                return new InvoiceViewModel
                {
                    InvoiceId = i.InvoiceId,
                    InvoiceNo = i.InvoiceNo,
                    TableName = db.DiningTables.Find(i.TableId)?.TableName ?? "—",
                    StaffName = staff?.FullName ?? "—",
                    BranchName = branch?.Name ?? "—",
                    Subtotal = $"{i.Subtotal:N0} đ",
                    VatAmount = $"{i.VatAmount:N0} đ",
                    TotalAmount = $"{i.TotalAmount:N0} đ",
                    PayMethod = PayMethodText(i.PaymentMethod),
                    PaidAt = i.PaidAt.ToString("HH:mm  dd/MM/yyyy")
                };
            }).ToList();
        }

        private void DateFilter_Changed(object sender, SelectionChangedEventArgs e) { }
        private void CbBranchInvoice_Changed(object sender, SelectionChangedEventArgs e)
        {
            ReloadInvoiceStaffFilter();
            LoadInvoices();
        }
        private void BtnSearchInvoice_Click(object sender, RoutedEventArgs e) => LoadInvoices();

        private void BtnResetInvoiceFilter_Click(object sender, RoutedEventArgs e)
        {
            DpFrom.SelectedDate = DateTime.Today.AddDays(-30);
            DpTo.SelectedDate = DateTime.Today;
            CbFilterStaff.SelectedIndex = 0;
            CbBranchInvoice.SelectedIndex = 0;
            LoadInvoices();
        }

        private void BtnViewInvoiceDetail_Click(object sender, RoutedEventArgs e)
        {
            var vm = (sender as Button)?.Tag as InvoiceViewModel;
            if (vm == null) return;
            new InvoiceDetailDialog(vm.InvoiceId) { Owner = this }.ShowDialog();
        }

        // ── TAB 6: CẢNH BÁO & LOG ────────────────────────────────────────────

        private void LoadAlerts()
        {
            if (DgAlerts == null || CbBranchAlert == null) return;

            int? branchId = GetSelectedBranchId(CbBranchAlert);
            using var db = new AppDbContext();

            List<int>? accountIds = branchId.HasValue
                ? db.Accounts.Where(a => a.BranchId == branchId).Select(a => a.AccountId).ToList()
                : null;

            var query = db.Alerts.Where(a => !a.IsResolved).AsQueryable();
            if (accountIds != null)
                query = query.Where(a => a.AccountId.HasValue && accountIds.Contains(a.AccountId.Value));

            var alerts = query.OrderByDescending(a => a.CreatedAt).ToList().Select(a =>
            {
                var staff = a.AccountId.HasValue ? db.Accounts.Find(a.AccountId.Value) : null;
                var branch = staff?.BranchId.HasValue == true
                             ? db.Branches.Find(staff.BranchId.Value) : null;
                return new AlertViewModel
                {
                    AlertId = a.AlertId,
                    AlertTypeText = a.AlertType.ToString(),
                    SeverityText = a.Severity.ToString(),
                    StaffName = staff?.FullName ?? "—",
                    BranchName = branch?.Name ?? "—",
                    Message = a.Message,
                    CreatedAt = a.CreatedAt.ToString("HH:mm  dd/MM/yyyy")
                };
            }).ToList();

            DgAlerts.ItemsSource = alerts;
            TxtAlertCount.Text = alerts.Count.ToString();
            TxtPendingAlerts.Text = alerts.Count.ToString();
        }

        private void CbBranchAlert_Changed(object sender, SelectionChangedEventArgs e)
        {
            ReloadLogStaffFilter();  // Cập nhật nhân viên log theo chi nhánh
            LoadAlerts();
        }

        private void BtnResolveAll_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Đánh dấu tất cả cảnh báo là đã xử lý?",
                "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;

            using var db = new AppDbContext();
            foreach (var a in db.Alerts.Where(x => !x.IsResolved).ToList())
            {
                a.IsResolved = true;
                a.ResolvedAt = DateTime.Now;
                a.ResolvedNote = "Xử lý hàng loạt bởi " + _currentUser.FullName;
            }
            db.SaveChanges();
            LoadAlerts();
        }

        private void InitLogFilters()
        {
            ReloadLogStaffFilter();

            CbFilterLogType.ItemsSource = new List<string>
                { "— Tất cả —", "Login", "Logout", "OpenTable",
                  "AddItem", "RemoveItem", "UpdateQuantity", "CancelOrder", "Checkout" };
            CbFilterLogType.SelectedIndex = 0;
        }

        /// <summary>Reload danh sách nhân viên trong log theo chi nhánh đang chọn</summary>
        private void ReloadLogStaffFilter()
        {
            if (CbFilterLogStaff == null) return;
            int? branchId = GetSelectedBranchId(CbBranchAlert);

            using var db = new AppDbContext();
            var staffQuery = db.Accounts.AsQueryable();
            if (branchId.HasValue)
                staffQuery = staffQuery.Where(a => a.BranchId == branchId);

            var staffItems = new List<object> { new { AccountId = 0, FullName = "— Tất cả —" } };
            staffItems.AddRange(staffQuery.OrderBy(a => a.FullName).ToList().Cast<object>());
            CbFilterLogStaff.ItemsSource = staffItems;
            CbFilterLogStaff.DisplayMemberPath = "FullName";
            CbFilterLogStaff.SelectedIndex = 0;
        }

        private void LoadLogs()
        {
            if (DgLogs == null || CbFilterLogStaff == null) return;

            int? branchId = GetSelectedBranchId(CbBranchAlert);
            int staffId = 0;
            string? typeFilter = CbFilterLogType?.SelectedItem as string;
            if (typeFilter == "— Tất cả —") typeFilter = null;

            if (CbFilterLogStaff.SelectedItem != null)
            {
                dynamic sel = CbFilterLogStaff.SelectedItem;
                try { staffId = (int)sel.AccountId; } catch { }
            }

            using var db = new AppDbContext();

            List<int>? branchAccountIds = branchId.HasValue
                ? db.Accounts.Where(a => a.BranchId == branchId).Select(a => a.AccountId).ToList()
                : null;

            var query = db.ActionLogs.AsQueryable();
            if (branchAccountIds != null)
                query = query.Where(l => branchAccountIds.Contains(l.AccountId));
            if (staffId > 0)
                query = query.Where(l => l.AccountId == staffId);

            DgLogs.ItemsSource = query.OrderByDescending(l => l.Timestamp).Take(200).ToList()
                .Select(l =>
                {
                    var staff = db.Accounts.Find(l.AccountId);
                    var branch = staff?.BranchId.HasValue == true
                                 ? db.Branches.Find(staff.BranchId.Value) : null;
                    return new LogViewModel
                    {
                        StaffName = staff?.FullName ?? "—",
                        BranchName = branch?.Name ?? "—",
                        ActionTypeText = l.ActionType.ToString(),
                        Description = l.Description ?? "—",
                        Timestamp = l.Timestamp.ToString("HH:mm:ss  dd/MM/yyyy")
                    };
                })
                .Where(l => typeFilter == null || l.ActionTypeText == typeFilter)
                .ToList();
        }

        private void CbFilterLogStaff_Changed(object sender, SelectionChangedEventArgs e)
            => LoadLogs();

        // ── RETRAIN ──────────────────────────────────────────────────────────

        private async void BtnRetrainModel_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show("Yêu cầu train lại AI model?",
                "Retrain", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;

            string result = await AnomalyDetector.RequestRetrainAsync();
            MessageBox.Show(result.Contains("started")
                ? "✅ Retrain đang chạy ngầm..."
                : "⚠️ " + result,
                "Retrain", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        // ── ĐĂNG XUẤT ────────────────────────────────────────────────────────

        private void BtnLogout_Click(object sender, RoutedEventArgs e)
        {
            _clockTimer.Stop();
            new MainWindow().Show();
            this.Close();
        }

        // ── HELPER ───────────────────────────────────────────────────────────

        private static string PayMethodText(PaymentMethod m) => m switch
        {
            PaymentMethod.Cash => "💵 Tiền mặt",
            PaymentMethod.Card => "💳 Thẻ",
            PaymentMethod.Transfer => "📱 Chuyển khoản",
            _ => m.ToString()
        };
    }
}