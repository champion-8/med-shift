using MedShift.Domain.Enums;

namespace MedShift.Application.Interfaces;

public interface INotificationPublisher
{
    /// <summary>Queue in-app notification on the current DbContext (caller SaveChanges).</summary>
    void Queue(Guid userId, string title, string message, NotificationType type, Guid? jobId = null);

    /// <summary>Send FCM (or log if Firebase not configured). Never throws.</summary>
    Task PushAsync(Guid userId, string title, string message, string type, Guid? jobId = null, CancellationToken ct = default);

    /// <summary>Queue in-app notification and attempt push. Caller still SaveChanges.</summary>
    Task NotifyAsync(Guid userId, string title, string message, NotificationType type, Guid? jobId = null, CancellationToken ct = default);
}
