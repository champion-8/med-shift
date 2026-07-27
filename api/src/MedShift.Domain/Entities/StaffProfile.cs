using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class StaffProfile : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? ProfileImageUrl { get; set; }
    public StaffProfession Profession { get; set; } = StaffProfession.Nurse;
    public string? Specialty { get; set; }
    public string? LicenseNumber { get; set; }
    public DateTime? LicenseExpiryDate { get; set; }
    public string? NationalId { get; set; }
    /// <summary>Laser code from the back of Thai national ID card.</summary>
    public string? LaserCode { get; set; }
    public int YearsExperience { get; set; }
    public double Rating { get; set; }
    public int TotalJobsCompleted { get; set; }
    public double ReliabilityScore { get; set; } = 100;
    public decimal TotalEarnings { get; set; }
    public bool IsAvailable { get; set; } = true;
    public double? CurrentLocationLat { get; set; }
    public double? CurrentLocationLng { get; set; }

    public string? BankName { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankAccountName { get; set; }
    public bool BankAccountVerified { get; set; }
    /// <summary>PromptPay ID (phone or national ID). Bookbank OR PromptPay required for payout.</summary>
    public string? PromptPayId { get; set; }

    public StaffStatus Status { get; set; } = StaffStatus.Pending;
    public string? RejectionReason { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public Guid? ApprovedByAdminId { get; set; }

    public ICollection<StaffSkill> Skills { get; set; } = new List<StaffSkill>();
    public ICollection<StaffDocument> Documents { get; set; } = new List<StaffDocument>();
    public Wallet? Wallet { get; set; }
    public ICollection<JobApplication> Applications { get; set; } = new List<JobApplication>();
}
