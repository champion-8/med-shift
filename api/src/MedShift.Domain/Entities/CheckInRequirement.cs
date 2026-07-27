namespace MedShift.Domain.Entities;

public class CheckInRequirement : BaseEntity
{
    public Guid? OrganizationId { get; set; }
    public Organization? Organization { get; set; }

    public Guid? JobId { get; set; }
    public Job? Job { get; set; }

    public int StepNumber { get; set; }
    public string TitleTh { get; set; } = string.Empty;
    public string TitleEn { get; set; } = string.Empty;
    public string ContentTh { get; set; } = string.Empty;
    public string ContentEn { get; set; } = string.Empty;
    public string Type { get; set; } = "general";
    public bool RequiresAcknowledgment { get; set; } = true;
    public int EstimatedReadTimeSeconds { get; set; } = 30;
}
