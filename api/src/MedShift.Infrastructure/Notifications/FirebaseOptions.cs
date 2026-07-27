namespace MedShift.Infrastructure.Notifications;

public class FirebaseOptions
{
    public const string SectionName = "Firebase";

    /// <summary>
    /// Master switch. When false, never call FCM even if credentials exist.
    /// </summary>
    public bool Enabled { get; set; }

    /// <summary>
    /// Path to Firebase service account JSON (Admin SDK).
    /// Absolute path, or relative to the API content root.
    /// </summary>
    public string? CredentialsPath { get; set; }

    public bool HasCredentialsPath => !string.IsNullOrWhiteSpace(CredentialsPath);

    public string DryRunReason
    {
        get
        {
            if (!Enabled) return "Firebase:Enabled=false";
            if (!HasCredentialsPath) return "Firebase:CredentialsPath empty";
            return "ok";
        }
    }
}
