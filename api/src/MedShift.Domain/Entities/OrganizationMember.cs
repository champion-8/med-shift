using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class OrganizationMember : BaseEntity
{
    public Guid OrganizationId { get; set; }
    public Organization Organization { get; set; } = null!;

    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public OrganizationMemberRole Role { get; set; } = OrganizationMemberRole.Member;
    public bool IsActive { get; set; } = true;
}
