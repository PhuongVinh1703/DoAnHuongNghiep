using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Xml.Linq;
using DoAnQuanLyQuanAnAI.Data;
using DoAnQuanLyQuanAnAI.Models;
using ModelMenuItem = DoAnQuanLyQuanAnAI.Models.MenuItem;

namespace DoAnQuanLyQuanAnAI
{
    public partial class MenuItemDialog : Window
    {
        private int? _editItemId = null;

        // Danh sách emoji thực phẩm
        private static readonly string[] FoodEmojis =
        {
            // Thịt & gia cầm
            "🥩","🍖","🍗","🥓","🌭","🍔","🌮","🌯","🥙",
            // Hải sản
            "🦐","🦑","🦀","🐟","🍤","🦞","🐠","🦈","🐙",
            // Cơm / Mì / Bún
            "🍚","🍜","🍝","🍛","🥗","🍲","🫕","🥘","🍱",
            // Rau củ
            "🥦","🥕","🌽","🥬","🍅","🧅","🧄","🥑","🍆",
            // Bánh & Bún
            "🥐","🍞","🥖","🫓","🥨","🧆","🥚","🍳","🥞",
            // Đồ uống
            "🧃","🥤","☕","🍵","🧋","🍺","🍹","🥛","🫖",
            // Tráng miệng
            "🍰","🎂","🍮","🍨","🍦","🧁","🍩","🍪","🍫",
            // Khai vị & khác
            "🥗","🥟","🧇","🫔","🍣","🍱","🥫","🫙","🍽️",
        };

        public MenuItemDialog(ModelMenuItem? existingItem = null)
        {
            InitializeComponent();
            BuildEmojiPanel();
            LoadCategories();

            if (existingItem != null)
            {
                _editItemId = existingItem.ItemId;
                TxtHeaderTitle.Text = "Sửa món ăn";
                TxtHeaderEmoji.Text = existingItem.Emoji ?? "🍽️";
                TxtSelectedEmoji.Text = existingItem.Emoji ?? "🍽️";
                TxtName.Text = existingItem.Name;
                TxtDescription.Text = existingItem.Description ?? "";
                TxtPrice.Text = existingItem.Price.ToString("0");
                ChkAvailable.IsChecked = existingItem.IsAvailable;

                // Chọn đúng danh mục
                foreach (var item in CbCategory.Items)
                {
                    if (item is MenuCategory cat && cat.CategoryId == existingItem.CategoryId)
                    {
                        CbCategory.SelectedItem = item;
                        break;
                    }
                }
            }

            Loaded += (s, e) => TxtName.Focus();
        }

        // ── Build bảng emoji ──────────────────────────────────────────────────

        private void BuildEmojiPanel()
        {
            EmojiPanel.Children.Clear();
            foreach (var emoji in FoodEmojis)
            {
                var btn = new Button
                {
                    Content = emoji,
                    FontSize = 18,
                    Width = 32,
                    Height = 32,
                    Margin = new Thickness(2),
                    Background = Brushes.Transparent,
                    BorderThickness = new Thickness(0),
                    Cursor = Cursors.Hand,
                    ToolTip = emoji
                };
                btn.Click += (s, e) =>
                {
                    TxtSelectedEmoji.Text = emoji;
                    TxtHeaderEmoji.Text = emoji;
                };
                EmojiPanel.Children.Add(btn);
            }
        }

        private void BtnPickEmoji_Click(object sender, MouseButtonEventArgs e)
        {
            // Click vào ô emoji lớn → scroll bảng emoji lên đầu để dễ chọn
            // (bảng đã luôn hiển thị, không cần làm thêm gì)
        }

        // ── Load danh mục ─────────────────────────────────────────────────────

        private void LoadCategories()
        {
            using var db = new AppDbContext();
            var cats = db.MenuCategories.OrderBy(c => c.DisplayOrder).ToList();
            CbCategory.ItemsSource = cats;
            CbCategory.DisplayMemberPath = "Name";
            if (cats.Any()) CbCategory.SelectedIndex = 0;
        }

        // ── Lưu ──────────────────────────────────────────────────────────────

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            string name = TxtName.Text.Trim();
            string emoji = TxtSelectedEmoji.Text;
            string priceStr = TxtPrice.Text.Trim();

            if (string.IsNullOrEmpty(name))
            {
                ShowError("Vui lòng nhập tên món!");
                return;
            }
            if (!decimal.TryParse(priceStr, out decimal price) || price <= 0)
            {
                ShowError("Giá món không hợp lệ! Nhập số nguyên dương.");
                return;
            }
            if (CbCategory.SelectedItem is not MenuCategory selectedCat)
            {
                ShowError("Vui lòng chọn danh mục!");
                return;
            }

            try
            {
                using var db = new AppDbContext();

                if (_editItemId.HasValue)
                {
                    // Sửa món
                    var item = db.MenuItems.Find(_editItemId.Value);
                    if (item == null) return;

                    item.Name = name;
                    item.Emoji = emoji;
                    item.Description = TxtDescription.Text.Trim();
                    item.Price = price;
                    item.CategoryId = selectedCat.CategoryId;
                    item.IsAvailable = ChkAvailable.IsChecked == true;
                }
                else
                {
                    // Thêm mới
                    db.MenuItems.Add(new ModelMenuItem
                    {
                        Name = name,
                        Emoji = emoji,
                        Description = TxtDescription.Text.Trim(),
                        Price = price,
                        CategoryId = selectedCat.CategoryId,
                        IsAvailable = ChkAvailable.IsChecked == true
                    });
                }

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