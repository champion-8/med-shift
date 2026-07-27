using System.Security.Claims;
using MedShift.Application.Common;
using MedShift.Application.DTOs.Auth;
using MedShift.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MedShift.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(IAuthService authService) : ControllerBase
{
    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Login([FromBody] LoginRequest request, CancellationToken ct)
    {
        try
        {
            var result = await authService.LoginAsync(request, ct);
            return Ok(ApiResponse<AuthResponse>.Ok(result));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<AuthResponse>.Fail(ex.Message));
        }
    }

    [HttpPost("register/staff")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> RegisterStaff([FromBody] StaffRegisterRequest request, CancellationToken ct)
    {
        try
        {
            var result = await authService.RegisterStaffAsync(request, ct);
            return Ok(ApiResponse<AuthResponse>.Ok(result));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<AuthResponse>.Fail(ex.Message));
        }
    }

    [HttpPost("register/clinic")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> RegisterClinic([FromBody] ClinicRegisterRequest request, CancellationToken ct)
    {
        try
        {
            var result = await authService.RegisterClinicAsync(request, ct);
            return Ok(ApiResponse<AuthResponse>.Ok(result));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<AuthResponse>.Fail(ex.Message));
        }
    }

    [HttpPost("forgot-password")]
    public async Task<ActionResult<ApiResponse<ForgotPasswordResponse>>> ForgotPassword(
        [FromBody] ForgotPasswordRequest request,
        CancellationToken ct)
    {
        try
        {
            var result = await authService.ForgotPasswordAsync(request, ct);
            return Ok(ApiResponse<ForgotPasswordResponse>.Ok(result, result.Message));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<ForgotPasswordResponse>.Fail(ex.Message));
        }
    }

    [HttpPost("reset-password")]
    public async Task<ActionResult<ApiResponse<object>>> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken ct)
    {
        try
        {
            await authService.ResetPasswordAsync(request, ct);
            return Ok(ApiResponse<object>.Ok(new { }, "ตั้งรหัสผ่านใหม่สำเร็จ กรุณาเข้าสู่ระบบ"));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ApiResponse<object>.Fail(ex.Message));
        }
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<object>>> Me(CancellationToken ct)
    {
        var userId = GetUserId();
        var me = await authService.GetMeAsync(userId, ct);
        return Ok(ApiResponse<object>.Ok(me));
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue("sub")
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException());
}
