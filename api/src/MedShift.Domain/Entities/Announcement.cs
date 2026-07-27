namespace MedShift.Domain.Entities;

public class Announcement : BaseEntity
{
    public string TitleTh { get; set; } = string.Empty;
    public string TitleEn { get; set; } = string.Empty;
    public string MessageTh { get; set; } = string.Empty;
    public string MessageEn { get; set; } = string.Empty;
    public string Type { get; set; } = "info";
    public bool IsActive { get; set; } = true;
    public DateTime? ExpiresAt { get; set; }
}
