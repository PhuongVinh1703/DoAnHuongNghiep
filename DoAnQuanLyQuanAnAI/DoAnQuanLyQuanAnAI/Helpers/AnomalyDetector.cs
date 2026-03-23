using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using DoAnQuanLyQuanAnAI.Models;

namespace DoAnQuanLyQuanAnAI.Helpers
{
    public class AnomalyResult
    {
        public bool IsAnomaly { get; set; }
        public double AnomalyScore { get; set; }
        public string RiskLevel { get; set; } = "LOW";
        public string AnomalyType { get; set; } = "Normal";

        public AlertType ToAlertType() => AnomalyType switch
        {
            "CancelAfterPayment" => AlertType.CancelAfterPayment,
            "ExcessiveDiscount" => AlertType.ExcessiveDiscount,
            "SpeedAnomaly" => AlertType.SpeedAnomaly,
            "UnusualHours" => AlertType.UnusualHours,
            "FrequentCancellation" => AlertType.FrequentCancellation,
            _ => AlertType.FrequentCancellation
        };

        public string AnomalyTypeVN => AnomalyType switch
        {
            "CancelAfterPayment" => "Hủy sau thanh toán",
            "ExcessiveDiscount" => "Lạm dụng giảm giá",
            "SpeedAnomaly" => "Thanh toán quá nhanh",
            "UnusualHours" => "Giao dịch ngoài giờ",
            "FrequentCancellation" => "Hủy bill liên tục",
            _ => "Bất thường khác"
        };
    }

    public static class AnomalyDetector
    {
        private const string API_URL = "http://localhost:5050";

        /// <summary>
        /// Tạo HttpClient mới mỗi lần gọi — tránh lỗi connection reuse
        /// khi API Python khởi động sau app C#
        /// </summary>
        private static HttpClient CreateClient() => new HttpClient
        {
            BaseAddress = new Uri(API_URL),
            Timeout = TimeSpan.FromSeconds(10)
        };

        public static async Task<AnomalyResult> PredictAsync(
            int staffId,
            double sessionDuration,
            int numItemsOrdered,
            double cancelRate,
            int transactionHour,
            double checkoutTimeSec,
            int voidCount,
            double discountPercent,
            double addRemoveRatio)
        {
            try
            {
                var payload = new
                {
                    staff_id = staffId,
                    session_duration = sessionDuration,
                    num_items_ordered = numItemsOrdered,
                    cancel_rate = cancelRate,
                    transaction_hour = transactionHour,
                    checkout_time_sec = checkoutTimeSec,
                    void_count = voidCount,
                    discount_percent = discountPercent,
                    add_remove_ratio = addRemoveRatio
                };

                string json = JsonSerializer.Serialize(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                using var http = CreateClient();
                var resp = await http.PostAsync("/predict", content);

                if (!resp.IsSuccessStatusCode)
                    return SafeDefault();

                string body = await resp.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<JsonElement>(body);

                return new AnomalyResult
                {
                    IsAnomaly = result.GetProperty("is_anomaly").GetBoolean(),
                    AnomalyScore = result.GetProperty("anomaly_score").GetDouble(),
                    RiskLevel = result.GetProperty("risk_level").GetString() ?? "LOW",
                    AnomalyType = result.GetProperty("anomaly_type").GetString() ?? "Normal"
                };
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[AI] PredictAsync lỗi: {ex.Message}");
                return SafeDefault();
            }
        }

        public static async Task<bool> IsApiAliveAsync()
        {
            try
            {
                using var http = CreateClient();
                http.Timeout = TimeSpan.FromSeconds(3);
                var resp = await http.GetAsync("/health");
                return resp.IsSuccessStatusCode;
            }
            catch { return false; }
        }

        public static async Task<string> RequestRetrainAsync()
        {
            try
            {
                using var http = CreateClient();
                var resp = await http.PostAsync("/retrain",
                    new StringContent("{}", Encoding.UTF8, "application/json"));
                return await resp.Content.ReadAsStringAsync();
            }
            catch (Exception ex) { return $"Lỗi: {ex.Message}"; }
        }

        public static async Task SendFeedbackAsync(
            object features, int actualLabel, string actualType)
        {
            try
            {
                var payload = new
                {
                    features = features,
                    actual_label = actualLabel,
                    actual_type = actualType
                };
                string json = JsonSerializer.Serialize(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                using var http = CreateClient();
                await http.PostAsync("/feedback", content);
            }
            catch { }
        }

        private static AnomalyResult SafeDefault() =>
            new AnomalyResult
            {
                IsAnomaly = false,
                AnomalyScore = 0,
                RiskLevel = "LOW",
                AnomalyType = "Normal"
            };
    }
}