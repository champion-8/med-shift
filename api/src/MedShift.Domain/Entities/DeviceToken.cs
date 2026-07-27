namespace MedShift.Domain.Entities;

public class DeviceToken : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    public string FirebaseDeviceToken { get; set; } = string.Empty;
    public string? Platform { get; set; }
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
