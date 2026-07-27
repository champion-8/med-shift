namespace MedShift.Infrastructure.Payments;

public interface IPaymentGateway
{
    string ProviderName { get; }

    /// <summary>True when charge completes synchronously (Simulated).</summary>
    bool IsSynchronous { get; }

    /// <summary>Immediate charge (Simulated). Not used for QR providers.</summary>
    Task<PaymentChargeResult> ChargeAsync(
        Guid organizationId,
        decimal amount,
        string description,
        CancellationToken ct = default);

    /// <summary>Create PromptPay QR session. Returns PNG bytes + merchant reference.</summary>
    Task<PaymentQrSession> CreateQrChargeAsync(
        Guid organizationId,
        Guid jobId,
        decimal amount,
        string description,
        string merchantReference,
        CancellationToken ct = default);

    Task RefundAsync(
        string gatewayReference,
        string? merchantReference,
        string? gbpReferenceNo,
        decimal amount,
        string reason,
        CancellationToken ct = default);

    /// <summary>Query remote status. Returns Paid when settled.</summary>
    Task<PaymentStatusQueryResult> QueryStatusAsync(
        string merchantReference,
        CancellationToken ct = default);
}

public record PaymentChargeResult(bool Success, string Reference, string Provider, string? Message);

public record PaymentQrSession(
    bool Success,
    string MerchantReference,
    string Provider,
    byte[]? QrPngBytes,
    string? Message);

public record PaymentStatusQueryResult(
    bool Paid,
    string? GbpReferenceNo,
    decimal? Amount,
    string? RawStatus,
    string? Message);
