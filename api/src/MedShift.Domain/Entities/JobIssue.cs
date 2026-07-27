using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class JobIssue : BaseEntity
{
    public Guid JobId { get; set; }
    public Job Job { get; set; } = null!;

    public Guid StaffProfileId { get; set; }
    public StaffProfile StaffProfile { get; set; } = null!;

    public Guid OrganizationId { get; set; }
    public JobIssueCategory Category { get; set; }
    public string Description { get; set; } = string.Empty;
    public JobIssueStatus Status { get; set; } = JobIssueStatus.Open;
    public DateTime? ResolvedAt { get; set; }
    public Guid? ResolvedByUserId { get; set; }
}
