using MedShift.Domain.Enums;

namespace MedShift.Application.DTOs.Staff;

public record StaffDocumentDto(
    Guid Id,
    string DocumentType,
    string FileUrl,
    string? OriginalFileName,
    string VerificationStatus,
    string? RejectionReason,
    DateTime CreatedAt);

public record StaffProfileDto(
    Guid Id,
    Guid UserId,
    string Email,
    string FirstName,
    string LastName,
    string? Phone,
    string? ProfileImageUrl,
    string Profession,
    string? Specialty,
    string? LicenseNumber,
    double ReliabilityScore,
    double Rating,
    int TotalJobsCompleted,
    decimal TotalEarnings,
    string? BankName,
    string? BankAccountNumber,
    string? BankAccountName,
    bool BankAccountVerified,
    string Status,
    string? RejectionReason,
    double? CurrentLocationLat,
    double? CurrentLocationLng,
    bool IsAvailable,
    IReadOnlyList<StaffSkillDto> Skills,
    string? NationalId = null,
    DateTime? LicenseExpiryDate = null,
    string? LaserCode = null,
    string? PromptPayId = null,
    IReadOnlyList<StaffDocumentDto>? Documents = null);

public record StaffSkillDto(Guid Id, string Name, decimal MinRate, decimal MaxRate, int YearsExperience, bool IsVerified, string? Certification);

public record UpdateStaffProfileRequest(
    string FirstName,
    string LastName,
    string? Phone,
    string? Specialty,
    string? LicenseNumber,
    string? NationalId,
    int YearsExperience,
    string? BankName,
    string? BankAccountNumber,
    string? BankAccountName,
    bool? BankAccountVerified,
    double? CurrentLocationLat,
    double? CurrentLocationLng,
    bool? IsAvailable,
    IReadOnlyList<UpsertSkillRequest>? Skills,
    DateTime? LicenseExpiryDate = null,
    string? LaserCode = null,
    string? PromptPayId = null);

public record UploadStaffDocumentRequest(string DocumentType);

public record UpsertSkillRequest(string Name, decimal MinRate, decimal MaxRate, int YearsExperience, string? Certification);

public record WalletDto(decimal Balance, IReadOnlyList<TransactionDto> Transactions);
public record TransactionDto(Guid Id, string Type, decimal Amount, string Status, string Description, decimal BalanceBefore, decimal BalanceAfter, DateTime CreatedAt, Guid? JobId);
public record WithdrawRequest(decimal Amount);
public record SettleNegativeBalanceRequest(string? PaymentReference = null);
public record CompleteCheckInRequest(
    IReadOnlyList<int> CompletedSteps,
    double Latitude,
    double Longitude,
    double? AccuracyMeters = null);
public record CheckInRequirementDto(Guid Id, int StepNumber, string Title, string Content, string Type, bool RequiresAcknowledgment, int EstimatedReadTimeSeconds);
public record NotificationDto(Guid Id, string Title, string Message, string Type, bool IsRead, DateTime CreatedAt, Guid? JobId);
public record AnnouncementDto(Guid Id, string Title, string Message, string Type, DateTime CreatedAt, DateTime? ExpiresAt);

public record ReportJobIssueRequest(string Category, string Description);
public record JobIssueDto(
    Guid Id,
    Guid JobId,
    Guid StaffProfileId,
    string StaffName,
    string Category,
    string Description,
    string Status,
    DateTime CreatedAt,
    DateTime? ResolvedAt);

public record StaffListItemDto(
    Guid UserId,
    Guid StaffProfileId,
    string Email,
    string FullName,
    string Profession,
    bool IsActive,
    string Status,
    string? LicenseNumber,
    double ReliabilityScore,
    DateTime CreatedAt);
