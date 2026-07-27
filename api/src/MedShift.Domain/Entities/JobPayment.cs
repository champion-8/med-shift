using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

/// <summary>
/// Clinic payment at job post time via payment gateway.
/// StaffAmount is escrowed for the worker; PlatformFee is system revenue.
/// </summary>
public class JobPayment : BaseEntity
{
    public Guid JobId { get; set; }
    public Job Job { get; set; } = null!;

    public Guid OrganizationId { get; set; }

    /// <summary>Amount reserved for staff (= Job.TotalPay).</summary>
    public decimal StaffAmount { get; set; }

    /// <summary>Platform fee charged on top of staff amount.</summary>
    public decimal PlatformFee { get; set; }

    /// <summary>StaffAmount + PlatformFee charged to clinic.</summary>
    public decimal TotalCharged { get; set; }

    public decimal FeePercent { get; set; }

    public string GatewayReference { get; set; } = string.Empty;
    public string GatewayProvider { get; set; } = "Simulated";
    public JobPaymentStatus Status { get; set; } = JobPaymentStatus.Pending;

    /// <summary>Merchant referenceNo sent to GB Prime Pay (max 15 chars).</summary>
    public string? MerchantReference { get; set; }

    /// <summary>GB Prime Pay transaction reference after payment.</summary>
    public string? GbpReferenceNo { get; set; }

    public DateTime? ReleasedAt { get; set; }
    public DateTime? RefundedAt { get; set; }
}
