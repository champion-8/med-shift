namespace MedShift.Application.DTOs.Auth;

public record LoginRequest(string Email, string Password);

public record StaffRegisterRequest(
    string Email,
    string Password,
    string FirstName,
    string LastName,
    string? Phone,
    string Profession,
    string? LicenseNumber,
    string? NationalId = null,
    DateTime? LicenseExpiryDate = null,
    string? LaserCode = null,
    string? BankName = null,
    string? BankAccountNumber = null,
    string? BankAccountName = null,
    bool? BankAccountVerified = null,
    string? PromptPayId = null);

public record ClinicRegisterRequest(
    string Email,
    string Password,
    string FirstName,
    string LastName,
    string OrganizationName,
    string? LegalName,
    string? TaxId,
    string? Phone,
    string Address,
    double Latitude,
    double Longitude,
    string? DocumentUrl);

public record AuthResponse(
    string AccessToken,
    DateTime ExpiresAt,
    string Role,
    Guid UserId,
    object? Profile);

public record ForgotPasswordRequest(string Email);

public record ForgotPasswordResponse(
    string Message,
    /// <summary>Returned only when EmailSettings/SMTP is unavailable or send fails (dev fallback).</summary>
    string? ResetCode,
    DateTime? ExpiresAt);

public record ResetPasswordRequest(string Email, string Code, string NewPassword);
