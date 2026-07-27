namespace MedShift.Domain.Enums;

public enum JobStatus
{
    Open = 1,
    Applied = 2,
    Selecting = 3,
    Confirmed = 4,
    CheckedIn = 5,
    InProgress = 6,
    Completed = 7,
    Cancelled = 8,
    /// <summary>Awaiting clinic payment gateway confirmation (e.g. PromptPay QR).</summary>
    PendingPayment = 9
}
