namespace MedShift.Domain.Entities;

/// <summary>Staff rates the clinic after completing a job (one review per job).</summary>
public class JobClinicReview : BaseEntity
{
    public Guid JobId { get; set; }
    public Job Job { get; set; } = null!;

    public Guid StaffProfileId { get; set; }
    public StaffProfile StaffProfile { get; set; } = null!;

    public Guid OrganizationId { get; set; }
    public Guid RatedByUserId { get; set; }

    /// <summary>1–5 stars.</summary>
    public int Rating { get; set; }
    public string? Comment { get; set; }
}
