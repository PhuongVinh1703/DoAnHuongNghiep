using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Helpers;
using DoAnQuanLyQuanAnAI.Models;

namespace DoAnQuanLyQuanAnAI
{
    public class BranchItem
    {
        public int BranchId { get; set; }
        public string Name { get; set; } = "";
        public string DisplayName => BranchId == 0 ? "— Chưa phân công —" : $"🏢 {Name}";
    }

    public partial class AddAccountDialog : Window
    {
        private readonly Account _currentUser;

        public AddAccountDialog(Account currentUser)
        {
            InitializeComponent();
            _currentUser = currentUser;
            InitRoles();
            LoadBranches();
            Loaded += (s, e) => TxtFullName.Focus();
        }

        private void InitRoles()
        {
            CbRole.Items.Clear();

            if (_currentUser.Role == AccountRole.Owner)
            {
                // Owner có thể tạo tất cả vai trò
                CbRole.Items.Add(new ComboBoxItem { Content = "👤 Nhân viên", Tag = "1", IsSelected = true });
                CbRole.Items.Add(new ComboBoxItem { Content = "🏢 Quản lý", Tag = "2" });
                CbRole.Items.Add(new ComboBoxItem { Content = "👑 Owner", Tag = "0" });
            }
            else
            {
                // Manager chỉ có thể tạo Nhân viên
                CbRole.Items.Add(new ComboBoxItem { Content = "👤 Nhân viên", Tag = "1", IsSelected = true });
                CbRole.IsEnabled = false;

                // Tiêu đề cũng thay đổi
                TxtTitle.Text = "Thêm nhân viên mới";
            }

            CbRole.SelectedIndex = 0;
        }

        private void LoadBranches()
        {
            using var db = new AppDbContext();
            var branches = db.Branches
                .Where(b => b.IsActive)
                .OrderBy(b => b.Name)
                .Select(b => new BranchItem { BranchId = b.BranchId, Name = b.Name })
                .ToList();

            var items = new List<BranchItem>
            {
                new BranchItem { BranchId = 0, Name = "— Chưa phân công —" }
            };
            items.AddRange(branches);

            CbBranch.ItemsSource = items;
            CbBranch.SelectedIndex = 0;

            // Manager → khóa chi nhánh theo chi nhánh của họ
            if (_currentUser.Role == AccountRole.Manager && _currentUser.BranchId.HasValue)
            {
                var locked = items.FirstOrDefault(b => b.BranchId == _currentUser.BranchId.Value);
                if (locked != null) CbBranch.SelectedItem = locked;
                CbBranch.IsEnabled = false;
                TxtBranchLocked.Visibility = Visibility.Visible;
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            string fullName = TxtFullName.Text.Trim();
            string username = TxtUsername.Text.Trim();
            string password = TxtPassword.Password;
            string phone = TxtPhone.Text.Trim();

            if (string.IsNullOrEmpty(fullName)) { ShowError("Vui lòng nhập họ và tên!"); return; }
            if (string.IsNullOrEmpty(username)) { ShowError("Vui lòng nhập tên đăng nhập!"); return; }
            if (username.Length < 4) { ShowError("Tên đăng nhập phải ít nhất 4 ký tự!"); return; }
            if (string.IsNullOrEmpty(password)) { ShowError("Vui lòng nhập mật khẩu!"); return; }
            if (password.Length < 6) { ShowError("Mật khẩu phải ít nhất 6 ký tự!"); return; }

            var roleItem = CbRole.SelectedItem as ComboBoxItem;
            var genderItem = CbGender.SelectedItem as ComboBoxItem;
            var branchItem = CbBranch.SelectedItem as BranchItem;

            AccountRole role = roleItem?.Tag?.ToString() switch
            {
                "0" => AccountRole.Owner,
                "2" => AccountRole.Manager,
                _ => AccountRole.Staff
            };

            Gender gender = genderItem?.Tag?.ToString() switch
            {
                "0" => Gender.Male,
                "1" => Gender.Female,
                _ => Gender.Other
            };

            int? branchId = branchItem?.BranchId == 0 ? null : branchItem?.BranchId;

            // Manager bắt buộc phải có chi nhánh
            if (role == AccountRole.Manager && branchId == null)
            {
                ShowError("Quản lý phải được gán vào một chi nhánh cụ thể!");
                return;
            }

            try
            {
                using var db = new AppDbContext();

                if (db.Accounts.Any(a => a.Username == username))
                {
                    ShowError($"Tên đăng nhập \"{username}\" đã tồn tại!");
                    return;
                }

                string avatar = role switch
                {
                    AccountRole.Owner => "👑",
                    AccountRole.Manager => "🏢",
                    _ => "👤"
                };

                db.Accounts.Add(new Account
                {
                    FullName = fullName,
                    Username = username,
                    PasswordHash = PasswordHelper.Hash(password),
                    Phone = string.IsNullOrEmpty(phone) ? null : phone,
                    Role = role,
                    Gender = gender,
                    BranchId = branchId,
                    Avatar = avatar,
                    IsActive = true,
                    JoinDate = DateTime.Today,
                    CreatedAt = DateTime.Now
                });
                db.SaveChanges();

                string roleText = role == AccountRole.Manager ? "Quản lý" : "Nhân viên";
                MessageBox.Show(
                    $"Đã thêm {roleText} [{fullName}] thành công!\nTên đăng nhập: {username}",
                    "Thành công", MessageBoxButton.OK, MessageBoxImage.Information);

                DialogResult = true;
                Close();
            }
            catch (Exception ex)
            {
                ShowError("Lỗi khi lưu: " + ex.Message);
            }
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            DialogResult = false;
            Close();
        }

        private void ShowError(string msg)
        {
            TxtError.Text = "⚠️ " + msg;
            ErrorBox.Visibility = Visibility.Visible;
        }
    }
}
