using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;

namespace DoAnQuanLyQuanAnAI
{
    public partial class App : Application
    {
        private static Process? _apiProcess;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            Task.Run(() => StartPythonApi());
        }

        protected override void OnExit(ExitEventArgs e)
        {
            try
            {
                if (_apiProcess != null && !_apiProcess.HasExited)
                {
                    _apiProcess.Kill();
                    _apiProcess.Dispose();
                }
            }
            catch { }
            base.OnExit(e);
        }

        private static void StartPythonApi()
        {
            try
            {
                // ── Tìm thư mục AI_Module ──────────────────────────────────
                // BaseDirectory = ...bin\Debug\net9.0-windows\
                // Cần lên 5 cấp để ra thư mục "Đồ Án AI\" rồi vào AI_Module
                string[] possiblePaths =
                {
                    // 5 cấp: net9.0-windows → Debug → bin → DoAnQuanLyQuanAnAI(inner) → DoAnQuanLyQuanAnAI(outer) → "Đồ Án AI"
                    Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                 @"..\..\..\..\..\AI_Module"),
                    // Fallback hardcode đường dẫn thực tế
                    @"D:\năm 4\Đồ Án AI\AI_Module",
                    @"D:\DoAnAI\AI_Module",
                    @"C:\DoAnAI\AI_Module",
                };

                string? apiDir = null;
                string? apiFile = null;

                foreach (var path in possiblePaths)
                {
                    try
                    {
                        var fullPath = Path.GetFullPath(path);
                        var file = Path.Combine(fullPath, "predict_api.py");
                        if (File.Exists(file))
                        {
                            apiDir = fullPath;
                            apiFile = file;
                            Debug.WriteLine($"[AI] Tìm thấy AI_Module tại: {fullPath}");
                            break;
                        }
                    }
                    catch { continue; }
                }

                if (apiDir == null || apiFile == null)
                {
                    Debug.WriteLine("[AI] ❌ Không tìm thấy predict_api.py trong bất kỳ đường dẫn nào");
                    return;
                }

                if (!File.Exists(Path.Combine(apiDir, "binary_model.pkl")))
                {
                    Debug.WriteLine("[AI] ❌ Chưa có binary_model.pkl — cần chạy train_model.py trước");
                    return;
                }

                // Kiểm tra API đã chạy chưa (tránh chạy 2 lần)
                using var testHttp = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
                try
                {
                    var testResp = testHttp.GetAsync("http://localhost:5050/health")
                                           .GetAwaiter().GetResult();
                    if (testResp.IsSuccessStatusCode)
                    {
                        Debug.WriteLine("[AI] API đã đang chạy, bỏ qua khởi động mới");
                        return;
                    }
                }
                catch { /* API chưa chạy → tiếp tục khởi động */ }

                // Khởi động Python API
                var startInfo = new ProcessStartInfo
                {
                    FileName = "python",
                    Arguments = $"\"{apiFile}\"",
                    WorkingDirectory = apiDir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };

                _apiProcess = Process.Start(startInfo);
                Debug.WriteLine($"[AI] ✅ Python API khởi động (PID: {_apiProcess?.Id})");

                // Chờ tối đa 20 giây cho đến khi API sẵn sàng
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
                for (int i = 1; i <= 20; i++)
                {
                    Thread.Sleep(1000);
                    try
                    {
                        var resp = http.GetAsync("http://localhost:5050/health")
                                       .GetAwaiter().GetResult();
                        if (resp.IsSuccessStatusCode)
                        {
                            Debug.WriteLine($"[AI] ✅ API sẵn sàng sau {i} giây");
                            return;
                        }
                    }
                    catch { }
                    Debug.WriteLine($"[AI] Chờ API... ({i}/20s)");
                }

                Debug.WriteLine("[AI] ⚠️ API không phản hồi sau 20 giây");
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[AI] Lỗi khởi động: {ex.Message}");
            }
        }
    }
}