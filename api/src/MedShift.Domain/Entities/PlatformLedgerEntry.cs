namespace MedShift.Domain.Entities;

/// <summary>Platform revenue ledger (fees collected from clinic payments).</summary>
public class PlatformLedgerEntry : BaseEntity
{
    public Guid? JobId { get; set; }
    public Guid? OrganizationId { get; set; }
    public decimal Amount { get; set; }
    public string Type { get; set; } = "JobPlatformFee";
    public string Description { get; set; } = string.Empty;
    public string? GatewayReference { get; set; }
}
