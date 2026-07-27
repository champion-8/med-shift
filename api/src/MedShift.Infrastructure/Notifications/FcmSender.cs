using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace MedShift.Infrastructure.Notifications;

public interface IFcmSender
{
    Task<FcmSendResult> SendAsync(
        IReadOnlyList<string> deviceTokens,
        string title,
        string body,
        IReadOnlyDictionary<string, string>? data = null,
        CancellationToken ct = default);
}

public record FcmSendResult(int Attempted, int Sent, IReadOnlyList<string> InvalidTokens);

public class FcmSender(
    IOptions<FirebaseOptions> options,
    IHostEnvironment env,
    ILogger<FcmSender> logger) : IFcmSender
{
    private static readonly object InitLock = new();

    public async Task<FcmSendResult> SendAsync(
        IReadOnlyList<string> deviceTokens,
        string title,
        string body,
        IReadOnlyDictionary<string, string>? data = null,
        CancellationToken ct = default)
    {
        var tokens = deviceTokens.Where(t => !string.IsNullOrWhiteSpace(t)).Distinct().ToList();
        if (tokens.Count == 0)
            return new FcmSendResult(0, 0, []);

        var cfg = options.Value;
        if (!TryEnsureFirebaseApp(cfg, out var reason))
        {
            logger.LogInformation(
                "FCM dry-run ({Reason}). Would push to {Count} device(s): {Title} — {Body}",
                reason,
                tokens.Count,
                title,
                body);
            return new FcmSendResult(tokens.Count, 0, []);
        }

        var sent = 0;
        var invalid = new List<string>();
        var dataDict = data?.ToDictionary(kv => kv.Key, kv => kv.Value)
            ?? new Dictionary<string, string>();

        foreach (var token in tokens)
        {
            try
            {
                var message = new Message
                {
                    Fid = token,
                    Notification = new Notification
                    {
                        Title = title,
                        Body = body
                    },
                    Data = dataDict,
                    Android = new AndroidConfig { Priority = Priority.High },
                    Apns = new ApnsConfig
                    {
                        Aps = new Aps { Sound = "default" }
                    }
                };

                await FirebaseMessaging.DefaultInstance.SendAsync(message, ct);
                sent++;
                logger.LogInformation("FCM sent to …{Tail}: {Title}", Tail(token), title);
            }
            catch (FirebaseMessagingException ex) when (IsInvalidToken(ex))
            {
                logger.LogWarning("FCM invalid token …{Tail}: {Code} {Message}",
                    Tail(token), ex.MessagingErrorCode, ex.Message);
                invalid.Add(token);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "FCM send failed for token …{Tail}", Tail(token));
            }
        }

        return new FcmSendResult(tokens.Count, sent, invalid);
    }

    private bool TryEnsureFirebaseApp(FirebaseOptions cfg, out string reason)
    {
        if (!cfg.Enabled)
        {
            reason = "Firebase:Enabled=false";
            return false;
        }

        if (!cfg.HasCredentialsPath)
        {
            reason = "Firebase:CredentialsPath empty";
            return false;
        }

        var path = ResolveCredentialsPath(cfg.CredentialsPath!);
        if (!File.Exists(path))
        {
            reason = $"Firebase credentials file not found: {path}";
            return false;
        }

        try
        {
            lock (InitLock)
            {
                if (FirebaseApp.DefaultInstance == null)
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = CredentialFactory
                            .FromFile<ServiceAccountCredential>(path)
                            .ToGoogleCredential()
                    });
                    logger.LogInformation("Firebase Admin SDK initialized from {Path}", path);
                }
            }

            reason = "ok";
            return true;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to initialize Firebase Admin SDK from {Path}", path);
            reason = "Firebase Admin init failed";
            return false;
        }
    }

    private string ResolveCredentialsPath(string configured)
    {
        if (Path.IsPathRooted(configured))
            return configured;
        return Path.GetFullPath(Path.Combine(env.ContentRootPath, configured));
    }

    private static bool IsInvalidToken(FirebaseMessagingException ex) =>
        ex.MessagingErrorCode is MessagingErrorCode.Unregistered
            or MessagingErrorCode.InvalidArgument
            or MessagingErrorCode.SenderIdMismatch;

    private static string Tail(string token) => token.Length > 8 ? token[^8..] : token;
}
