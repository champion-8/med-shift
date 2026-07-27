using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class JobApplication : BaseEntity
{
    public Guid JobId { get; set; }
    public Job Job { get; set; } = null!;

    public Guid StaffProfileId { get; set; }
    public StaffProfile StaffProfile { get; set; } = null!;

    public ApplicationStatus Status { get; set; } = ApplicationStatus.Pending;
    public int? WaitlistPosition { get; set; }
    public string? CancelReason { get; set; }
    public decimal? PenaltyAmount { get; set; }
}
