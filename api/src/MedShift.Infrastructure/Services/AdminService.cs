using MedShift.Application.DTOs.Admin;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using MedShift.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace MedShift.Infrastructure.Services;

public class AdminService(MedShiftDbContext db, INotificationPublisher notifications) : IAdminService
{
    public async Task<IReadOnlyList<OrganizationDto>> GetPendingOrganizationsAsync(CancellationToken ct = default)
    {
        var orgs = await db.Organizations
            .Where(o => o.Status == OrganizationStatus.Pending)
            .OrderBy(o => o.CreatedAt)
            .ToListAsync(ct);
        return orgs.Select(MapOrg).ToList();
    }

    public async Task ApproveOrganizationAsync(Guid adminUserId, Guid organizationId, CancellationToken ct = default)
    {
        var org = await db.Organizations.FirstOrDefaultAsync(o => o.Id == organizationId, ct)
            ?? throw new InvalidOperationException("ไม่พบองค์กร");
        org.Status = OrganizationStatus.Approved;
        org.ApprovedAt = DateTime.UtcNow;
        org.ApprovedByAdminId = adminUserId;
        org.RejectionReason = null;
        org.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task RejectOrganizationAsync(Guid adminUserId, Guid organizationId, string reason, CancellationToken ct = default)
    {
        var org = await db.Organizations.FirstOrDefaultAsync(o => o.Id == organizationId, ct)
            ?? throw new InvalidOperationException("ไม่พบองค์กร");
        org.Status = OrganizationStatus.Rejected;
        org.RejectionReason = reason;
        org.ApprovedByAdminId = adminUserId;
        org.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task SuspendOrganizationAsync(Guid adminUserId, Guid organizationId, string? reason, CancellationToken ct = default)
    {
        var org = await db.Organizations.FirstOrDefaultAsync(o => o.Id == organizationId, ct)
            ?? throw new InvalidOperationException("ไม่พบองค์กร");
        org.Status = OrganizationStatus.Suspended;
        org.RejectionReason = reason;
        org.ApprovedByAdminId = adminUserId;
        org.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<StaffListItemDto>> GetPendingStaffAsync(CancellationToken ct = default)
    {
        var items = await db.StaffProfiles.Include(s => s.User)
            .Where(s => s.Status == StaffStatus.Pending)
            .OrderBy(s => s.CreatedAt)
            .ToListAsync(ct);
        return items.Select(MapStaffListItem).ToList();
    }

    public async Task ApproveStaffAsync(Guid adminUserId, Guid staffProfileId, CancellationToken ct = default)
    {
        var staff = await db.StaffProfiles.FirstOrDefaultAsync(s => s.Id == staffProfileId, ct)
            ?? throw new InvalidOperationException("ไม่พบบุคลากร");
        staff.Status = StaffStatus.Approved;
        staff.ApprovedAt = DateTime.UtcNow;
        staff.ApprovedByAdminId = adminUserId;
        staff.RejectionReason = null;
        staff.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);

        await notifications.NotifyAsync(
            staff.UserId,
            "บัญชีได้รับการอนุมัติ",
            "Admin อนุมัติบัญชีของคุณแล้ว สามารถรับงานได้",
            NotificationType.System,
            ct: ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task RejectStaffAsync(Guid adminUserId, Guid staffProfileId, string reason, CancellationToken ct = default)
    {
        var staff = await db.StaffProfiles.FirstOrDefaultAsync(s => s.Id == staffProfileId, ct)
            ?? throw new InvalidOperationException("ไม่พบบุคลากร");
        staff.Status = StaffStatus.Rejected;
        staff.RejectionReason = reason;
        staff.ApprovedByAdminId = adminUserId;
        staff.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);

        await notifications.NotifyAsync(
            staff.UserId,
            "บัญชีถูกปฏิเสธ",
            $"Admin ปฏิเสธบัญชีของคุณ: {reason}",
            NotificationType.System,
            ct: ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task SuspendStaffAsync(Guid adminUserId, Guid staffProfileId, string? reason, CancellationToken ct = default)
    {
        var staff = await db.StaffProfiles.FirstOrDefaultAsync(s => s.Id == staffProfileId, ct)
            ?? throw new InvalidOperationException("ไม่พบบุคลากร");
        staff.Status = StaffStatus.Suspended;
        staff.RejectionReason = reason;
        staff.ApprovedByAdminId = adminUserId;
        staff.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<StaffListItemDto>> GetStaffAsync(CancellationToken ct = default)
    {
        var items = await db.StaffProfiles.Include(s => s.User)
            .OrderBy(s => s.FirstName)
            .ToListAsync(ct);
        return items.Select(MapStaffListItem).ToList();
    }

    public async Task SetStaffActiveAsync(Guid staffUserId, bool isActive, CancellationToken ct = default)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == staffUserId && u.Role == UserRole.Staff, ct)
            ?? throw new InvalidOperationException("ไม่พบพนักงาน");
        user.IsActive = isActive;
        user.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<WithdrawalDto>> GetPendingWithdrawalsAsync(CancellationToken ct = default)
    {
        var items = await db.WithdrawalRequests
            .Include(w => w.Wallet).ThenInclude(w => w.StaffProfile)
            .Where(w => w.Status == WithdrawalStatus.Pending)
            .OrderBy(w => w.CreatedAt)
            .ToListAsync(ct);

        return items.Select(w => new WithdrawalDto(
            w.Id,
            w.Wallet.StaffProfileId,
            $"{w.Wallet.StaffProfile.FirstName} {w.Wallet.StaffProfile.LastName}",
            w.Amount, w.BankName, w.BankAccountNumber, w.BankAccountName,
            w.Status.ToString(), w.CreatedAt)).ToList();
    }

    public async Task ApproveWithdrawalAsync(Guid adminUserId, Guid withdrawalId, CancellationToken ct = default)
    {
        var w = await db.WithdrawalRequests
            .Include(x => x.Wallet).ThenInclude(x => x.Transactions)
            .Include(x => x.Wallet).ThenInclude(x => x.StaffProfile)
            .FirstOrDefaultAsync(x => x.Id == withdrawalId, ct)
            ?? throw new InvalidOperationException("ไม่พบคำขอถอนเงิน");

        if (w.Status != WithdrawalStatus.Pending)
            throw new InvalidOperationException("คำขอนี้ถูกดำเนินการแล้ว");

        w.Status = WithdrawalStatus.Approved;
        w.ReviewedByAdminId = adminUserId;
        w.ReviewedAt = DateTime.UtcNow;
        w.UpdatedAt = DateTime.UtcNow;

        var tx = w.Wallet.Transactions
            .Where(t => t.Type == TransactionType.Withdrawal && t.Status == TransactionStatus.Pending)
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefault(t => t.Amount == -w.Amount);
        if (tx != null)
        {
            tx.Status = TransactionStatus.Completed;
            tx.UpdatedAt = DateTime.UtcNow;
        }

        if (w.Wallet.StaffProfile != null)
        {
            await notifications.NotifyAsync(
                w.Wallet.StaffProfile.UserId,
                "อนุมัติการถอนเงินแล้ว",
                $"คำขอถอนเงิน {w.Amount:N2} บาท ได้รับการอนุมัติแล้ว",
                NotificationType.PaymentReceived,
                ct: ct);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task RejectWithdrawalAsync(Guid adminUserId, Guid withdrawalId, string note, CancellationToken ct = default)
    {
        var w = await db.WithdrawalRequests
            .Include(x => x.Wallet).ThenInclude(x => x.Transactions)
            .Include(x => x.Wallet).ThenInclude(x => x.StaffProfile)
            .FirstOrDefaultAsync(x => x.Id == withdrawalId, ct)
            ?? throw new InvalidOperationException("ไม่พบคำขอถอนเงิน");

        if (w.Status != WithdrawalStatus.Pending)
            throw new InvalidOperationException("คำขอนี้ถูกดำเนินการแล้ว");

        // refund balance
        var before = w.Wallet.Balance;
        w.Wallet.Balance += w.Amount;
        w.Wallet.UpdatedAt = DateTime.UtcNow;

        var tx = w.Wallet.Transactions
            .Where(t => t.Type == TransactionType.Withdrawal && t.Status == TransactionStatus.Pending)
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefault(t => t.Amount == -w.Amount);
        if (tx != null)
        {
            tx.Status = TransactionStatus.Cancelled;
            tx.UpdatedAt = DateTime.UtcNow;
        }

        db.WalletTransactions.Add(new WalletTransaction
        {
            WalletId = w.WalletId,
            Type = TransactionType.Refund,
            Amount = w.Amount,
            Status = TransactionStatus.Completed,
            Description = $"คืนเงินจากคำขอถอนที่ถูกปฏิเสธ: {note}",
            BalanceBefore = before,
            BalanceAfter = w.Wallet.Balance
        });

        w.Status = WithdrawalStatus.Rejected;
        w.AdminNote = note;
        w.ReviewedByAdminId = adminUserId;
        w.ReviewedAt = DateTime.UtcNow;
        w.UpdatedAt = DateTime.UtcNow;

        if (w.Wallet.StaffProfile != null)
        {
            await notifications.NotifyAsync(
                w.Wallet.StaffProfile.UserId,
                "คำขอถอนเงินถูกปฏิเสธ",
                $"คำขอถอนเงิน {w.Amount:N2} บาท ถูกปฏิเสธ และคืนเงินเข้ากระเป๋าแล้ว: {note}",
                NotificationType.System,
                ct: ct);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task<AnnouncementDto> CreateAnnouncementAsync(CreateAnnouncementRequest request, CancellationToken ct = default)
    {
        var a = new Announcement
        {
            TitleTh = request.TitleTh,
            TitleEn = request.TitleEn,
            MessageTh = request.MessageTh,
            MessageEn = request.MessageEn,
            Type = request.Type,
            ExpiresAt = request.ExpiresAt,
            IsActive = true
        };
        db.Announcements.Add(a);
        await db.SaveChangesAsync(ct);
        return new AnnouncementDto(a.Id, a.TitleTh, a.MessageTh, a.Type, a.CreatedAt, a.ExpiresAt);
    }

    public async Task<DashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var totalStaff = await db.StaffProfiles.CountAsync(s => s.Status == StaffStatus.Approved, ct);
        var pendingStaff = await db.StaffProfiles.CountAsync(s => s.Status == StaffStatus.Pending, ct);
        var totalClinics = await db.Organizations.CountAsync(o => o.Status == OrganizationStatus.Approved, ct);
        var pendingClinics = await db.Organizations.CountAsync(o => o.Status == OrganizationStatus.Pending, ct);
        var openJobs = await db.Jobs.CountAsync(j => j.Status == JobStatus.Open || j.Status == JobStatus.Applied || j.Status == JobStatus.Selecting, ct);
        var pendingWithdrawals = await db.WithdrawalRequests.CountAsync(w => w.Status == WithdrawalStatus.Pending, ct);
        var totalWallet = await db.Wallets.SumAsync(w => (decimal?)w.Balance, ct) ?? 0;
        return new DashboardDto(totalStaff, pendingStaff, totalClinics, pendingClinics, openJobs, pendingWithdrawals, totalWallet);
    }

    private static StaffListItemDto MapStaffListItem(StaffProfile s) =>
        new(
            s.UserId,
            s.Id,
            s.User.Email,
            s.FirstName + " " + s.LastName,
            s.Profession.ToString(),
            s.User.IsActive,
            s.Status.ToString(),
            s.LicenseNumber,
            s.ReliabilityScore,
            s.CreatedAt);

    private static OrganizationDto MapOrg(Organization org) =>
        new(org.Id, org.Name, org.LegalName, org.TaxId, org.Phone, org.Email, org.Address,
            org.Latitude, org.Longitude, org.Status.ToString(), org.RejectionReason, org.ApprovedAt, org.Rating);
}
