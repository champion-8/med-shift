namespace MedShift.Domain.Entities;

public class CheckInSession : BaseEntity
{
    public Guid JobId { get; set; }
    public Job Job { get; set; } = null!;

    public Guid StaffProfileId { get; set; }
    public string CompletedStepsJson { get; set; } = "[]";
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }

    /// <summary>Staff GPS at check-in time.</summary>
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? AccuracyMeters { get; set; }
    /// <summary>Straight-line distance to job location in meters.</summary>
    public double? DistanceMeters { get; set; }
}
