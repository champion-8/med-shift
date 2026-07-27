namespace MedShift.Infrastructure.Email;

public class EmailSettings
{
    public const string SectionName = "EmailSettings";

    /// <summary>When false, skips SMTP and Auth falls back to returning the reset code in API responses.</summary>
    public bool Enabled { get; set; } = true;

    public string SmtpServer { get; set; } = "";
    public int Port { get; set; } = 587;
    public bool UseSsl { get; set; } = true;
    public string SenderName { get; set; } = "MedShift";
    public string SenderEmail { get; set; } = "";
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";

    public bool IsConfigured =>
        Enabled
        && !string.IsNullOrWhiteSpace(SmtpServer)
        && !string.IsNullOrWhiteSpace(SenderEmail)
        && !string.IsNullOrWhiteSpace(Username)
        && !string.IsNullOrWhiteSpace(Password);
}
