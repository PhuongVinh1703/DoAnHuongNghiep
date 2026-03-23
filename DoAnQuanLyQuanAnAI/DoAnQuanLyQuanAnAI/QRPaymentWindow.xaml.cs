using System;
using System.Net.Http;
using System.Windows;
using System.Windows.Media.Imaging;

namespace DoAnQuanLyQuanAnAI
{
    public partial class QRPaymentWindow : Window
    {
        // ── Thông tin tài khoản ngân hàng ────────────────────────────────────
        private const string BANK_ID = "ICB";               // VietinBank
        private const string ACCOUNT_NO = "108876927706";
        private const string ACCOUNT_NAME = "TRAN PHUONG VINH";

        public QRPaymentWindow(decimal totalAmount, string invoiceNo)
        {
            InitializeComponent();

            TxtAmount.Text = $"{totalAmount:N0} đ";
            TxtInvoiceNo.Text = invoiceNo;

            LoadQRCode(totalAmount, invoiceNo);
        }

        private async void LoadQRCode(decimal amount, string invoiceNo)
        {
            try
            {
                // Làm tròn về số nguyên (VietQR không nhận số thập phân)
                long amountInt = (long)Math.Round(amount);

                string url = $"https://img.vietqr.io/image/{BANK_ID}-{ACCOUNT_NO}-compact2.png" +
                             $"?amount={amountInt}" +
                             $"&addInfo={Uri.EscapeDataString(invoiceNo)}" +
                             $"&accountName={Uri.EscapeDataString(ACCOUNT_NAME)}";

                using var client = new HttpClient();
                client.Timeout = TimeSpan.FromSeconds(15);
                var imageBytes = await client.GetByteArrayAsync(url);

                // Chuyển bytes thành ảnh
                var bitmap = new BitmapImage();
                using var stream = new System.IO.MemoryStream(imageBytes);
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.StreamSource = stream;
                bitmap.EndInit();
                bitmap.Freeze();

                // Cập nhật UI trên UI thread
                Dispatcher.Invoke(() =>
                {
                    QrImage.Source = bitmap;
                    TxtQrStatus.Text = "✅ Dùng app ngân hàng, MoMo, ZaloPay hoặc VNPay để quét";
                    TxtQrStatus.Foreground = System.Windows.Media.Brushes.Green;
                });
            }
            catch (Exception ex)
            {
                Dispatcher.Invoke(() =>
                {
                    TxtQrStatus.Text = "⚠️ Không tải được QR. Vui lòng chuyển khoản thủ công.\n" + ex.Message;
                    TxtQrStatus.Foreground = System.Windows.Media.Brushes.OrangeRed;
                });
            }
        }

        private void BtnClose_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}
