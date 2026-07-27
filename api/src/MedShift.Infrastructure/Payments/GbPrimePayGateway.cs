using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace MedShift.Infrastructure.Payments;

public class GbPrimePayGateway(
    IHttpClientFactory httpClientFactory,
    IOptions<PaymentGatewayOptions> options,
    ILogger<GbPrimePayGateway> logger) : IPaymentGateway
{

    public string ProviderName => "GbPrimePay";
    public bool IsSynchronous => false;

    private GbPrimePayOptions Cfg => options.Value.GbPrimePay;

    public Task<PaymentChargeResult> ChargeAsync(
        Guid organizationId,
        decimal amount,
        string description,
        CancellationToken ct = default)
        => Task.FromResult(new PaymentChargeResult(
            false, "", ProviderName, "GB Prime Pay ใช้ QR — เรียก CreateQrChargeAsync"));

    public async Task<PaymentQrSession> CreateQrChargeAsync(
        Guid organizationId,
        Guid jobId,
        decimal amount,
        string description,
        string merchantReference,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(Cfg.Token))
            return new PaymentQrSession(false, merchantReference, ProviderName, null, "ยังไม่ได้ตั้ง PaymentGateway:GbPrimePay:Token");

        if (amount < 1m)
            return new PaymentQrSession(false, merchantReference, ProviderName, null, "ยอดขั้นต่ำ 1.00 บาท");

        if (merchantReference.Length > 15)
            return new PaymentQrSession(false, merchantReference, ProviderName, null, "referenceNo ยาวเกิน 15 ตัวอักษร");

        var webhookBase = (Cfg.WebhookPublicBaseUrl ?? "").TrimEnd('/');
        if (string.IsNullOrWhiteSpace(webhookBase))
            return new PaymentQrSession(false, merchantReference, ProviderName, null,
                "ต้องตั้ง PaymentGateway:GbPrimePay:WebhookPublicBaseUrl สำหรับ backgroundUrl");

        var backgroundUrl = $"{webhookBase}/api/payments/gbprimepay/webhook";
        var client = httpClientFactory.CreateClient("gbprimepay");
        var form = new Dictionary<string, string>
        {
            ["token"] = Cfg.Token,
            ["amount"] = amount.ToString("0.00"),
            ["referenceNo"] = merchantReference,
            ["backgroundUrl"] = backgroundUrl,
            ["detail"] = Truncate(description, 250),
            ["merchantDefined1"] = jobId.ToString("N")
        };

        using var content = new FormUrlEncodedContent(form);
        using var res = await client.PostAsync($"{Cfg.BaseUrl.TrimEnd('/')}/v3/qrcode", content, ct);
        var bytes = await res.Content.ReadAsByteArrayAsync(ct);

        if (!res.IsSuccessStatusCode)
        {
            var text = Encoding.UTF8.GetString(bytes);
            logger.LogWarning("GB QR create failed HTTP {Status}: {Body}", (int)res.StatusCode, text);
            return new PaymentQrSession(false, merchantReference, ProviderName, null,
                $"สร้าง QR ไม่สำเร็จ ({(int)res.StatusCode})");
        }

        var contentType = res.Content.Headers.ContentType?.MediaType ?? "";
        if (!contentType.Contains("image", StringComparison.OrdinalIgnoreCase) && bytes.Length > 0 && bytes[0] == (byte)'{')
        {
            var text = Encoding.UTF8.GetString(bytes);
            logger.LogWarning("GB QR create returned JSON instead of image: {Body}", text);
            return new PaymentQrSession(false, merchantReference, ProviderName, null, text);
        }

        logger.LogInformation(
            "GB QR created org={Org} job={Job} ref={Ref} amount={Amount} bytes={Len}",
            organizationId, jobId, merchantReference, amount, bytes.Length);

        return new PaymentQrSession(true, merchantReference, ProviderName, bytes, null);
    }

    public async Task RefundAsync(
        string gatewayReference,
        string? merchantReference,
        string? gbpReferenceNo,
        decimal amount,
        string reason,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(Cfg.SecretKey))
        {
            logger.LogWarning("GB refund skipped — SecretKey empty. ref={Ref} amount={Amount}", gatewayReference, amount);
            return;
        }

        if (string.IsNullOrWhiteSpace(merchantReference) || string.IsNullOrWhiteSpace(gbpReferenceNo))
        {
            logger.LogWarning("GB refund skipped — missing merchant/gbp reference");
            return;
        }

        var client = httpClientFactory.CreateClient("gbprimepay");
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{Cfg.BaseUrl.TrimEnd('/')}/unified/transaction");
        req.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{Cfg.SecretKey}:")));

        var payload = new Dictionary<string, string>
        {
            ["apiType"] = "PR",
            ["amount"] = amount.ToString("0.00"),
            ["referenceNo"] = merchantReference,
            ["gbpReferenceNo"] = gbpReferenceNo
        };
        req.Content = new FormUrlEncodedContent(payload);

        using var res = await client.SendAsync(req, ct);
        var body = await res.Content.ReadAsStringAsync(ct);
        if (!res.IsSuccessStatusCode)
            logger.LogWarning("GB refund HTTP {Status}: {Body} reason={Reason}", (int)res.StatusCode, body, reason);
        else
            logger.LogInformation("GB refund ok ref={Ref} gbp={Gbp} amount={Amount} — {Reason}",
                merchantReference, gbpReferenceNo, amount, reason);
    }

    public async Task<PaymentStatusQueryResult> QueryStatusAsync(
        string merchantReference,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(Cfg.SecretKey))
            return new PaymentStatusQueryResult(false, null, null, null, "SecretKey empty");

        var client = httpClientFactory.CreateClient("gbprimepay");
        using var req = new HttpRequestMessage(HttpMethod.Post, $"{Cfg.BaseUrl.TrimEnd('/')}/v1/check_status_txn");
        req.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{Cfg.SecretKey}:")));
        req.Content = new StringContent(
            JsonSerializer.Serialize(new { referenceNo = merchantReference }),
            Encoding.UTF8,
            "application/json");

        using var res = await client.SendAsync(req, ct);
        var body = await res.Content.ReadAsStringAsync(ct);
        if (!res.IsSuccessStatusCode)
            return new PaymentStatusQueryResult(false, null, null, null, body);

        try
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (!root.TryGetProperty("txn", out var txn))
                return new PaymentStatusQueryResult(false, null, null, null, body);

            var status = txn.TryGetProperty("status", out var st) ? st.GetString() : null;
            var gbp = txn.TryGetProperty("gbpReferenceNo", out var g) ? g.GetString() : null;
            decimal? amount = null;
            if (txn.TryGetProperty("amount", out var am))
            {
                if (am.ValueKind == JsonValueKind.Number) amount = am.GetDecimal();
                else if (decimal.TryParse(am.GetString(), out var parsed)) amount = parsed;
            }

            var paid = string.Equals(status, "S", StringComparison.OrdinalIgnoreCase);
            return new PaymentStatusQueryResult(paid, gbp, amount, status, null);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "GB status parse failed: {Body}", body);
            return new PaymentStatusQueryResult(false, null, null, null, body);
        }
    }

    private static string Truncate(string value, int max)
        => string.IsNullOrEmpty(value) ? "" : value.Length <= max ? value : value[..max];
}
