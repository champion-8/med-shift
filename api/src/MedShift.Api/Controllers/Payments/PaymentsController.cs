using System.Globalization;
using System.Text.Json;
using MedShift.Infrastructure.Persistence;
using MedShift.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MedShift.Api.Controllers.Payments;

[ApiController]
[Route("api/payments")]
public class PaymentsController(
    JobEscrowService escrow,
    MedShiftDbContext db,
    ILogger<PaymentsController> logger) : ControllerBase
{
    /// <summary>GB Prime Pay backgroundUrl callback (anonymous).</summary>
    [AllowAnonymous]
    [HttpPost("gbprimepay/webhook")]
    public async Task<IActionResult> GbPrimePayWebhook(CancellationToken ct)
    {
        string body;
        using (var reader = new StreamReader(Request.Body))
            body = await reader.ReadToEndAsync(ct);

        logger.LogInformation("GB webhook payload: {Body}", body);

        try
        {
            string? resultCode = null;
            string? referenceNo = null;
            string? gbpReferenceNo = null;
            decimal? amount = null;

            if (!string.IsNullOrWhiteSpace(body) && body.TrimStart().StartsWith('{'))
            {
                using var doc = JsonDocument.Parse(body);
                var root = doc.RootElement;
                resultCode = GetString(root, "resultCode");
                referenceNo = GetString(root, "referenceNo");
                gbpReferenceNo = GetString(root, "gbpReferenceNo");
                amount = GetDecimal(root, "amount");
            }

            if (string.IsNullOrWhiteSpace(referenceNo) && Request.HasFormContentType)
            {
                resultCode = Request.Form["resultCode"].ToString();
                referenceNo = Request.Form["referenceNo"].ToString();
                gbpReferenceNo = Request.Form["gbpReferenceNo"].ToString();
                if (decimal.TryParse(Request.Form["amount"], NumberStyles.Any, CultureInfo.InvariantCulture, out var formAmount))
                    amount = formAmount;
            }

            if (string.IsNullOrWhiteSpace(referenceNo))
            {
                logger.LogWarning("GB webhook missing referenceNo");
                return Ok(new { ok = false, message = "missing referenceNo" });
            }

            if (!string.IsNullOrEmpty(resultCode) && resultCode != "00")
            {
                logger.LogWarning("GB webhook non-success resultCode={Code} ref={Ref}", resultCode, referenceNo);
                return Ok(new { ok = false, resultCode });
            }

            var confirmed = await escrow.ConfirmPaymentAsync(referenceNo, gbpReferenceNo, amount, ct);
            await db.SaveChangesAsync(ct);
            return Ok(new { ok = confirmed });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "GB webhook processing failed");
            return Ok(new { ok = false, message = ex.Message });
        }
    }

    private static string? GetString(JsonElement root, string name)
        => root.TryGetProperty(name, out var el) ? el.ToString() : null;

    private static decimal? GetDecimal(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var el)) return null;
        if (el.ValueKind == JsonValueKind.Number) return el.GetDecimal();
        if (decimal.TryParse(el.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var v))
            return v;
        return null;
    }
}
