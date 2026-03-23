using System;
using System.IO;
using System.Text.Json;

namespace DoAnQuanLyQuanAnAI.Helpers
{
    /// <summary>
    /// Đọc cấu hình từ appsettings.json
    /// Tránh hardcode connection string và các thông số nhạy cảm trong source code
    /// </summary>
    public static class ConfigHelper
    {
        private static JsonDocument? _config;

        private static JsonDocument Config
        {
            get
            {
                if (_config != null) return _config;

                // Tìm file appsettings.json từ thư mục chạy app
                string[] searchPaths =
                {
                    "appsettings.json",
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "appsettings.json"),
                };

                foreach (var path in searchPaths)
                {
                    if (File.Exists(path))
                    {
                        string json = File.ReadAllText(path);
                        _config = JsonDocument.Parse(json);
                        return _config;
                    }
                }

                throw new FileNotFoundException(
                    "Không tìm thấy file appsettings.json!\n" +
                    "Vui lòng tạo file appsettings.json trong thư mục project.");
            }
        }

        /// <summary>Connection string từ appsettings.json</summary>
        public static string ConnectionString =>
            Config.RootElement
                  .GetProperty("ConnectionStrings")
                  .GetProperty("DefaultConnection")
                  .GetString()
            ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection không tìm thấy!");

        /// <summary>URL của Python AI API</summary>
        public static string ApiBaseUrl =>
            Config.RootElement
                  .GetProperty("AppSettings")
                  .GetProperty("ApiBaseUrl")
                  .GetString()
            ?? "http://localhost:5050";

        /// <summary>Timeout (giây) khi gọi AI API</summary>
        public static int ApiTimeoutSeconds
        {
            get
            {
                try
                {
                    return Config.RootElement
                                 .GetProperty("AppSettings")
                                 .GetProperty("ApiTimeoutSeconds")
                                 .GetInt32();
                }
                catch { return 5; }
            }
        }
    }
}