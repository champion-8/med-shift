using System.Net;
using System.Text.Json;
using MedShift.Application.DTOs.Auth;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using MedShift.Infrastructure.Email;
using MedShift.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace MedShift.Infrastructure.Auth;

public class AuthService(
    MedShiftDbContext db,
    IPasswordHasher passwordHasher,
    IJwtTokenService jwtTokenService,
    IEmailSender emailSender,
    ILogger<AuthService> logger) : IAuthService
{
    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var user = await db.Users
            .Include(u => u.StaffProfile)!.ThenInclude(s => s!.Skills)
            .Include(u => u.OrganizationMemberships).ThenInclude(m => m.Organization)
            .FirstOrDefaultAsync(u => u.Email == email, ct)
            ?? throw new InvalidOperationException("อีเมลหรือรหัสผ่านไม่ถูกต้อง");

        if (!user.IsActive)
            throw new InvalidOperationException("บัญชีถูกระงับการใช้งาน");

        if (!passwordHasher.Verify(request.Password, user.PasswordHash))
            throw new InvalidOperationException("อีเมลหรือรหัสผ่านไม่ถูกต้อง");

        Guid? orgId = null;
        string? orgRole = null;
        object? profile = null;

        if (user.Role == UserRole.Staff && user.StaffProfile != null)
        {
            profile = MapStaff(user);
        }
        else if (user.Role == UserRole.Clinic)
        {
            var membership = user.OrganizationMemberships.FirstOrDefault(m => m.IsActive)
                ?? throw new InvalidOperationException("ไม่พบองค์กรที่ผูกกับบัญชีนี้");
            orgId = membership.OrganizationId;
            orgRole = membership.Role.ToString();
            profile = MapOrg(membership.Organization, membership);
        }
        else if (user.Role == UserRole.Admin)
        {
            profile = new { user.Id, user.Email, Role = user.Role.ToString() };
        }

        var (token, expires) = jwtTokenService.CreateToken(user, orgId, orgRole);
        return new AuthResponse(token, expires, user.Role.ToString(), user.Id, profile);
    }

    public async Task<AuthResponse> RegisterStaffAsync(StaffRegisterRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(u => u.Email == email, ct))
            throw new InvalidOperationException("อีเมลนี้ถูกใช้งานแล้ว");

        if (!Enum.TryParse<StaffProfession>(request.Profession, true, out var profession))
            profession = StaffProfession.Nurse;

        var user = new User
        {
            Email = email,
            PasswordHash = passwordHasher.Hash(request.Password),
            Role = UserRole.Staff
        };

        var profile = new StaffProfile
        {
            User = user,
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Phone = request.Phone,
            Profession = profession,
            LicenseNumber = request.LicenseNumber,
            LicenseExpiryDate = request.LicenseExpiryDate,
            NationalId = request.NationalId,
            LaserCode = request.LaserCode,
            BankName = request.BankName,
            BankAccountNumber = request.BankAccountNumber,
            BankAccountName = request.BankAccountName,
            PromptPayId = request.PromptPayId,
            Status = StaffStatus.Pending,
            Wallet = new Wallet()
        };

        var hasPromptPay = !string.IsNullOrWhiteSpace(profile.PromptPayId);
        var completeBank = !string.IsNullOrWhiteSpace(profile.BankName)
            && !string.IsNullOrWhiteSpace(profile.BankAccountNumber)
            && !string.IsNullOrWhiteSpace(profile.BankAccountName);
        if (hasPromptPay || completeBank)
        {
            static string Norm(string s) =>
                string.Join(' ', s.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries)).ToLowerInvariant();
            var nameOk = !string.IsNullOrWhiteSpace(profile.BankAccountName)
                && Norm(profile.BankAccountName!) == Norm($"{profile.FirstName} {profile.LastName}");
            profile.BankAccountVerified = hasPromptPay && !completeBank
                || (completeBank && nameOk && (request.BankAccountVerified ?? true));
        }

        db.Users.Add(user);
        db.StaffProfiles.Add(profile);
        await db.SaveChangesAsync(ct);

        user.StaffProfile = profile;
        var (token, expires) = jwtTokenService.CreateToken(user);
        return new AuthResponse(token, expires, user.Role.ToString(), user.Id, MapStaff(user));
    }

    public async Task<AuthResponse> RegisterClinicAsync(ClinicRegisterRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(u => u.Email == email, ct))
            throw new InvalidOperationException("อีเมลนี้ถูกใช้งานแล้ว");

        var user = new User
        {
            Email = email,
            PasswordHash = passwordHasher.Hash(request.Password),
            Role = UserRole.Clinic
        };

        var org = new Organization
        {
            Name = request.OrganizationName.Trim(),
            LegalName = request.LegalName,
            TaxId = request.TaxId,
            Phone = request.Phone,
            Email = email,
            Address = request.Address,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            DocumentUrl = request.DocumentUrl,
            Status = OrganizationStatus.Pending
        };

        var membership = new OrganizationMember
        {
            User = user,
            Organization = org,
            Role = OrganizationMemberRole.Owner
        };

        db.Users.Add(user);
        db.Organizations.Add(org);
        db.OrganizationMembers.Add(membership);
        await db.SaveChangesAsync(ct);

        var (token, expires) = jwtTokenService.CreateToken(user, org.Id, membership.Role.ToString());
        return new AuthResponse(token, expires, user.Role.ToString(), user.Id, MapOrg(org, membership));
    }

    public async Task<object> GetMeAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await db.Users
            .Include(u => u.StaffProfile)!.ThenInclude(s => s!.Skills)
            .Include(u => u.OrganizationMemberships).ThenInclude(m => m.Organization)
            .FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new InvalidOperationException("ไม่พบผู้ใช้");

        return user.Role switch
        {
            UserRole.Staff => MapStaff(user),
            UserRole.Clinic => MapOrg(
                user.OrganizationMemberships.First(m => m.IsActive).Organization,
                user.OrganizationMemberships.First(m => m.IsActive)),
            _ => new { user.Id, user.Email, Role = user.Role.ToString() }
        };
    }

    public async Task<ForgotPasswordResponse> ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken ct = default)
    {
        const string genericMessage = "หากอีเมลนี้มีในระบบ เราได้สร้างรหัสรีเซ็ตแล้ว";
        var email = request.Email.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            throw new InvalidOperationException("กรุณากรอกอีเมลให้ถูกต้อง");

        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);
        if (user == null || !user.IsActive)
            return new ForgotPasswordResponse(genericMessage, null, null);

        var existing = await db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && t.UsedAt == null)
            .ToListAsync(ct);
        foreach (var t in existing)
        {
            t.UsedAt = DateTime.UtcNow;
            t.UpdatedAt = DateTime.UtcNow;
        }

        var code = Random.Shared.Next(100000, 999999).ToString();
        var expires = DateTime.UtcNow.AddMinutes(15);
        db.PasswordResetTokens.Add(new PasswordResetToken
        {
            UserId = user.Id,
            Code = code,
            ExpiresAt = expires
        });
        await db.SaveChangesAsync(ct);

        if (emailSender.IsAvailable)
        {
            try
            {
                var safeCode = WebUtility.HtmlEncode(code);
                var plain =
                    $"รหัสรีเซ็ตรหัสผ่าน MedShift ของคุณคือ {code}\n\nรหัสหมดอายุใน 15 นาที\nหากคุณไม่ได้ขอรีเซ็ต สามารถเพิกเฉยอีเมลนี้ได้";
                var html = $"""
                    <p>รหัสรีเซ็ตรหัสผ่าน <strong>MedShift</strong> ของคุณคือ</p>
                    <p style="font-size:28px;font-weight:bold;letter-spacing:4px;">{safeCode}</p>
                    <p>รหัสหมดอายุใน 15 นาที</p>
                    <p style="color:#666;font-size:12px;">หากคุณไม่ได้ขอรีเซ็ต สามารถเพิกเฉยอีเมลนี้ได้</p>
                    """;
                await emailSender.SendAsync(
                    email,
                    "MedShift — รหัสรีเซ็ตรหัสผ่าน",
                    html,
                    plain,
                    ct);
                return new ForgotPasswordResponse(
                    "หากอีเมลนี้มีในระบบ เราได้ส่งรหัสรีเซ็ตไปแล้ว กรุณาตรวจสอบกล่องจดหมาย",
                    null,
                    expires);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to send password reset email to {Email}; falling back to API code", email);
            }
        }

        // Fallback when SMTP is off or send failed — return code for clients/tests.
        logger.LogWarning("Password reset code for {Email}: {Code} (expires {Expires:O}) — SMTP unavailable", email, code, expires);
        return new ForgotPasswordResponse(
            $"{genericMessage} (โหมดทดสอบ: ใช้รหัสที่แสดงบนหน้าจอ)",
            code,
            expires);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var code = request.Code.Trim();
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(code))
            throw new InvalidOperationException("กรุณากรอกอีเมลและรหัสรีเซ็ต");

        if (string.IsNullOrWhiteSpace(request.NewPassword) || request.NewPassword.Length < 6)
            throw new InvalidOperationException("รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร");

        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email, ct)
            ?? throw new InvalidOperationException("รหัสรีเซ็ตไม่ถูกต้องหรือหมดอายุ");

        var token = await db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && t.Code == code && t.UsedAt == null)
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefaultAsync(ct)
            ?? throw new InvalidOperationException("รหัสรีเซ็ตไม่ถูกต้องหรือหมดอายุ");

        if (token.ExpiresAt < DateTime.UtcNow)
            throw new InvalidOperationException("รหัสรีเซ็ตหมดอายุแล้ว กรุณาขอรหัสใหม่");

        user.PasswordHash = passwordHasher.Hash(request.NewPassword);
        user.UpdatedAt = DateTime.UtcNow;
        token.UsedAt = DateTime.UtcNow;
        token.UpdatedAt = DateTime.UtcNow;

        var others = await db.PasswordResetTokens
            .Where(t => t.UserId == user.Id && t.UsedAt == null && t.Id != token.Id)
            .ToListAsync(ct);
        foreach (var t in others)
        {
            t.UsedAt = DateTime.UtcNow;
            t.UpdatedAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync(ct);
    }

    private static StaffProfileDto MapStaff(User user)
    {
        var p = user.StaffProfile!;
        return new StaffProfileDto(
            p.Id, user.Id, user.Email, p.FirstName, p.LastName, p.Phone,
            p.ProfileImageUrl,
            p.Profession.ToString(), p.Specialty, p.LicenseNumber,
            p.ReliabilityScore, p.Rating, p.TotalJobsCompleted, p.TotalEarnings,
            p.BankName, p.BankAccountNumber, p.BankAccountName, p.BankAccountVerified,
            p.Status.ToString(), p.RejectionReason,
            p.CurrentLocationLat, p.CurrentLocationLng,
            p.IsAvailable,
            p.Skills.Select(s => new StaffSkillDto(s.Id, s.Name, s.MinRate, s.MaxRate, s.YearsExperience, s.IsVerified, s.Certification)).ToList(),
            p.NationalId,
            p.LicenseExpiryDate,
            p.LaserCode,
            p.PromptPayId,
            p.Documents?.OrderByDescending(d => d.CreatedAt)
                .Select(d => new StaffDocumentDto(
                    d.Id, d.DocumentType.ToString(), d.FileUrl, d.OriginalFileName,
                    d.VerificationStatus.ToString(), d.RejectionReason, d.CreatedAt))
                .ToList());
    }

    private static OrganizationDto MapOrg(Organization org, OrganizationMember membership) =>
        new(org.Id, org.Name, org.LegalName, org.TaxId, org.Phone, org.Email, org.Address,
            org.Latitude, org.Longitude, org.Status.ToString(), org.RejectionReason, org.ApprovedAt);
}
