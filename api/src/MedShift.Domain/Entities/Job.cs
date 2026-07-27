using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class Job : BaseEntity
{
    public Guid OrganizationId { get; set; }
    public Organization Organization { get; set; } = null!;

    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string LocationName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public decimal HourlyRate { get; set; }
    public decimal TotalPay { get; set; }
    public JobStatus Status { get; set; } = JobStatus.Open;
    public string RequiredSkillsJson { get; set; } = "[]";
    public string? RequiredCertification { get; set; }
    public double MinReliabilityScore { get; set; } = 0;
    public Guid? HiredStaffProfileId { get; set; }
    public StaffProfile? HiredStaffProfile { get; set; }

    public ICollection<JobApplication> Applications { get; set; } = new List<JobApplication>();
    public ICollection<CheckInRequirement> CheckInRequirements { get; set; } = new List<CheckInRequirement>();
    public CheckInSession? CheckInSession { get; set; }
    public JobReview? Review { get; set; }
    public JobClinicReview? ClinicReview { get; set; }
    public JobPayment? Payment { get; set; }
    public ICollection<JobIssue> Issues { get; set; } = new List<JobIssue>();
}
