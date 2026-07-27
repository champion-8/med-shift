namespace MedShift.Domain.Enums;

public enum JobPaymentStatus
{
    /// <summary>Waiting for gateway confirmation (QR unpaid).</summary>
    Pending = 0,
    /// <summary>Clinic paid; staff share held until job completes.</summary>
    Held = 1,
    /// <summary>Staff share released to staff wallet.</summary>
    Released = 2,
    /// <summary>Staff share refunded to clinic.</summary>
    Refunded = 3
}
