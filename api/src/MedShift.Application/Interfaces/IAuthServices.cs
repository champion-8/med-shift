using System.Security.Claims;
using MedShift.Application.DTOs.Auth;
using MedShift.Domain.Entities;

namespace MedShift.Application.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateToken(User user, Guid? organizationId = null, string? organizationRole = null);
    ClaimsPrincipal? ValidateToken(string token);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct = default);
    Task<AuthResponse> RegisterStaffAsync(StaffRegisterRequest request, CancellationToken ct = default);
    Task<AuthResponse> RegisterClinicAsync(ClinicRegisterRequest request, CancellationToken ct = default);
    Task<object> GetMeAsync(Guid userId, CancellationToken ct = default);
    Task<ForgotPasswordResponse> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken ct = default);
    Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default);
}
