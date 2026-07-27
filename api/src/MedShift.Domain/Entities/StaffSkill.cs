namespace MedShift.Domain.Entities;

public class StaffSkill : BaseEntity
{
    public Guid StaffProfileId { get; set; }
    public StaffProfile StaffProfile { get; set; } = null!;

    public string Name { get; set; } = string.Empty;
    public decimal MinRate { get; set; }
    public decimal MaxRate { get; set; }
    public int YearsExperience { get; set; }
    public bool IsVerified { get; set; }
    public string? Certification { get; set; }
}
