using MedShift.Domain.Enums;

namespace MedShift.Domain.Entities;

public class User : BaseEntity
{
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public UserRole Role { get; set; }
    public bool IsActive { get; set; } = true;
    public string PreferredLocale { get; set; } = "th";

    public StaffProfile? StaffProfile { get; set; }
    public ICollection<OrganizationMember> OrganizationMemberships { get; set; } = new List<OrganizationMember>();
    public ICollection<DeviceToken> DeviceTokens { get; set; } = new List<DeviceToken>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
}
