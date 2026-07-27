namespace MedShift.Application.DTOs.Clinic;

public record OrganizationDto(
    Guid Id,
    string Name,
    string? LegalName,
    string? TaxId,
    string? Phone,
    string? Email,
    string Address,
    double Latitude,
    double Longitude,
    string Status,
    string? RejectionReason,
    DateTime? ApprovedAt,
    double Rating = 0);

public record UpdateOrganizationRequest(
    string Name,
    string? LegalName,
    string? TaxId,
    string? Phone,
    string Address,
    double Latitude,
    double Longitude,
    string? DocumentUrl);

public record ApplicantDto(
    Guid ApplicationId,
    Guid StaffProfileId,
    string FullName,
    string Profession,
    string? LicenseNumber,
    double ReliabilityScore,
    double Rating,
    string Status,
    int? WaitlistPosition,
    DateTime AppliedAt);

public record OrgMemberDto(Guid UserId, Guid MembershipId, string Email, string Role, bool IsActive);

public record CreateOrgMemberRequest(string Email, string Password, string Role);

public record RateJobRequest(int Rating, string? Comment);
