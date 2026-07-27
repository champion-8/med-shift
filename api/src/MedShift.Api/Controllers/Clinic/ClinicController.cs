using System.Security.Claims;
using MedShift.Application.Common;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Jobs;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MedShift.Api.Controllers.Clinic;

[ApiController]
[Authorize(Roles = "Clinic")]
[Route("api/clinic")]
public class ClinicController(IClinicService clinicService) : ControllerBase
{
    [HttpGet("organization")]
    public async Task<ActionResult<ApiResponse<OrganizationDto>>> Organization(CancellationToken ct)
        => Ok(ApiResponse<OrganizationDto>.Ok(await clinicService.GetOrganizationAsync(UserId, ct)));

    [HttpPut("organization")]
    public async Task<ActionResult<ApiResponse<OrganizationDto>>> UpdateOrganization([FromBody] UpdateOrganizationRequest request, CancellationToken ct)
    {
        try { return Ok(ApiResponse<OrganizationDto>.Ok(await clinicService.UpdateOrganizationAsync(UserId, request, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<OrganizationDto>.Fail(ex.Message)); }
    }

    [HttpGet("jobs")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<JobDto>>>> Jobs(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<JobDto>>.Ok(await clinicService.GetJobsAsync(UserId, ct)));

    [HttpGet("billing/fee-config")]
    public async Task<ActionResult<ApiResponse<PlatformFeeConfigDto>>> FeeConfig(CancellationToken ct)
        => Ok(ApiResponse<PlatformFeeConfigDto>.Ok(await clinicService.GetPlatformFeeConfigAsync(ct)));

    [HttpGet("billing/payment-preview")]
    public async Task<ActionResult<ApiResponse<JobPaymentPreviewDto>>> PaymentPreview(
        [FromQuery] decimal hourlyRate,
        [FromQuery] DateTime startTime,
        [FromQuery] DateTime endTime,
        CancellationToken ct)
    {
        try
        {
            return Ok(ApiResponse<JobPaymentPreviewDto>.Ok(
                await clinicService.PreviewJobPaymentAsync(UserId, hourlyRate, startTime, endTime, ct)));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<JobPaymentPreviewDto>.Fail(ex.Message));
        }
    }

    [HttpPost("jobs")]
    public async Task<ActionResult<ApiResponse<JobDto>>> CreateJob([FromBody] CreateJobRequest request, CancellationToken ct)
    {
        try { return Ok(ApiResponse<JobDto>.Ok(await clinicService.CreateJobAsync(UserId, request, ct))); }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<JobDto>.Fail(ex.Message)); }
    }

    [HttpGet("jobs/{jobId:guid}/payment-status")]
    public async Task<ActionResult<ApiResponse<JobPaymentStatusDto>>> JobPaymentStatus(Guid jobId, CancellationToken ct)
    {
        try { return Ok(ApiResponse<JobPaymentStatusDto>.Ok(await clinicService.GetJobPaymentStatusAsync(UserId, jobId, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<JobPaymentStatusDto>.Fail(ex.Message)); }
    }

    [HttpPut("jobs/{jobId:guid}")]
    public async Task<ActionResult<ApiResponse<JobDto>>> UpdateJob(Guid jobId, [FromBody] UpdateJobRequest request, CancellationToken ct)
    {
        try { return Ok(ApiResponse<JobDto>.Ok(await clinicService.UpdateJobAsync(UserId, jobId, request, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<JobDto>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/close")]
    public async Task<ActionResult<ApiResponse<object>>> CloseJob(Guid jobId, CancellationToken ct)
    {
        try
        {
            await clinicService.CloseJobAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปิดงานแล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("jobs/{jobId:guid}/applicants")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<ApplicantDto>>>> Applicants(Guid jobId, CancellationToken ct)
    {
        try { return Ok(ApiResponse<IReadOnlyList<ApplicantDto>>.Ok(await clinicService.GetApplicantsAsync(UserId, jobId, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<IReadOnlyList<ApplicantDto>>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/applicants/{staffProfileId:guid}/hire")]
    public async Task<ActionResult<ApiResponse<object>>> Hire(Guid jobId, Guid staffProfileId, CancellationToken ct)
    {
        try
        {
            await clinicService.HireApplicantAsync(UserId, jobId, staffProfileId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "จ้างงานสำเร็จ"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/applicants/{staffProfileId:guid}/waitlist")]
    public async Task<ActionResult<ApiResponse<object>>> Waitlist(Guid jobId, Guid staffProfileId, CancellationToken ct)
    {
        try
        {
            await clinicService.WaitlistApplicantAsync(UserId, jobId, staffProfileId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "เพิ่มเข้า waitlist แล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/applicants/{staffProfileId:guid}/reject")]
    public async Task<ActionResult<ApiResponse<object>>> Reject(Guid jobId, Guid staffProfileId, CancellationToken ct)
    {
        try
        {
            await clinicService.RejectApplicantAsync(UserId, jobId, staffProfileId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปฏิเสธผู้สมัครแล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/complete")]
    public async Task<ActionResult<ApiResponse<object>>> Complete(Guid jobId, CancellationToken ct)
    {
        try
        {
            await clinicService.CompleteJobAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปิดงานและจ่ายเงินแล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/no-show")]
    public async Task<ActionResult<ApiResponse<object>>> NoShow(Guid jobId, CancellationToken ct)
    {
        try
        {
            await clinicService.MarkNoShowAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "บันทึก No-show แล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/rate")]
    public async Task<ActionResult<ApiResponse<object>>> Rate(Guid jobId, [FromBody] RateJobRequest request, CancellationToken ct)
    {
        try
        {
            await clinicService.RateJobAsync(UserId, jobId, request, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ให้คะแนนแล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("jobs/{jobId:guid}/issues")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<JobIssueDto>>>> Issues(Guid jobId, CancellationToken ct)
    {
        try
        {
            return Ok(ApiResponse<IReadOnlyList<JobIssueDto>>.Ok(await clinicService.GetJobIssuesAsync(UserId, jobId, ct)));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<IReadOnlyList<JobIssueDto>>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/issues/{issueId:guid}/resolve")]
    public async Task<ActionResult<ApiResponse<object>>> ResolveIssue(Guid jobId, Guid issueId, CancellationToken ct)
    {
        try
        {
            await clinicService.ResolveJobIssueAsync(UserId, jobId, issueId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปิดรายงานปัญหาแล้ว"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("members")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<OrgMemberDto>>>> Members(CancellationToken ct)
    {
        try { return Ok(ApiResponse<IReadOnlyList<OrgMemberDto>>.Ok(await clinicService.GetMembersAsync(UserId, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<IReadOnlyList<OrgMemberDto>>.Fail(ex.Message)); }
    }

    [HttpPost("members")]
    public async Task<ActionResult<ApiResponse<OrgMemberDto>>> CreateMember([FromBody] CreateOrgMemberRequest request, CancellationToken ct)
    {
        try { return Ok(ApiResponse<OrgMemberDto>.Ok(await clinicService.CreateMemberAsync(UserId, request, ct))); }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<OrgMemberDto>.Fail(ex.Message)); }
    }

    [HttpPut("notifications/device")]
    public async Task<ActionResult<ApiResponse<object>>> RegisterDevice([FromBody] DeviceTokenRequest request, CancellationToken ct)
    {
        try
        {
            await clinicService.RegisterDeviceAsync(UserId, request.FirebaseDeviceToken, request.Platform, ct);
            return Ok(ApiResponse<object>.Ok(new { }));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("notifications/test-push")]
    public async Task<ActionResult<ApiResponse<object>>> TestPush(CancellationToken ct)
    {
        try
        {
            await clinicService.TestPushAsync(UserId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ส่งการแจ้งเตือนทดสอบแล้ว (ดู in-app + FCM log)"));
        }
        catch (Exception ex) when (ex is InvalidOperationException or UnauthorizedAccessException)
        { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    private Guid UserId =>
        Guid.Parse(User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

public record DeviceTokenRequest(string FirebaseDeviceToken, string? Platform);
