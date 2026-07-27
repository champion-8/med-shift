using System.Security.Claims;
using MedShift.Application.Common;
using MedShift.Application.DTOs.Admin;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MedShift.Api.Controllers.Admin;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/admin")]
public class AdminController(IAdminService adminService) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<ActionResult<ApiResponse<DashboardDto>>> Dashboard(CancellationToken ct)
        => Ok(ApiResponse<DashboardDto>.Ok(await adminService.GetDashboardAsync(ct)));

    [HttpGet("organizations/pending")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<OrganizationDto>>>> PendingOrgs(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<OrganizationDto>>.Ok(await adminService.GetPendingOrganizationsAsync(ct)));

    [HttpPost("organizations/{id:guid}/approve")]
    public async Task<ActionResult<ApiResponse<object>>> Approve(Guid id, CancellationToken ct)
    {
        try
        {
            await adminService.ApproveOrganizationAsync(UserId, id, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "อนุมัติองค์กรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("organizations/{id:guid}/reject")]
    public async Task<ActionResult<ApiResponse<object>>> Reject(Guid id, [FromBody] RejectRequest body, CancellationToken ct)
    {
        try
        {
            await adminService.RejectOrganizationAsync(UserId, id, body.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปฏิเสธองค์กรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("organizations/{id:guid}/suspend")]
    public async Task<ActionResult<ApiResponse<object>>> Suspend(Guid id, [FromBody] RejectRequest? body, CancellationToken ct)
    {
        try
        {
            await adminService.SuspendOrganizationAsync(UserId, id, body?.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ระงับองค์กรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("staff/pending")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<StaffListItemDto>>>> PendingStaff(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<StaffListItemDto>>.Ok(await adminService.GetPendingStaffAsync(ct)));

    [HttpPost("staff/{id:guid}/approve")]
    public async Task<ActionResult<ApiResponse<object>>> ApproveStaff(Guid id, CancellationToken ct)
    {
        try
        {
            await adminService.ApproveStaffAsync(UserId, id, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "อนุมัติบุคลากรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("staff/{id:guid}/reject")]
    public async Task<ActionResult<ApiResponse<object>>> RejectStaff(Guid id, [FromBody] RejectRequest body, CancellationToken ct)
    {
        try
        {
            await adminService.RejectStaffAsync(UserId, id, body.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปฏิเสธบุคลากรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("staff/{id:guid}/suspend")]
    public async Task<ActionResult<ApiResponse<object>>> SuspendStaff(Guid id, [FromBody] RejectRequest? body, CancellationToken ct)
    {
        try
        {
            await adminService.SuspendStaffAsync(UserId, id, body?.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ระงับบุคลากรแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("staff")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<StaffListItemDto>>>> Staff(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<StaffListItemDto>>.Ok(await adminService.GetStaffAsync(ct)));

    [HttpPost("staff/{userId:guid}/active")]
    public async Task<ActionResult<ApiResponse<object>>> SetStaffActive(Guid userId, [FromBody] SetActiveRequest body, CancellationToken ct)
    {
        try
        {
            await adminService.SetStaffActiveAsync(userId, body.IsActive, ct);
            return Ok(ApiResponse<object>.Ok(new { }));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpGet("withdrawals/pending")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<WithdrawalDto>>>> PendingWithdrawals(CancellationToken ct)
        => Ok(ApiResponse<IReadOnlyList<WithdrawalDto>>.Ok(await adminService.GetPendingWithdrawalsAsync(ct)));

    [HttpPost("withdrawals/{id:guid}/approve")]
    public async Task<ActionResult<ApiResponse<object>>> ApproveWithdrawal(Guid id, CancellationToken ct)
    {
        try
        {
            await adminService.ApproveWithdrawalAsync(UserId, id, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "อนุมัติการถอนเงินแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("withdrawals/{id:guid}/reject")]
    public async Task<ActionResult<ApiResponse<object>>> RejectWithdrawal(Guid id, [FromBody] RejectRequest body, CancellationToken ct)
    {
        try
        {
            await adminService.RejectWithdrawalAsync(UserId, id, body.Reason, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ปฏิเสธการถอนเงินแล้ว"));
        }
        catch (InvalidOperationException ex) { return BadRequest(ApiResponse<object>.Fail(ex.Message)); }
    }

    [HttpPost("announcements")]
    public async Task<ActionResult<ApiResponse<AnnouncementDto>>> CreateAnnouncement([FromBody] CreateAnnouncementRequest request, CancellationToken ct)
        => Ok(ApiResponse<AnnouncementDto>.Ok(await adminService.CreateAnnouncementAsync(request, ct)));

    private Guid UserId =>
        Guid.Parse(User.FindFirstValue("sub") ?? User.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

public record RejectRequest(string Reason);
public record SetActiveRequest(bool IsActive);
