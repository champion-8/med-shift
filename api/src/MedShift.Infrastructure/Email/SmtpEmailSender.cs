using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace MedShift.Infrastructure.Email;

public class SmtpEmailSender(
    IOptions<EmailSettings> options,
    ILogger<SmtpEmailSender> logger) : IEmailSender
{
    public bool IsAvailable => options.Value.IsConfigured;

    public async Task SendAsync(
        string toEmail,
        string subject,
        string htmlBody,
        string? plainTextBody = null,
        CancellationToken ct = default)
    {
        var cfg = options.Value;
        if (!cfg.IsConfigured)
            throw new InvalidOperationException("EmailSettings is not configured");

        if (string.IsNullOrWhiteSpace(toEmail))
            throw new ArgumentException("Recipient email is required", nameof(toEmail));

        // Gmail app passwords are often pasted with spaces — strip them.
        var password = cfg.Password.Replace(" ", "", StringComparison.Ordinal);

        using var message = new MailMessage
        {
            From = new MailAddress(cfg.SenderEmail.Trim(), string.IsNullOrWhiteSpace(cfg.SenderName) ? "MedShift" : cfg.SenderName.Trim()),
            Subject = subject,
            IsBodyHtml = true,
            Body = htmlBody,
        };
        message.To.Add(toEmail.Trim());

        if (!string.IsNullOrWhiteSpace(plainTextBody))
            message.AlternateViews.Add(
                AlternateView.CreateAlternateViewFromString(plainTextBody, null, "text/plain"));

        using var client = new SmtpClient(cfg.SmtpServer.Trim(), cfg.Port)
        {
            EnableSsl = cfg.UseSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(cfg.Username.Trim(), password),
        };

        ct.ThrowIfCancellationRequested();
        await client.SendMailAsync(message, ct);
        logger.LogInformation("Email sent to {To} subject={Subject}", toEmail, subject);
    }
}
