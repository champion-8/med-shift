using System.Security.Claims;
using MedShift.Application.Common;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Jobs;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MedShift.Api.Controllers.Staff;

[ApiController]
[Authorize(Roles = "Staff")]
[Route("api/staff")]
public class StaffController(IStaffService staffService, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet("profile")]
    public async Task<ActionResult<ApiResponse<StaffProfileDto>>> Profile(CancellationToken ct)
        => Ok(ApiResponse<StaffProfileDto>.Ok(await staffService.GetProfileAsync(UserId, ct)));

    [HttpPut("profile")]
    public async Task<ActionResult<ApiResponse<StaffProfileDto>>> UpdateProfile([FromBody] UpdateStaffProfileRequest request, CancellationToken ct)
    {
        try { return Ok(ApiResponse<StaffProfileDto>.Ok(await staffService.UpdateProfileAsync(UserId, request, ct))); }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<StaffProfileDto>.Fail(ex.Message)); }
    }

    [HttpPost("profile/image")]
    [RequestSizeLimit(5_000_000)]
    public async Task<ActionResult<ApiResponse<StaffProfileDto>>> UploadProfileImage(IFormFile? file, CancellationToken ct)
    {
        try
        {
            if (file == null || file.Length == 0)
                return BadRequest(ApiResponse<StaffProfileDto>.Fail("กรุณาเลือกรูปภาพ"));

            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png", ".webp" };
            if (!allowed.Contains(ext))
                return BadRequest(ApiResponse<StaffProfileDto>.Fail("รองรับเฉพาะ JPG, PNG, WEBP"));

            var contentType = (file.ContentType ?? "").ToLowerInvariant();
            if (contentType.Length > 0 &&
                contentType is not ("image/jpeg" or "image/png" or "image/webp" or "image/jpg" or "application/octet-stream"))
                return BadRequest(ApiResponse<StaffProfileDto>.Fail("ชนิดไฟล์ไม่ถูกต้อง"));

            var webRoot = string.IsNullOrWhiteSpace(env.WebRootPath)
                ? Path.Combine(env.ContentRootPath, "wwwroot")
                : env.WebRootPath;
            var dir = Path.Combine(webRoot, "uploads", "profiles");
            Directory.CreateDirectory(dir);

            var fileName = $"{UserId:N}{ext}";
            var physicalPath = Path.Combine(dir, fileName);
            await using (var stream = System.IO.File.Create(physicalPath))
            {
                await file.CopyToAsync(stream, ct);
            }

            var relativeUrl = $"/uploads/profiles/{fileName}";
            var profile = await staffService.UpdateProfileImageAsync(UserId, relativeUrl, ct);
            return Ok(ApiResponse<StaffProfileDto>.Ok(profile, "อัปโหลดรูปโปรไฟล์สำเร็จ"));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<StaffProfileDto>.Fail(ex.Message));
        }
    }

    [HttpGet("documents")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<StaffDocumentDto>>>> Documents(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<StaffDocumentDto>>.Ok(await staffService.GetDocumentsAsync(UserId, ct)));

    [HttpPost("documents")]
    [RequestSizeLimit(8_000_000)]
    public async Task<ActionResult<ApiResponse<StaffDocumentDto>>> UploadDocument(
        [FromForm] string documentType,
        IFormFile? file,
        CancellationToken ct)
    {
        try
        {
            if (file == null || file.Length == 0)
                return BadRequest(ApiResponse<StaffDocumentDto>.Fail("กรุณาเลือกไฟล์เอกสาร"));

            await using var stream = file.OpenReadStream();
            var doc = await staffService.UploadDocumentAsync(
                UserId,
                documentType,
                stream,
                file.FileName,
                file.ContentType,
                file.Length,
                ct);
            return Ok(ApiResponse<StaffDocumentDto>.Ok(doc, "อัปโหลดเอกสารสำเร็จ"));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<StaffDocumentDto>.Fail(ex.Message));
        }
    }

    [HttpGet("jobs")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<JobDto>>>> OpenJobs(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<JobDto>>.Ok(await staffService.GetOpenJobsAsync(ct)));

    [HttpGet("jobs/{jobId:guid}")]
    public async Task<ActionResult<ApiResponse<JobDto>>> Job(Guid jobId, CancellationToken ct)
    {
        var job = await staffService.GetJobAsync(jobId, ct);
        return job == null
            ? NotFound(ApiResponse<JobDto>.Fail("ไม่พบงาน"))
            : Ok(ApiResponse<JobDto>.Ok(job));
    }

    [HttpPost("jobs/{jobId:guid}/apply")]
    public async Task<ActionResult<ApiResponse<object>>> Apply(Guid jobId, CancellationToken ct)
    {
        try
        {
            await staffService.ApplyForJobAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "สมัครงานสำเร็จ"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/withdraw")]
    public async Task<ActionResult<ApiResponse<object>>> Withdraw(Guid jobId, CancellationToken ct)
    {
        try
        {
            await staffService.WithdrawApplicationAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ถอนการสมัครแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/cancel")]
    public async Task<ActionResult<ApiResponse<object>>> Cancel(Guid jobId, [FromBody] CancelRequest? body, CancellationToken ct)
    {
        try
        {
            await staffService.CancelHiredJobAsync(UserId, jobId, body?.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ยกเลิกงานแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("my-jobs")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<JobDto>>>> MyJobs([FromQuery] string filter = "all", CancellationToken ct = default)
        => Ok(ApiResponse<IReadOnlyList<JobDto>>.Ok(await staffService.GetMyJobsAsync(UserId, filter, ct)));

    [HttpGet("wallet")]
    public async Task<ActionResult<ApiResponse<WalletDto>>> Wallet(CancellationToken ct)
        => Ok(ApiResponse<WalletDto>.Ok(await staffService.GetWalletAsync(UserId, ct)));

    [HttpPost("wallet/withdraw")]
    public async Task<ActionResult<ApiResponse<object>>> WithdrawMoney([FromBody] WithdrawRequest request, CancellationToken ct)
    {
        try
        {
            await staffService.RequestWithdrawAsync(UserId, request, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ส่งคำขอถอนเงินแล้ว รอแอดมินอนุมัติ"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("wallet/settle")]
    public async Task<ActionResult<ApiResponse<WalletDto>>> SettleNegativeBalance(
        [FromBody] SettleNegativeBalanceRequest? request,
        CancellationToken ct)
    {
        try
        {
            var wallet = await staffService.SettleNegativeBalanceAsync(UserId, request, ct);
            return Ok(ApiResponse<WalletDto>.Ok(wallet, "ชำระยอดติดลบสำเร็จ บัญชีถูกปลดล็อคแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<WalletDto>.Fail(ex.Message)); }
    }

    [HttpGet("jobs/{jobId:guid}/check-in-requirements")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<CheckInRequirementDto>>>> CheckInRequirements(Guid jobId, CancellationToken ct)
    {
        try { return Ok(ApiResponse<IReadOnlyList<CheckInRequirementDto>>.Ok(await staffService.GetCheckInRequirementsAsync(jobId, ct))); }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<IReadOnlyList<CheckInRequirementDto>>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/check-in")]
    public async Task<ActionResult<ApiResponse<object>>> CheckIn(Guid jobId, [FromBody] CompleteCheckInRequest request, CancellationToken ct)
    {
        try
        {
            await staffService.CompleteCheckInAsync(UserId, jobId, request, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "เช็คอินสำเร็จ"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/start")]
    public async Task<ActionResult<ApiResponse<object>>> Start(Guid jobId, CancellationToken ct)
    {
        try
        {
            await staffService.StartWorkAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "เริ่มงานแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/complete")]
    public async Task<ActionResult<ApiResponse<object>>> Complete(Guid jobId, CancellationToken ct)
    {
        try
        {
            await staffService.CompleteWorkAsync(UserId, jobId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปิดงานสำเร็จ ได้รับค่าจ้างแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/issues")]
    public async Task<ActionResult<ApiResponse<JobIssueDto>>> ReportIssue(
        Guid jobId,
        [FromBody] ReportJobIssueRequest request,
        CancellationToken ct)
    {
        try
        {
            var issue = await staffService.ReportJobIssueAsync(UserId, jobId, request, ct);
            return Ok(ApiResponse<JobIssueDto>.Ok(issue, "ส่งรายงานปัญหาแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<JobIssueDto>.Fail(ex.Message)); }
    }

    [HttpPost("jobs/{jobId:guid}/rate-clinic")]
    public async Task<ActionResult<ApiResponse<object>>> RateClinic(Guid jobId, [FromBody] RateJobRequest request, CancellationToken ct)
    {
        try
        {
            await staffService.RateClinicAsync(UserId, jobId, request, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ให้คะแนนคลินิกแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPut("notifications/device")]
    public async Task<ActionResult<ApiResponse<object>>> RegisterDevice([FromBody] DeviceTokenRequest request, CancellationToken ct)
    {
        await staffService.RegisterDeviceAsync(UserId, request.FirebaseDeviceToken, request.Platform, ct);
        return Ok(ApiResponse<object>.Ok(new { }));
    }

    [HttpGet("notifications")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<NotificationDto>>>> Notifications(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<NotificationDto>>.Ok(await staffService.GetNotificationsAsync(UserId, ct)));

    [HttpPatch("notifications/{id:guid}/read")]
    public async Task<ActionResult<ApiResponse<object>>> MarkRead(Guid id, CancellationToken ct)
    {
        try
        {
            await staffService.MarkNotificationReadAsync(UserId, id, ct);
            return Ok(ApiResponse<object>.Ok(new { }));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("notifications/test-push")]
    public async Task<ActionResult<ApiResponse<object>>> TestPush(CancellationToken ct)
    {
        try
        {
            await staffService.TestPushAsync(UserId, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ส่งการแจ้งเตือนทดสอบแล้ว (ดู in-app + FCM log)"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("announcements/active")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AnnouncementDto>>>> Announcements([FromQuery] string locale = "th", CancellationToken ct = default)
        => Ok(ApiResponse<IReadOnlyList<AnnouncementDto>>.Ok(await staffService.GetActiveAnnouncementsAsync(locale, ct)));

    private Guid UserId =>
        Guid.Parse(User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

public record CancelRequest(string? Reason);
public record DeviceTokenRequest(string FirebaseDeviceToken, string? Platform);
