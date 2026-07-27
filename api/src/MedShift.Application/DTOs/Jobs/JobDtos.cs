namespace MedShift.Application.DTOs.Jobs;

public record JobDto(
    Guid Id,
    Guid OrganizationId,
    string OrganizationName,
    string Title,
    string Description,
    string LocationName,
    string Address,
    double Latitude,
    double Longitude,
    DateTime StartTime,
    DateTime EndTime,
    decimal HourlyRate,
    decimal TotalPay,
    string Status,
    IReadOnlyList<string> RequiredSkills,
    string? RequiredCertification,
    double MinReliabilityScore,
    Guid? HiredStaffProfileId,
    double? ClinicRating,
    string? ClinicReviewComment,
    DateTime CreatedAt,
    decimal? PlatformFee = null,
    decimal? TotalCharged = null,
    string? PaymentStatus = null,
    string? GatewayReference = null,
    string? MerchantReference = null,
    string? PaymentQrImageBase64 = null,
    double? StaffClinicRating = null,
    string? StaffClinicReviewComment = null);

public record CreateJobRequest(
    string Title,
    string Description,
    string? LocationName,
    string? Address,
    double? Latitude,
    double? Longitude,
    DateTime StartTime,
    DateTime EndTime,
    decimal HourlyRate,
    IReadOnlyList<string> RequiredSkills,
    string? RequiredCertification,
    double MinReliabilityScore,
    /// <summary>Must be true — clinic confirms gateway charge (TotalPay + platform fee).</summary>
    bool ConfirmGatewayPayment = false);

public record UpdateJobRequest(
    string Title,
    string Description,
    string LocationName,
    string Address,
    double Latitude,
    double Longitude,
    DateTime StartTime,
    DateTime EndTime,
    decimal HourlyRate,
    IReadOnlyList<string> RequiredSkills,
    string? RequiredCertification,
    double MinReliabilityScore);

public record PlatformFeeConfigDto(
    decimal FeePercent,
    string Note);

public record JobPaymentPreviewDto(
    decimal StaffPay,
    decimal FeePercent,
    decimal PlatformFee,
    decimal TotalCharged,
    double Hours);

public record JobPaymentStatusDto(
    Guid JobId,
    string JobStatus,
    string PaymentStatus,
    decimal TotalCharged,
    string? MerchantReference,
    string? GbpReferenceNo,
    bool IsPaid);
