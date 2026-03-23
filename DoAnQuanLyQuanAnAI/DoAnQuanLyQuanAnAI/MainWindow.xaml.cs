using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Helpers;
using DoAnQuanLyQuanAnAI.Models;

namespace DoAnQuanLyQuanAnAI
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            Loaded += (s, e) => TxtUsername.Focus();
        }

        private void BtnLogin_Click(object sender, RoutedEventArgs e) => TryLogin();

        private void TxtInput_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter) TryLogin();
        }

        private void TryLogin()
        {
            string username = TxtUsername.Text.Trim();
            string password = TxtPassword.Visibility == Visibility.Visible
                              ? TxtPassword.Password
                              : TxtPasswordVisible.Text;

            if (string.IsNullOrEmpty(username) || string.IsNullOrEmpty(password))
            {
                ShowError("Vui lòng nhập đầy đủ thông tin!");
                return;
            }

            using var db = new AppDbContext();
            var account = db.Accounts.FirstOrDefault(
                a => a.Username == username && a.IsActive);

            // Dùng PasswordHelper.Verify hỗ trợ cả BCrypt mới lẫn SHA256 cũ
            if (account == null || !PasswordHelper.Verify(password, account.PasswordHash))
            {
                ShowError("Tên đăng nhập hoặc mật khẩu không đúng!");
                return;
            }

            // Tự động nâng cấp hash SHA256 cũ → BCrypt mới khi user đăng nhập
            if (PasswordHelper.NeedsUpgrade(account.PasswordHash))
            {
                account.PasswordHash = PasswordHelper.Hash(password);
                db.SaveChanges();
            }

            Window next = account.Role == AccountRole.Owner
                ? new OwnerDashboardWindow(account)
                : (Window)new StaffPOSWindow(account);

            next.Show();
            this.Close();
        }

        private void ShowError(string msg)
        {
            TxtError.Text = msg;
            ErrorBox.Visibility = Visibility.Visible;
        }

        private void BtnTogglePassword_Click(object sender, RoutedEventArgs e)
        {
            if (TxtPassword.Visibility == Visibility.Visible)
            {
                TxtPasswordVisible.Text = TxtPassword.Password;
                TxtPassword.Visibility = Visibility.Collapsed;
                TxtPasswordVisible.Visibility = Visibility.Visible;
                BtnTogglePassword.Content = "🙈";
            }
            else
            {
                TxtPassword.Password = TxtPasswordVisible.Text;
                TxtPasswordVisible.Visibility = Visibility.Collapsed;
                TxtPassword.Visibility = Visibility.Visible;
                BtnTogglePassword.Content = "👁";
            }
        }

        private void TxtPassword_PasswordChanged(object sender, RoutedEventArgs e)
        {
            if (ErrorBox.Visibility == Visibility.Visible)
                ErrorBox.Visibility = Visibility.Collapsed;
        }
    }
}