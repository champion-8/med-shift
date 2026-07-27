using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class Organization : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? LegalName { get; set; }
    public string? TaxId { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string Address { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public OrganizationStatus Status { get; set; } = OrganizationStatus.Pending;
    public string? RejectionReason { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public Guid? ApprovedByAdminId { get; set; }
    public string? DocumentUrl { get; set; }

    /// <summary>Average rating from staff JobClinicReviews (1–5).</summary>
    public double Rating { get; set; }

    public ICollection<OrganizationMember> Members { get; set; } = new List<OrganizationMember>();
    public ICollection<Job> Jobs { get; set; } = new List<Job>();
    public ICollection<CheckInRequirement> CheckInRequirements { get; set; } = new List<CheckInRequirement>();
}
