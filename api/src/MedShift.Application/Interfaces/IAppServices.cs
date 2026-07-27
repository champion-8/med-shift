using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Jobs;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.DTOs.Admin;

namespace MedShift.Application.Interfaces;

public interface IStaffService
{
    Task<StaffProfileDto> GetProfileAsync(Guid userId, CancellationToken ct = default);
    Task<StaffProfileDto> UpdateProfileAsync(Guid userId, UpdateStaffProfileRequest request, CancellationToken ct = default);
    Task<StaffProfileDto> UpdateProfileImageAsync(Guid userId, string profileImageUrl, CancellationToken ct = default);
    Task<StaffDocumentDto> UploadDocumentAsync(
        Guid userId,
        string documentType,
        Stream content,
        string originalFileName,
        string? contentType,
        long fileSizeBytes,
        CancellationToken ct = default);
    Task<IReadOnlyList<StaffDocumentDto>> GetDocumentsAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<JobDto>> GetOpenJobsAsync(CancellationToken ct = default);
    Task<JobDto?> GetJobAsync(Guid jobId, CancellationToken ct = default);
    Task ApplyForJobAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task WithdrawApplicationAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task CancelHiredJobAsync(Guid userId, Guid jobId, string? reason, CancellationToken ct = default);
    Task<IReadOnlyList<JobDto>> GetMyJobsAsync(Guid userId, string filter, CancellationToken ct = default);
    Task<WalletDto> GetWalletAsync(Guid userId, CancellationToken ct = default);
    Task RequestWithdrawAsync(Guid userId, WithdrawRequest request, CancellationToken ct = default);
    Task<WalletDto> SettleNegativeBalanceAsync(Guid userId, SettleNegativeBalanceRequest? request = null, CancellationToken ct = default);
    Task CompleteCheckInAsync(Guid userId, Guid jobId, CompleteCheckInRequest request, CancellationToken ct = default);
    Task StartWorkAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task CompleteWorkAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task RateClinicAsync(Guid userId, Guid jobId, RateJobRequest request, CancellationToken ct = default);
    Task<JobIssueDto> ReportJobIssueAsync(Guid userId, Guid jobId, ReportJobIssueRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<CheckInRequirementDto>> GetCheckInRequirementsAsync(Guid jobId, CancellationToken ct = default);
    Task RegisterDeviceAsync(Guid userId, string token, string? platform, CancellationToken ct = default);
    Task<IReadOnlyList<NotificationDto>> GetNotificationsAsync(Guid userId, CancellationToken ct = default);
    Task MarkNotificationReadAsync(Guid userId, Guid notificationId, CancellationToken ct = default);
    Task TestPushAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<AnnouncementDto>> GetActiveAnnouncementsAsync(string locale, CancellationToken ct = default);
}

public interface IClinicService
{
    Task EnsureApprovedAsync(Guid userId, CancellationToken ct = default);
    Task<OrganizationDto> GetOrganizationAsync(Guid userId, CancellationToken ct = default);
    Task<OrganizationDto> UpdateOrganizationAsync(Guid userId, UpdateOrganizationRequest request, CancellationToken ct = default);
    Task<PlatformFeeConfigDto> GetPlatformFeeConfigAsync(CancellationToken ct = default);
    Task<JobPaymentPreviewDto> PreviewJobPaymentAsync(Guid userId, decimal hourlyRate, DateTime startTime, DateTime endTime, CancellationToken ct = default);
    Task<JobDto> CreateJobAsync(Guid userId, CreateJobRequest request, CancellationToken ct = default);
    Task<JobPaymentStatusDto> GetJobPaymentStatusAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task<JobDto> UpdateJobAsync(Guid userId, Guid jobId, UpdateJobRequest request, CancellationToken ct = default);
    Task CloseJobAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task<IReadOnlyList<JobDto>> GetJobsAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<ApplicantDto>> GetApplicantsAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task HireApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default);
    Task WaitlistApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default);
    Task RejectApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default);
    Task CompleteJobAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task MarkNoShowAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task RateJobAsync(Guid userId, Guid jobId, RateJobRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<JobIssueDto>> GetJobIssuesAsync(Guid userId, Guid jobId, CancellationToken ct = default);
    Task ResolveJobIssueAsync(Guid userId, Guid jobId, Guid issueId, CancellationToken ct = default);
    Task RegisterDeviceAsync(Guid userId, string token, string? platform, CancellationToken ct = default);
    Task TestPushAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<OrgMemberDto>> GetMembersAsync(Guid userId, CancellationToken ct = default);
    Task<OrgMemberDto> CreateMemberAsync(Guid userId, CreateOrgMemberRequest request, CancellationToken ct = default);
}

public interface IAdminService
{
    Task<IReadOnlyList<OrganizationDto>> GetPendingOrganizationsAsync(CancellationToken ct = default);
    Task ApproveOrganizationAsync(Guid adminUserId, Guid organizationId, CancellationToken ct = default);
    Task RejectOrganizationAsync(Guid adminUserId, Guid organizationId, string reason, CancellationToken ct = default);
    Task SuspendOrganizationAsync(Guid adminUserId, Guid organizationId, string? reason, CancellationToken ct = default);
    Task<IReadOnlyList<StaffListItemDto>> GetPendingStaffAsync(CancellationToken ct = default);
    Task ApproveStaffAsync(Guid adminUserId, Guid staffProfileId, CancellationToken ct = default);
    Task RejectStaffAsync(Guid adminUserId, Guid staffProfileId, string reason, CancellationToken ct = default);
    Task SuspendStaffAsync(Guid adminUserId, Guid staffProfileId, string? reason, CancellationToken ct = default);
    Task<IReadOnlyList<StaffListItemDto>> GetStaffAsync(CancellationToken ct = default);
    Task SetStaffActiveAsync(Guid staffUserId, bool isActive, CancellationToken ct = default);
    Task<IReadOnlyList<WithdrawalDto>> GetPendingWithdrawalsAsync(CancellationToken ct = default);
    Task ApproveWithdrawalAsync(Guid adminUserId, Guid withdrawalId, CancellationToken ct = default);
    Task RejectWithdrawalAsync(Guid adminUserId, Guid withdrawalId, string note, CancellationToken ct = default);
    Task<AnnouncementDto> CreateAnnouncementAsync(CreateAnnouncementRequest request, CancellationToken ct = default);
    Task<DashboardDto> GetDashboardAsync(CancellationToken ct = default);
}
