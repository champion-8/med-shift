namespace MedShift.Infrastructure.Auth;

public class JwtSettings
{
    public const string SectionName = "Jwt";
    public string Issuer { get; set; } = "MedShift";
    public string Audience { get; set; } = "MedShiftClients";
    public string Key { get; set; } = string.Empty;
    public int ExpiryMinutes { get; set; } = 60 * 24;
}
