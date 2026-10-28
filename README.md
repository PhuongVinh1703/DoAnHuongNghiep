# 🍽️ Reserve & Relish — AI Smart Restaurant Management System

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![WPF](https://img.shields.io/badge/WPF-.NET_9-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)
![Python](https://img.shields.io/badge/Python-Flask-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![SQL Server](https://img.shields.io/badge/SQL_Server-MSSQL-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)

**Hệ thống quản lý nhà hàng thông minh tích hợp AI — Đồ án tốt nghiệp**

</div>

---

## 📋 Mục lục

- [Giới thiệu](#-giới-thiệu)
- [Kiến trúc hệ thống](#-kiến-trúc-hệ-thống)
- [Các thành phần](#-các-thành-phần)
- [Tính năng nổi bật](#-tính-năng-nổi-bật)
- [Công nghệ sử dụng](#-công-nghệ-sử-dụng)
- [Cài đặt và Chạy](#-cài-đặt--chạy)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Module AI](#-module-ai)
- [Tác giả](#-tác-giả)

---

## 🎯 Giới thiệu

**Reserve & Relish** là hệ thống quản lý nhà hàng toàn diện được xây dựng như đồ án hướng nghiệp, kết hợp:

- **Ứng dụng di động** (Flutter) dành cho khách hàng, nhân viên và quản lý
- **Ứng dụng desktop** (WPF / .NET 9) dành cho chủ nhà hàng
- **Module AI** (Python / scikit-learn) phát hiện gian lận giao dịch thời gian thực
- **Cơ sở dữ liệu đám mây** (Supabase / PostgreSQL) với Realtime subscriptions

Hệ thống hỗ trợ **4 vai trò** người dùng: Chủ nhà hàng (Owner), Quản lý (Manager), Nhân viên (Staff) và Khách hàng (Customer).

---

## 🏗️ Kiến trúc hệ thống

```
┌───────────────────────────────────────────────────────────────┐
│                      CLIENT LAYER                             │
│                                                               │
│   ┌──────────────────────┐      ┌────────────────────────┐   │
│   │   Flutter Mobile App │      │  WPF Desktop (Owner)   │   │
│   │   (Android / iOS)    │      │  .NET 9 / Windows      │   │
│   └──────────┬───────────┘      └────────────┬───────────┘   │
└──────────────┼──────────────────────────────  ┼──────────────┘
               │                               │
               ▼                               ▼
┌───────────────────────────────────────────────────────────────┐
│                     DATABASE LAYER                            │
│                                                               │
│   ┌──────────────────────────┐  ┌─────────────────────────┐  │
│   │   Supabase (PostgreSQL)  │  │  SQL Server (MSSQL)     │  │
│   │   - REST API             │  │  - Entity Framework Core │  │
│   │   - Realtime WebSocket   │  │  - BCrypt Password Hash  │  │
│   │   - RPC via pgcrypto     │  └─────────────────────────┘  │
│   └──────────────────────────┘                                │
└───────────────────────────────────────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────────────────────────┐
│                       AI MODULE                               │
│                                                               │
│   ┌─────────────────────────────────────────────────────┐    │
│   │   Python Flask API (port 5050)                       │    │
│   │   scikit-learn — Random Forest / Isolation Forest    │    │
│   │   Phát hiện bất thường giao dịch (6 loại anomaly)   │    │
│   └─────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┘
```

---

## 📦 Các thành phần

### 1. 📱 Flutter Mobile App (`DoAnQuanLyQuanAnAI_MobileApp/`)
Ứng dụng di động đa nền tảng (Android/iOS) phục vụ 3 role: Manager, Staff, Customer.

### 2. 🖥️ WPF Desktop App (`DoAnQuanLyQuanAnAI/`)
Ứng dụng Windows dành riêng cho chủ nhà hàng (Owner), xây dựng bằng WPF + .NET 9.

### 3. 🤖 AI Module (`AI_Module/`)
Flask REST API chạy mô hình Machine Learning phát hiện giao dịch bất thường.

---

## ✨ Tính năng nổi bật

### 👑 Owner (WPF Desktop)
| Tính năng | Mô tả |
|-----------|-------|
| Dashboard tổng quan | Doanh thu, đơn hàng, nhân viên theo thời gian thực |
| Quản lý tài khoản | CRUD nhân viên, phân quyền vai trò |
| Xem hóa đơn chi tiết | Lịch sử giao dịch, in hóa đơn |
| QR Payment | Thanh toán qua mã QR |
| AI Alerts | Cảnh báo giao dịch bất thường do module AI phát hiện |
| Menu Management | Quản lý món ăn và giá cả |

### 📊 Manager (Flutter Mobile)
| Tính năng | Mô tả |
|-----------|-------|
| Dashboard AI | Biểu đồ doanh thu, KPI theo kỳ |
| Quản lý nhân viên | Thêm/sửa/xóa staff, phân ca |
| Quản lý khách hàng | CRM — tìm kiếm, lọc, lịch sử mua |
| AI Alerts Screen | Xem và xử lý cảnh báo gian lận thời gian thực |
| Quản lý đặt bàn | Xem, duyệt, hủy reservation |
| Quản lý khuyến mãi | Tạo và áp dụng mã giảm giá |
| Menu Availability | Bật/tắt món ăn theo ngày |

### 🧑‍🍳 Staff (Flutter Mobile)
| Tính năng | Mô tả |
|-----------|-------|
| POS Interface | Giao diện bán hàng tại bàn |
| Quản lý bàn | Xem trạng thái bàn, ghép bàn |
| Tạo order | Chọn món, thêm ghi chú, xác nhận |
| Checkout | Tính tiền, áp voucher, thanh toán |
| Tra cứu khách hàng | Tìm theo tên/số điện thoại |
| Đăng ký khách | Tạo tài khoản khách tại quầy |
| Hóa đơn | Xem hóa đơn thành công, xuất QR |

### 👤 Customer (Flutter Mobile)
| Tính năng | Mô tả |
|-----------|-------|
| Đặt bàn trực tuyến | Chọn chi nhánh, ngày, giờ, số người, ghi chú |
| Xem thực đơn | Tra cứu món ăn, danh mục, giá cả và mô tả món |
| Tích điểm & Loyalty | Xem điểm thưởng, lịch sử |
| Voucher | Nhận và dùng mã giảm giá |
| QR Membership | Thẻ thành viên dạng QR code |
| Lịch sử hóa đơn | Xem các hóa đơn đã thanh toán |
| Đăng ký / OTP | Đăng ký tài khoản với xác thực email OTP |

### 🔐 Xác thực & Bảo mật
- Mật khẩu mã hóa **BCrypt** qua PostgreSQL `pgcrypto`
- Token lưu trong **Flutter Secure Storage** (Keychain/Keystore)
- RPC PostgreSQL an toàn: `verify_password`, `register_customer`, `change_account_password`
- OTP Email qua Supabase Auth SMTP

---

## 🛠️ Công nghệ sử dụng

### Mobile App (Flutter)
| Thư viện | Phiên bản | Mục đích |
|----------|-----------|----------|
| `supabase_flutter` | ^2.12.4 | Database client + Realtime |
| `provider` | ^6.1.5 | State management |
| `flutter_secure_storage` | ^10.1.0 | Lưu token bảo mật |
| `dio` | ^5.9.2 | HTTP client |
| `fl_chart` | ^1.2.0 | Biểu đồ dashboard |
| `mobile_scanner` | ^7.2.0 | Quét QR code |
| `qr_flutter` | ^4.1.0 | Tạo QR code |
| `google_fonts` | ^8.1.0 | Typography |
| `connectivity_plus` | ^7.1.1 | Kiểm tra kết nối mạng |

### WPF Desktop (.NET 9)
| Thư viện | Phiên bản | Mục đích |
|----------|-----------|----------|
| `Entity Framework Core` | 9.0.13 | ORM + Migrations |
| `EF Core SQL Server` | 9.0.13 | MSSQL Provider |
| `BCrypt.Net-Next` | 4.1.0 | Mã hóa mật khẩu |

### AI Module (Python)
| Thư viện | Mục đích |
|----------|----------|
| `Flask` | REST API server |
| `scikit-learn` | Machine Learning models |
| `pandas` | Xử lý dữ liệu |
| `numpy` | Tính toán số học |
| `gunicorn` | WSGI production server |

---

## 🚀 Cài đặt & Chạy

### Yêu cầu hệ thống
- **Flutter SDK** >= 3.0 (Dart >= 3.11)
- **.NET SDK** 9.0
- **Python** >= 3.9
- **SQL Server** (cho WPF app)
- Tài khoản **Supabase** (cho mobile app)

---

### 📱 Mobile App

```bash
cd DoAnQuanLyQuanAnAI_MobileApp

# Cài dependencies
flutter pub get

# Cấu hình Supabase trong lib/main.dart:
# const String supabaseUrl = 'https://<your-project>.supabase.co';
# const String supabaseAnonKey = 'eyJhbGci...'; // JWT anon key

# Chạy app
flutter run

# Build APK
flutter build apk --release
```

> ⚠️ **Lưu ý**: Supabase free tier tự động **pause project sau 7 ngày** không hoạt động.
> Vào https://supabase.com/dashboard và click **Restore project** nếu bị pause.

---

### 🖥️ Desktop App (WPF)

```bash
cd DoAnQuanLyQuanAnAI

# Cập nhật appsettings.json với connection string SQL Server của bạn

# Chạy migrations
dotnet ef database update

# Build & chạy
dotnet run
# Hoặc mở DoAnQuanLyQuanAnAI.sln bằng Visual Studio 2022+
```

---

### 🤖 AI Module

```bash
cd AI_Module

# Tạo virtual environment
python -m venv venv
venv\Scripts\activate

# Cài dependencies
pip install -r requirements.txt

# Chạy API server (port 5050)
python predict_api.py

# Hoặc dùng script tự động:
install_and_run.bat
```

---

## 📁 Cấu trúc thư mục

```
DoAnHuongNghiep/
├── 📱 DoAnQuanLyQuanAnAI_MobileApp/    # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                   # Entry point + Supabase init
│   │   ├── config/                     # Constants, API config
│   │   ├── core/
│   │   │   ├── constants/              # API URLs, colors, enums
│   │   │   ├── network/                # Dio client + interceptors
│   │   │   ├── storage/                # Secure storage, local cache
│   │   │   └── utils/                  # Error handler, formatters
│   │   ├── models/                     # Data models (auth, menu, order...)
│   │   ├── services/                   # Business logic + Supabase queries
│   │   │   ├── auth_service.dart       # Login, logout, OTP, register
│   │   │   ├── menu_service.dart
│   │   │   ├── order_service.dart
│   │   │   ├── invoice_service.dart
│   │   │   ├── customer_service.dart
│   │   │   ├── dashboard_service.dart
│   │   │   └── ...
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── splash_screen.dart
│   │   │   ├── manager/                # 8 screens cho Manager
│   │   │   ├── staff/                  # 8 screens cho Staff
│   │   │   └── customer/               # 8 screens cho Customer
│   │   ├── widgets/                    # Reusable UI components
│   │   ├── theme/                      # AppTheme, AppColors
│   │   └── l10n/                       # Đa ngôn ngữ (i18n)
│   └── pubspec.yaml
│
├── 🖥️ DoAnQuanLyQuanAnAI/              # WPF Desktop App (Owner)
│   └── DoAnQuanLyQuanAnAI/
│       ├── MainWindow.xaml             # Login window
│       ├── OwnerDashboardWindow.xaml   # Dashboard chính
│       ├── StaffPOSWindow.xaml         # POS Interface
│       ├── Models/                     # EF Core entities
│       ├── Migrations/                 # Database migrations
│       ├── Helpers/                    # Utility classes
│       └── appsettings.json
│
└── 🤖 AI_Module/                       # Python Flask AI API
    ├── predict_api.py                  # Flask REST endpoints
    ├── train_model.py                  # Training script
    ├── GenerateTrainingData.py         # Synthetic data generator
    ├── model_config.json               # Model metadata & thresholds
    ├── anomaly_model.pkl               # Isolation Forest model
    ├── binary_model.pkl                # Binary classifier
    ├── multi_model.pkl                 # Multi-class classifier
    ├── scaler.pkl                      # Feature scaler
    ├── label_encoder.pkl               # Label encoder
    ├── training_data.csv               # Dataset (11,960 samples)
    ├── feedback_data.jsonl             # Feedback loop data
    └── requirements.txt
```

---

## 🤖 Module AI

### Mô hình phát hiện bất thường giao dịch

| Mô hình | Loại | Mục đích |
|---------|------|----------|
| `anomaly_model.pkl` | Isolation Forest | Phát hiện điểm bất thường tổng quát |
| `binary_model.pkl` | Random Forest | Phân loại: bình thường / bất thường |
| `multi_model.pkl` | Random Forest | Phân loại loại bất thường cụ thể |

### Features phân tích (9 đặc trưng)

| Feature | Ý nghĩa |
|---------|---------|
| `session_duration` | Thời gian phiên làm việc |
| `num_items_ordered` | Số lượng món đặt |
| `cancel_rate` | Tỷ lệ hủy order |
| `transaction_hour` | Giờ giao dịch |
| `checkout_time_sec` | Thời gian thanh toán (giây) |
| `void_count` | Số lần void transaction |
| `discount_percent` | Phần trăm giảm giá áp dụng |
| `add_remove_ratio` | Tỷ lệ thêm/xóa món |
| `items_removed_after_confirm` | Số món xóa sau xác nhận |

### 6 loại Anomaly được phát hiện

| Loại | Mô tả |
|------|-------|
| `AddRemoveAnomaly` | Thêm/xóa món bất thường sau khi confirm |
| `CancelAfterPayment` | Hủy giao dịch sau khi thanh toán |
| `ExcessiveDiscount` | Áp dụng giảm giá quá mức cho phép |
| `FrequentCancellation` | Hủy order liên tục trong phiên |
| `SpeedAnomaly` | Thời gian checkout quá nhanh/chậm |
| `UnusualHours` | Giao dịch ngoài giờ hoạt động |

### Thông số mô hình
- **Training samples**: 11,960 (trong đó 4,960 anomaly)
- **AUC Score**: 1.0 | **CV F1 Mean**: 1.0
- **Model version**: 3.0
- **Anomaly threshold**: 0.5 | **High-risk threshold**: 0.75

---

## 📊 Roles & Quyền hạn

```
Role 0 — Owner     → WPF Desktop App
Role 1 — Staff     → Flutter Mobile (Staff screens)
Role 2 — Manager   → Flutter Mobile (Manager screens)
Role 3 — Customer  → Flutter Mobile (Customer screens)
```

---

## 🔑 Cấu hình môi trường

### Supabase (Mobile App) — `lib/main.dart`
```dart
const String supabaseUrl = 'https://<project-ref>.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### SQL Server (Desktop App) — `appsettings.json`
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=<SERVER>;Initial Catalog=DoAnAI;Integrated Security=True;Encrypt=False"
  },
  "AppSettings": {
    "ApiBaseUrl": "http://localhost:5050",
    "ApiTimeoutSeconds": 5
  }
}
```

---

## 📄 License

Dự án được phát triển cho mục đích học thuật (đồ án hướng nghiệp).  
© 2024 – PhuongVinh1703. All rights reserved.

---

## 👨‍💻 Tác giả

**Phuong Vinh**  
[![GitHub](https://img.shields.io/badge/GitHub-PhuongVinh1703-181717?style=flat-square&logo=github)](https://github.com/PhuongVinh1703)

---

<div align="center">
<i>Reserve &amp; Relish — Smart Restaurant, Smarter Management 🍽️✨</i>
</div>
