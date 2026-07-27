using System.Text.Json;
using MedShift.Application.DTOs.Clinic;
using MedShift.Application.DTOs.Jobs;
using MedShift.Application.DTOs.Staff;
using MedShift.Application.Interfaces;
using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using MedShift.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace MedShift.Infrastructure.Services;

public class ClinicService(
    MedShiftDbContext db,
    IPasswordHasher passwordHasher,
    INotificationPublisher notifications,
    JobEscrowService escrow) : IClinicService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public async Task EnsureApprovedAsync(Guid userId, CancellationToken ct = default)
    {
        var org = await GetMembershipAsync(userId, ct);
        if (org.Organization.Status != OrganizationStatus.Approved)
            throw new InvalidOperationException("องค์กรของคุณยังไม่ได้รับการอนุมัติจากแอดมิน");
    }

    public async Task<OrganizationDto> GetOrganizationAsync(Guid userId, CancellationToken ct = default)
    {
        var m = await GetMembershipAsync(userId, ct);
        return MapOrg(m.Organization);
    }

    public async Task<OrganizationDto> UpdateOrganizationAsync(Guid userId, UpdateOrganizationRequest request, CancellationToken ct = default)
    {
        var m = await GetMembershipAsync(userId, ct, requireAdmin: true);
        var org = m.Organization;
        org.Name = request.Name.Trim();
        org.LegalName = request.LegalName;
        org.TaxId = request.TaxId;
        org.Phone = request.Phone;
        org.Address = request.Address;
        org.Latitude = request.Latitude;
        org.Longitude = request.Longitude;
        org.DocumentUrl = request.DocumentUrl;
        org.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return MapOrg(org);
    }

    public async Task<PlatformFeeConfigDto> GetPlatformFeeConfigAsync(CancellationToken ct = default)
    {
        var pct = await escrow.GetFeePercentAsync(ct);
        return new PlatformFeeConfigDto(
            pct,
            escrow.IsSynchronousGateway
                ? "คลินิกจ่ายค่าจ้างพนักงาน + ค่าธรรมเนียมแพลตฟอร์มตอนประกาศงาน (จำลอง payment gateway)"
                : "คลินิกสแกน PromptPay QR (GB Prime Pay) จ่ายค่าจ้าง + ค่าธรรมเนียมตอนประกาศงาน");
    }

    public async Task<JobPaymentPreviewDto> PreviewJobPaymentAsync(
        Guid userId,
        decimal hourlyRate,
        DateTime startTime,
        DateTime endTime,
        CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        if (endTime <= startTime)
            throw new InvalidOperationException("เวลาสิ้นสุดต้องหลังเวลาเริ่ม");
        if (hourlyRate <= 0)
            throw new InvalidOperationException("ค่าจ้างต้องมากกว่า 0");

        var hours = (endTime - startTime).TotalHours;
        var staffPay = Math.Round(hourlyRate * (decimal)hours, 2);
        var feePercent = await escrow.GetFeePercentAsync(ct);
        var (_, fee, total) = JobEscrowService.Calculate(staffPay, feePercent);
        return new JobPaymentPreviewDto(staffPay, feePercent, fee, total, hours);
    }

    public async Task<JobDto> CreateJobAsync(Guid userId, CreateJobRequest request, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var m = await GetMembershipAsync(userId, ct);
        var org = m.Organization;

        if (!request.ConfirmGatewayPayment)
            throw new InvalidOperationException("กรุณายืนยันการชำระเงินผ่าน payment gateway ก่อนประกาศงาน");

        if (request.EndTime <= request.StartTime)
            throw new InvalidOperationException("เวลาสิ้นสุดต้องหลังเวลาเริ่ม");

        if (request.HourlyRate <= 0)
            throw new InvalidOperationException("ค่าจ้างต้องมากกว่า 0");

        var hours = (decimal)(request.EndTime - request.StartTime).TotalHours;
        var useQr = !escrow.IsSynchronousGateway;
        var job = new Job
        {
            OrganizationId = org.Id,
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            LocationName = request.LocationName?.Trim() ?? org.Name,
            Address = request.Address?.Trim() ?? org.Address,
            Latitude = request.Latitude ?? org.Latitude,
            Longitude = request.Longitude ?? org.Longitude,
            StartTime = DateTime.SpecifyKind(request.StartTime, DateTimeKind.Utc),
            EndTime = DateTime.SpecifyKind(request.EndTime, DateTimeKind.Utc),
            HourlyRate = request.HourlyRate,
            TotalPay = Math.Round(request.HourlyRate * hours, 2),
            RequiredSkillsJson = JsonSerializer.Serialize(request.RequiredSkills ?? [], JsonOptions),
            RequiredCertification = request.RequiredCertification,
            MinReliabilityScore = request.MinReliabilityScore,
            Status = useQr ? JobStatus.PendingPayment : JobStatus.Open
        };

        db.Jobs.Add(job);
        await db.SaveChangesAsync(ct);

        string? qrBase64 = null;
        JobPayment payment;
        if (useQr)
        {
            var (pending, qr) = await escrow.CreatePendingQrPaymentAsync(job, org.Id, ct);
            payment = pending;
            if (qr.QrPngBytes is { Length: > 0 })
                qrBase64 = Convert.ToBase64String(qr.QrPngBytes);
        }
        else
        {
            payment = await escrow.ChargeAndHoldAsync(job, org.Id, ct);
        }

        await db.SaveChangesAsync(ct);

        job.Organization = org;
        job.Payment = payment;
        return StaffService.MapJob(job, qrBase64);
    }

    public async Task<JobPaymentStatusDto> GetJobPaymentStatusAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var job = await GetOrgJobAsync(userId, jobId, ct);
        var payment = job.Payment
            ?? await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบข้อมูลการชำระเงิน");

        if (payment.Status == JobPaymentStatus.Pending)
        {
            await escrow.SyncPaymentStatusFromGatewayAsync(payment, ct);
            await db.SaveChangesAsync(ct);
            await db.Entry(job).ReloadAsync(ct);
            await db.Entry(payment).ReloadAsync(ct);
        }

        return new JobPaymentStatusDto(
            job.Id,
            job.Status.ToString(),
            payment.Status.ToString(),
            payment.TotalCharged,
            payment.MerchantReference,
            payment.GbpReferenceNo,
            payment.Status is JobPaymentStatus.Held or JobPaymentStatus.Released);
    }

    public async Task<JobDto> UpdateJobAsync(Guid userId, Guid jobId, UpdateJobRequest request, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await GetOrgJobAsync(userId, jobId, ct);
        if (job.Status is JobStatus.Completed or JobStatus.Cancelled or JobStatus.InProgress or JobStatus.CheckedIn)
            throw new InvalidOperationException("ไม่สามารถแก้ไขงานในสถานะนี้ได้");

        var hours = (decimal)(request.EndTime - request.StartTime).TotalHours;
        var newTotal = Math.Round(request.HourlyRate * hours, 2);
        var payment = await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct);
        if (payment != null && payment.Status == JobPaymentStatus.Held && newTotal != job.TotalPay)
            throw new InvalidOperationException("ไม่สามารถเปลี่ยนค่าจ้างหลังชำระเงินแล้ว — ปิดงานแล้วสร้างใหม่หากต้องการเปลี่ยนยอด");

        job.Title = request.Title.Trim();
        job.Description = request.Description.Trim();
        job.LocationName = request.LocationName;
        job.Address = request.Address;
        job.Latitude = request.Latitude;
        job.Longitude = request.Longitude;
        job.StartTime = DateTime.SpecifyKind(request.StartTime, DateTimeKind.Utc);
        job.EndTime = DateTime.SpecifyKind(request.EndTime, DateTimeKind.Utc);
        job.HourlyRate = request.HourlyRate;
        job.TotalPay = Math.Round(request.HourlyRate * hours, 2);
        job.RequiredSkillsJson = JsonSerializer.Serialize(request.RequiredSkills ?? [], JsonOptions);
        job.RequiredCertification = request.RequiredCertification;
        job.MinReliabilityScore = request.MinReliabilityScore;
        job.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return StaffService.MapJob(job);
    }

    public async Task CloseJobAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var job = await GetOrgJobAsync(userId, jobId, ct);
        if (job.Status is JobStatus.Completed or JobStatus.InProgress)
            throw new InvalidOperationException("ไม่สามารถปิดงานในสถานะนี้ได้");
        job.Status = JobStatus.Cancelled;
        job.UpdatedAt = DateTime.UtcNow;
        await escrow.RefundStaffEscrowAsync(job, $"ปิดประกาศงาน: {job.Title}", ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<JobDto>> GetJobsAsync(Guid userId, CancellationToken ct = default)
    {
        var m = await GetMembershipAsync(userId, ct);
        var jobs = await db.Jobs.Include(j => j.Organization).Include(j => j.Review).Include(j => j.ClinicReview).Include(j => j.Payment)
            .Where(j => j.OrganizationId == m.OrganizationId)
            .OrderByDescending(j => j.StartTime)
            .ToListAsync(ct);
        return jobs.Select(j => StaffService.MapJob(j)).ToList();
    }

    public async Task<IReadOnlyList<ApplicantDto>> GetApplicantsAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        await GetOrgJobAsync(userId, jobId, ct);
        var apps = await db.JobApplications
            .Include(a => a.StaffProfile)
            .Where(a => a.JobId == jobId)
            .OrderBy(a => a.CreatedAt)
            .ToListAsync(ct);

        return apps.Select(a => new ApplicantDto(
            a.Id, a.StaffProfileId,
            $"{a.StaffProfile.FirstName} {a.StaffProfile.LastName}",
            a.StaffProfile.Profession.ToString(),
            a.StaffProfile.LicenseNumber,
            a.StaffProfile.ReliabilityScore,
            a.StaffProfile.Rating,
            a.Status.ToString(),
            a.WaitlistPosition,
            a.CreatedAt)).ToList();
    }

    public async Task HireApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await db.Jobs.Include(j => j.Applications).Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        var m = await GetMembershipAsync(userId, ct);
        if (job.OrganizationId != m.OrganizationId)
            throw new UnauthorizedAccessException();

        if (job.HiredStaffProfileId.HasValue)
            throw new InvalidOperationException("งานนี้มีผู้รับจ้างแล้ว ใช้ waitlist สำหรับคนอื่น");

        var app = job.Applications.FirstOrDefault(a => a.StaffProfileId == staffProfileId)
            ?? throw new InvalidOperationException("ไม่พบผู้สมัคร");

        if (app.Status is ApplicationStatus.Withdrawn or ApplicationStatus.Rejected)
            throw new InvalidOperationException("ไม่สามารถจ้างผู้สมัครในสถานะนี้ได้");

        var staff = await db.StaffProfiles.FirstAsync(s => s.Id == staffProfileId, ct);
        if (staff.Status != StaffStatus.Approved)
            throw new InvalidOperationException("บุคลากรคนนี้ยังไม่ได้รับอนุมัติจาก Admin");

        app.Status = ApplicationStatus.Hired;
        app.WaitlistPosition = null;
        job.HiredStaffProfileId = staffProfileId;
        job.Status = JobStatus.Confirmed;
        job.UpdatedAt = DateTime.UtcNow;

        await notifications.NotifyAsync(
            staff.UserId,
            "คุณได้รับงานแล้ว",
            $"คลินิกยืนยันจ้างคุณสำหรับงาน \"{job.Title}\"",
            NotificationType.ApplicationUpdate,
            job.Id,
            ct);

        await db.SaveChangesAsync(ct);
    }

    public async Task WaitlistApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await GetOrgJobAsync(userId, jobId, ct);
        var apps = await db.JobApplications.Where(a => a.JobId == jobId).ToListAsync(ct);
        var app = apps.FirstOrDefault(a => a.StaffProfileId == staffProfileId)
            ?? throw new InvalidOperationException("ไม่พบผู้สมัคร");

        var waitlistCount = apps.Count(a => a.Status == ApplicationStatus.Waitlist);
        if (waitlistCount >= 10)
            throw new InvalidOperationException("รายชื่อสำรองเต็มแล้ว");

        app.Status = ApplicationStatus.Waitlist;
        app.WaitlistPosition = waitlistCount + 1;
        app.UpdatedAt = DateTime.UtcNow;
        if (job.Status == JobStatus.Open || job.Status == JobStatus.Applied)
            job.Status = JobStatus.Selecting;

        var staff = await db.StaffProfiles.FirstAsync(s => s.Id == staffProfileId, ct);
        await notifications.NotifyAsync(
            staff.UserId,
            "อยู่ในรายชื่อสำรอง",
            $"คุณอยู่ในรายชื่อสำรองลำดับที่ {app.WaitlistPosition} สำหรับงาน \"{job.Title}\"",
            NotificationType.ApplicationUpdate,
            job.Id,
            ct);

        await db.SaveChangesAsync(ct);
    }

    public async Task RejectApplicantAsync(Guid userId, Guid jobId, Guid staffProfileId, CancellationToken ct = default)
    {
        var job = await GetOrgJobAsync(userId, jobId, ct);
        var app = await db.JobApplications.FirstOrDefaultAsync(a => a.JobId == jobId && a.StaffProfileId == staffProfileId, ct)
            ?? throw new InvalidOperationException("ไม่พบผู้สมัคร");
        if (app.Status == ApplicationStatus.Hired)
            throw new InvalidOperationException("ไม่สามารถปฏิเสธผู้ที่จ้างแล้ว");
        app.Status = ApplicationStatus.Rejected;
        app.WaitlistPosition = null;
        app.UpdatedAt = DateTime.UtcNow;

        var staff = await db.StaffProfiles.FirstAsync(s => s.Id == staffProfileId, ct);
        await notifications.NotifyAsync(
            staff.UserId,
            "ไม่ได้รับการคัดเลือก",
            $"คลินิกไม่ได้เลือกคุณสำหรับงาน \"{job.Title}\"",
            NotificationType.ApplicationUpdate,
            job.Id,
            ct);

        await db.SaveChangesAsync(ct);
    }

    public async Task CompleteJobAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await GetOrgJobAsync(userId, jobId, ct);
        if (job.HiredStaffProfileId == null)
            throw new InvalidOperationException("ยังไม่มีผู้รับจ้าง");
        if (job.Status is not (JobStatus.CheckedIn or JobStatus.InProgress or JobStatus.Confirmed))
            throw new InvalidOperationException("สถานะงานยังไม่พร้อมปิดงาน");

        var alreadyPaid = await db.WalletTransactions.AnyAsync(
            t => t.JobId == jobId && t.Type == TransactionType.Payment && t.Status == TransactionStatus.Completed,
            ct);
        if (alreadyPaid || job.Status == JobStatus.Completed)
            throw new InvalidOperationException("งานนี้ปิดและจ่ายค่าจ้างไปแล้ว");

        var staff = await db.StaffProfiles.Include(s => s.Wallet)
            .FirstAsync(s => s.Id == job.HiredStaffProfileId, ct);

        var wallet = staff.Wallet ?? throw new InvalidOperationException("ไม่พบ wallet");
        await escrow.ReleaseToStaffAsync(job, staff, wallet, ct);

        job.Status = JobStatus.Completed;
        job.UpdatedAt = DateTime.UtcNow;

        var paidAmount = (await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct))?.StaffAmount
            ?? job.TotalPay;

        await notifications.NotifyAsync(
            staff.UserId,
            "ได้รับค่าตอบแทน",
            $"คุณได้รับ {paidAmount:N2} บาท จากงาน \"{job.Title}\"",
            NotificationType.PaymentReceived,
            job.Id,
            ct);

        await db.SaveChangesAsync(ct);
    }

    public async Task MarkNoShowAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await db.Jobs
            .Include(j => j.Applications)
            .Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        var membership = await GetMembershipAsync(userId, ct);
        if (job.OrganizationId != membership.OrganizationId)
            throw new UnauthorizedAccessException("ไม่มีสิทธิ์จัดการงานนี้");

        if (job.HiredStaffProfileId == null)
            throw new InvalidOperationException("ยังไม่มีผู้รับจ้าง");

        if (job.Status is not (JobStatus.Confirmed or JobStatus.CheckedIn or JobStatus.InProgress))
            throw new InvalidOperationException("สถานะงานยังไม่สามารถบันทึก No-show ได้");

        var staff = await db.StaffProfiles.Include(s => s.Wallet)
            .FirstAsync(s => s.Id == job.HiredStaffProfileId, ct);

        var app = job.Applications.FirstOrDefault(a =>
                a.StaffProfileId == staff.Id && a.Status == ApplicationStatus.Hired)
            ?? throw new InvalidOperationException("ไม่พบการจ้างงาน");

        const decimal penalty = 100m;
        const double reliabilityPenalty = 15;

        app.Status = ApplicationStatus.NoShow;
        app.CancelReason = "No-show";
        app.PenaltyAmount = penalty;
        app.UpdatedAt = DateTime.UtcNow;

        staff.ReliabilityScore = Math.Max(0, staff.ReliabilityScore - reliabilityPenalty);
        staff.UpdatedAt = DateTime.UtcNow;

        var wallet = staff.Wallet;
        if (wallet != null)
        {
            var before = wallet.Balance;
            wallet.Balance -= penalty;
            wallet.UpdatedAt = DateTime.UtcNow;
            db.WalletTransactions.Add(new WalletTransaction
            {
                WalletId = wallet.Id,
                JobId = job.Id,
                Type = TransactionType.Penalty,
                Amount = -penalty,
                Status = TransactionStatus.Completed,
                Description = $"ค่าปรับ No-show: {job.Title}",
                BalanceBefore = before,
                BalanceAfter = wallet.Balance
            });
        }

        job.HiredStaffProfileId = null;
        job.UpdatedAt = DateTime.UtcNow;

        await notifications.NotifyAsync(
            staff.UserId,
            "บันทึกว่าไม่มาทำงาน (No-show)",
            $"งาน \"{job.Title}\" ถูกบันทึกเป็น No-show — คะแนนความน่าเชื่อถือลด {reliabilityPenalty:0} และมีค่าปรับ {penalty:N0} บาท",
            NotificationType.JobCancelled,
            job.Id,
            ct);

        var waitlist = job.Applications
            .Where(a => a.Status == ApplicationStatus.Waitlist)
            .OrderBy(a => a.WaitlistPosition)
            .ThenBy(a => a.CreatedAt)
            .ToList();

        JobApplication? promoted = null;
        foreach (var candidate in waitlist)
        {
            var candidateStaff = await db.StaffProfiles.FirstAsync(s => s.Id == candidate.StaffProfileId, ct);
            if (candidateStaff.Status != StaffStatus.Approved) continue;
            promoted = candidate;
            break;
        }

        if (promoted != null)
        {
            promoted.Status = ApplicationStatus.Hired;
            promoted.WaitlistPosition = null;
            promoted.UpdatedAt = DateTime.UtcNow;
            job.HiredStaffProfileId = promoted.StaffProfileId;
            job.Status = JobStatus.Confirmed;

            var remaining = waitlist.Where(a => a.Id != promoted.Id).ToList();
            for (var i = 0; i < remaining.Count; i++)
            {
                remaining[i].WaitlistPosition = i + 1;
                remaining[i].UpdatedAt = DateTime.UtcNow;
            }

            var promotedStaff = await db.StaffProfiles.FirstAsync(s => s.Id == promoted.StaffProfileId, ct);
            await notifications.NotifyAsync(
                promotedStaff.UserId,
                "ได้งานจากรายชื่อสำรอง",
                $"คุณถูกเลื่อนจาก waitlist สำหรับงาน \"{job.Title}\"",
                NotificationType.WaitlistPromoted,
                job.Id,
                ct);
        }
        else
        {
            job.Status = JobStatus.Cancelled;
            await escrow.RefundStaffEscrowAsync(job, $"No-show — ยกเลิกงาน: {job.Title}", ct);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task RateJobAsync(Guid userId, Guid jobId, RateJobRequest request, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await db.Jobs
            .Include(j => j.Review)
            .Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        var membership = await GetMembershipAsync(userId, ct);
        if (job.OrganizationId != membership.OrganizationId)
            throw new UnauthorizedAccessException("ไม่มีสิทธิ์จัดการงานนี้");

        if (job.Status != JobStatus.Completed)
            throw new InvalidOperationException("ให้คะแนนได้เฉพาะงานที่ปิดและจ่ายเงินแล้ว");

        if (job.HiredStaffProfileId == null)
            throw new InvalidOperationException("ไม่พบผู้รับจ้างในงานนี้");

        if (job.Review != null)
            throw new InvalidOperationException("งานนี้ถูกให้คะแนนแล้ว");

        if (request.Rating is < 1 or > 5)
            throw new InvalidOperationException("คะแนนต้องอยู่ระหว่าง 1–5");

        var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        if (comment is { Length: > 1000 })
            throw new InvalidOperationException("ความคิดเห็นยาวเกินไป");

        var staff = await db.StaffProfiles.FirstAsync(s => s.Id == job.HiredStaffProfileId, ct);

        db.JobReviews.Add(new JobReview
        {
            JobId = job.Id,
            StaffProfileId = staff.Id,
            OrganizationId = job.OrganizationId,
            RatedByUserId = userId,
            Rating = request.Rating,
            Comment = comment
        });

        var avg = await db.JobReviews
            .Where(r => r.StaffProfileId == staff.Id)
            .Select(r => (double?)r.Rating)
            .AverageAsync(ct);
        // Include the new review not yet saved — compute manually
        var priorCount = await db.JobReviews.CountAsync(r => r.StaffProfileId == staff.Id, ct);
        var newAvg = priorCount == 0
            ? request.Rating
            : ((avg ?? 0) * priorCount + request.Rating) / (priorCount + 1);
        staff.Rating = Math.Round(newAvg, 2);
        staff.UpdatedAt = DateTime.UtcNow;

        await notifications.NotifyAsync(
            staff.UserId,
            "ได้รับการรีวิวจากคลินิก",
            $"งาน \"{job.Title}\" ได้คะแนน {request.Rating}/5" +
            (comment != null ? $" — {comment}" : ""),
            NotificationType.ApplicationUpdate,
            job.Id,
            ct);

        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<JobIssueDto>> GetJobIssuesAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await GetOrgJobAsync(userId, jobId, ct);

        var issues = await db.JobIssues
            .Include(i => i.StaffProfile)
            .Where(i => i.JobId == job.Id)
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync(ct);

        return issues.Select(i => new JobIssueDto(
            i.Id, i.JobId, i.StaffProfileId,
            $"{i.StaffProfile.FirstName} {i.StaffProfile.LastName}",
            i.Category.ToString(), i.Description, i.Status.ToString(),
            i.CreatedAt, i.ResolvedAt)).ToList();
    }

    public async Task ResolveJobIssueAsync(Guid userId, Guid jobId, Guid issueId, CancellationToken ct = default)
    {
        await EnsureApprovedAsync(userId, ct);
        var job = await GetOrgJobAsync(userId, jobId, ct);
        var issue = await db.JobIssues.FirstOrDefaultAsync(i => i.Id == issueId && i.JobId == job.Id, ct)
            ?? throw new InvalidOperationException("ไม่พบรายงานปัญหา");

        if (issue.Status == JobIssueStatus.Resolved)
            throw new InvalidOperationException("รายงานนี้ถูกปิดแล้ว");

        issue.Status = JobIssueStatus.Resolved;
        issue.ResolvedAt = DateTime.UtcNow;
        issue.ResolvedByUserId = userId;
        issue.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<OrgMemberDto>> GetMembersAsync(Guid userId, CancellationToken ct = default)
    {
        var m = await GetMembershipAsync(userId, ct, requireAdmin: true);
        var members = await db.OrganizationMembers.Include(x => x.User)
            .Where(x => x.OrganizationId == m.OrganizationId)
            .ToListAsync(ct);
        return members.Select(x => new OrgMemberDto(x.UserId, x.Id, x.User.Email, x.Role.ToString(), x.IsActive)).ToList();
    }

    public async Task<OrgMemberDto> CreateMemberAsync(Guid userId, CreateOrgMemberRequest request, CancellationToken ct = default)
    {
        var m = await GetMembershipAsync(userId, ct, requireAdmin: true);
        var email = request.Email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(u => u.Email == email, ct))
            throw new InvalidOperationException("อีเมลนี้ถูกใช้งานแล้ว");

        if (!Enum.TryParse<OrganizationMemberRole>(request.Role, true, out var role) || role == OrganizationMemberRole.Owner)
            role = OrganizationMemberRole.Member;

        var user = new User
        {
            Email = email,
            PasswordHash = passwordHasher.Hash(request.Password),
            Role = UserRole.Clinic
        };
        var membership = new OrganizationMember
        {
            User = user,
            OrganizationId = m.OrganizationId,
            Role = role
        };
        db.Users.Add(user);
        db.OrganizationMembers.Add(membership);
        await db.SaveChangesAsync(ct);
        return new OrgMemberDto(user.Id, membership.Id, user.Email, membership.Role.ToString(), membership.IsActive);
    }

    private async Task<OrganizationMember> GetMembershipAsync(Guid userId, CancellationToken ct, bool requireAdmin = false)
    {
        var m = await db.OrganizationMembers
            .Include(x => x.Organization)
            .Include(x => x.User)
            .FirstOrDefaultAsync(x => x.UserId == userId && x.IsActive, ct)
            ?? throw new InvalidOperationException("ไม่พบสมาชิกองค์กร");

        if (requireAdmin && m.Role is not (OrganizationMemberRole.Owner or OrganizationMemberRole.Admin))
            throw new UnauthorizedAccessException("ต้องเป็นแอดมินของคลินิก");

        return m;
    }

    private async Task<Job> GetOrgJobAsync(Guid userId, Guid jobId, CancellationToken ct)
    {
        var m = await GetMembershipAsync(userId, ct);
        var job = await db.Jobs.Include(j => j.Organization).Include(j => j.Review).Include(j => j.ClinicReview).Include(j => j.Payment)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");
        if (job.OrganizationId != m.OrganizationId)
            throw new UnauthorizedAccessException();
        return job;
    }

    private static OrganizationDto MapOrg(Organization org) =>
        new(org.Id, org.Name, org.LegalName, org.TaxId, org.Phone, org.Email, org.Address,
            org.Latitude, org.Longitude, org.Status.ToString(), org.RejectionReason, org.ApprovedAt, org.Rating);

    public async Task RegisterDeviceAsync(Guid userId, string token, string? platform, CancellationToken ct = default)
    {
        await GetMembershipAsync(userId, ct);
        var existing = await db.DeviceTokens.FirstOrDefaultAsync(d => d.UserId == userId && d.FirebaseDeviceToken == token, ct);
        if (existing != null)
        {
            existing.LastSeenAt = DateTime.UtcNow;
            existing.Platform = platform;
        }
        else
        {
            db.DeviceTokens.Add(new DeviceToken
            {
                UserId = userId,
                FirebaseDeviceToken = token,
                Platform = platform
            });
        }
        await db.SaveChangesAsync(ct);
    }

    public async Task TestPushAsync(Guid userId, CancellationToken ct = default)
    {
        await GetMembershipAsync(userId, ct);
        await notifications.NotifyAsync(
            userId,
            "ทดสอบ Push Notification (Clinic)",
            "MedShift ส่งข้อความทดสอบนี้สำเร็จ (หรือ dry-run ถ้ายังไม่ตั้ง Firebase Admin credentials)",
            NotificationType.System,
            null,
            ct);
        await db.SaveChangesAsync(ct);
    }
}
