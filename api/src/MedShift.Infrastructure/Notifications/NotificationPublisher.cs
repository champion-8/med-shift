using MedShift.Application.Interfaces;
using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using MedShift.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace MedShift.Infrastructure.Notifications;

public class NotificationPublisher(
    MedShiftDbContext db,
    IFcmSender fcmSender,
    ILogger<NotificationPublisher> logger) : INotificationPublisher
{
    public void Queue(Guid userId, string title, string message, NotificationType type, Guid? jobId = null)
    {
        db.Notifications.Add(new Notification
        {
            UserId = userId,
            Title = title,
            Message = message,
            Type = type,
            JobId = jobId
        });
    }

    public async Task PushAsync(Guid userId, string title, string message, string type, Guid? jobId = null, CancellationToken ct = default)
    {
        try
        {
            var tokens = await db.DeviceTokens.AsNoTracking()
                .Where(d => d.UserId == userId)
                .Select(d => d.FirebaseDeviceToken)
                .Where(t => t != null && t != "")
                .ToListAsync(ct);

            if (tokens.Count == 0)
            {
                logger.LogDebug("No device tokens for user {UserId}; in-app only: {Title}", userId, title);
                return;
            }

            var data = new Dictionary<string, string>
            {
                ["type"] = type,
                ["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
            };
            if (jobId.HasValue)
                data["jobId"] = jobId.Value.ToString();

            var result = await fcmSender.SendAsync(tokens, title, message, data, ct);

            if (result.InvalidTokens.Count > 0)
            {
                var removed = await db.DeviceTokens
                    .Where(d => d.UserId == userId && result.InvalidTokens.Contains(d.FirebaseDeviceToken))
                    .ExecuteDeleteAsync(ct);
                logger.LogInformation(
                    "Pruned {Count} invalid FCM token(s) for user {UserId}",
                    removed,
                    userId);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Push failed for user {UserId}: {Title}", userId, title);
        }
    }

    public async Task NotifyAsync(Guid userId, string title, string message, NotificationType type, Guid? jobId = null, CancellationToken ct = default)
    {
        Queue(userId, title, message, type, jobId);
        await PushAsync(userId, title, message, type.ToString(), jobId, ct);
    }
}
