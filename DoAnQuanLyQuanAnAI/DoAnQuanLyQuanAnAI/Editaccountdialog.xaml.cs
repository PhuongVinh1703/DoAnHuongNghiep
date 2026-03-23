using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Models;

namespace DoAnQuanLyQuanAnAI
{
    public partial class EditAccountDialog : Window
    {
        private readonly int _accountId;
        private readonly Account _currentUser;

        public EditAccountDialog(StaffViewModel vm, Account currentUser)
        {
            InitializeComponent();
            _accountId = vm.AccountId;
            _currentUser = currentUser;

            TxtFullName.Text = vm.FullName;
            TxtPhone.Text = vm.Phone == "—" ? "" : vm.Phone;
            CbGender.SelectedIndex = vm.GenderValue;

            InitRoles(vm);
            LoadBranches(vm.BranchId);
            Loaded += (s, e) => TxtFullName.Focus();
        }

        private void InitRoles(StaffViewModel vm)
        {
            CbRole.Items.Clear();

            if (_currentUser.Role == AccountRole.Owner)
            {
                CbRole.Items.Add(new ComboBoxItem { Content = "👤 Nhân viên", Tag = "1" });
                CbRole.Items.Add(new ComboBoxItem { Content = "🏢 Quản lý", Tag = "2" });
                CbRole.Items.Add(new ComboBoxItem { Content = "👑 Owner", Tag = "0" });

                // Chọn đúng vai trò hiện tại
                string currentTag = vm.RoleText.Contains("Owner") ? "0"
                                  : vm.RoleText.Contains("Quản lý") ? "2" : "1";
                foreach (ComboBoxItem item in CbRole.Items)
                    if (item.Tag?.ToString() == currentTag) { item.IsSelected = true; break; }
            }
            else
            {
                // Manager chỉ thấy và không thể đổi vai trò
                CbRole.Items.Add(new ComboBoxItem { Content = "👤 Nhân viên", Tag = "1", IsSelected = true });
                CbRole.IsEnabled = false;
            }

            if (CbRole.SelectedIndex < 0) CbRole.SelectedIndex = 0;
        }

        private void LoadBranches(int? currentBranchId)
        {
            using var db = new AppDbContext();
            var branches = db.Branches
                .Where(b => b.IsActive).OrderBy(b => b.Name)
                .Select(b => new BranchItem { BranchId = b.BranchId, Name = b.Name })
                .ToList();

            var items = new List<BranchItem>
                { new BranchItem { BranchId = 0, Name = "— Chưa phân công —" } };
            items.AddRange(branches);

            CbBranch.ItemsSource = items;
            CbBranch.SelectedItem = currentBranchId.HasValue
                ? items.FirstOrDefault(b => b.BranchId == currentBranchId.Value) ?? items[0]
                : items[0];

            // Manager không được thay đổi chi nhánh
            if (_currentUser.Role == AccountRole.Manager)
            {
                CbBranch.IsEnabled = false;
                TxtBranchLocked.Visibility = Visibility.Visible;
            }
        }

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            string fullName = TxtFullName.Text.Trim();
            string phone = TxtPhone.Text.Trim();

            if (string.IsNullOrEmpty(fullName)) { ShowError("Vui lòng nhập họ và tên!"); return; }

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

            if (role == AccountRole.Manager && branchId == null)
            {
                ShowError("Quản lý phải được gán vào một chi nhánh cụ thể!");
                return;
            }

            try
            {
                using var db = new AppDbContext();
                var acc = db.Accounts.Find(_accountId);
                if (acc == null) return;

                // Chặn hạ cấp Owner cuối cùng
                if (acc.Role == AccountRole.Owner && role != AccountRole.Owner)
                {
                    int ownerCount = db.Accounts.Count(
                        a => a.Role == AccountRole.Owner && a.IsActive && a.AccountId != _accountId);
                    if (ownerCount == 0)
                    {
                        ShowError("Không thể thay đổi — đây là Owner duy nhất!");
                        return;
                    }
                }

                acc.FullName = fullName;
                acc.Phone = string.IsNullOrEmpty(phone) ? null : phone;
                acc.Role = role;
                acc.Gender = gender;
                acc.BranchId = branchId;
                acc.Avatar = role switch
                {
                    AccountRole.Owner => "👑",
                    AccountRole.Manager => "🏢",
                    _ => "👤"
                };
                acc.UpdatedAt = DateTime.Now;
                db.SaveChanges();

                DialogResult = true;
                Close();
            }
            catch (Exception ex)
            {
                ShowError("Lỗi: " + ex.Message);
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
