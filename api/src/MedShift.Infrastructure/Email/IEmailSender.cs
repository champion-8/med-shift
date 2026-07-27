namespace MedShift.Infrastructure.Email;

public interface IEmailSender
{
    bool IsAvailable { get; }

    Task SendAsync(
        string toEmail,
        string subject,
        string htmlBody,
        string? plainTextBody = null,
        CancellationToken ct = default);
}
