using Microsoft.Extensions.Logging;

namespace MedShift.Infrastructure.Payments;

public class SimulatedPaymentGateway(ILogger<SimulatedPaymentGateway> logger) : IPaymentGateway
{
    public string ProviderName => "Simulated";
    public bool IsSynchronous => true;

    public Task<PaymentChargeResult> ChargeAsync(
        Guid organizationId,
        decimal amount,
        string description,
        CancellationToken ct = default)
    {
        if (amount <= 0)
            return Task.FromResult(new PaymentChargeResult(false, "", ProviderName, "จำนวนเงินไม่ถูกต้อง"));

        var reference = $"SIM-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..32];
        logger.LogInformation(
            "Simulated gateway CHARGE org={OrgId} amount={Amount} ref={Ref} — {Desc}",
            organizationId, amount, reference, description);
        return Task.FromResult(new PaymentChargeResult(true, reference, ProviderName, null));
    }

    public Task<PaymentQrSession> CreateQrChargeAsync(
        Guid organizationId,
        Guid jobId,
        decimal amount,
        string description,
        string merchantReference,
        CancellationToken ct = default)
    {
        // Simulated path uses ChargeAsync instead; QR not required.
        return Task.FromResult(new PaymentQrSession(
            false, merchantReference, ProviderName, null, "Simulated gateway does not create QR"));
    }

    public Task RefundAsync(
        string gatewayReference,
        string? merchantReference,
        string? gbpReferenceNo,
        decimal amount,
        string reason,
        CancellationToken ct = default)
    {
        logger.LogInformation(
            "Simulated gateway REFUND ref={Ref} gbp={Gbp} amount={Amount} — {Reason}",
            gatewayReference, gbpReferenceNo, amount, reason);
        return Task.CompletedTask;
    }

    public Task<PaymentStatusQueryResult> QueryStatusAsync(
        string merchantReference,
        CancellationToken ct = default)
        => Task.FromResult(new PaymentStatusQueryResult(true, merchantReference, null, "S", null));
}
