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

public class StaffService(MedShiftDbContext db, INotificationPublisher notifications, JobEscrowService escrow, IFileStorage fileStorage) : IStaffService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    public async Task<StaffProfileDto> GetProfileAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        return MapProfile(user);
    }

    public async Task<StaffProfileDto> UpdateProfileImageAsync(Guid userId, string profileImageUrl, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        var p = user.StaffProfile!;
        p.ProfileImageUrl = profileImageUrl;
        p.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return MapProfile(user);
    }

    public async Task<StaffProfileDto> UpdateProfileAsync(Guid userId, UpdateStaffProfileRequest request, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        var p = user.StaffProfile!;
        p.FirstName = request.FirstName.Trim();
        p.LastName = request.LastName.Trim();
        p.Phone = request.Phone;
        p.Specialty = request.Specialty;
        p.LicenseNumber = request.LicenseNumber;
        p.LicenseExpiryDate = request.LicenseExpiryDate;
        p.NationalId = request.NationalId;
        p.LaserCode = request.LaserCode;
        p.YearsExperience = request.YearsExperience;
        p.BankName = request.BankName;
        p.BankAccountNumber = request.BankAccountNumber;
        p.BankAccountName = request.BankAccountName;
        p.PromptPayId = request.PromptPayId;
        ApplyBankVerification(p, request.FirstName, request.LastName, request.BankAccountVerified);
        if (request.CurrentLocationLat.HasValue) p.CurrentLocationLat = request.CurrentLocationLat;
        if (request.CurrentLocationLng.HasValue) p.CurrentLocationLng = request.CurrentLocationLng;
        if (request.IsAvailable.HasValue) p.IsAvailable = request.IsAvailable.Value;
        p.UpdatedAt = DateTime.UtcNow;

        if (request.Skills != null)
        {
            var existingSkills = await db.StaffSkills
                .Where(s => s.StaffProfileId == p.Id)
                .ToListAsync(ct);
            db.StaffSkills.RemoveRange(existingSkills);

            foreach (var s in request.Skills)
            {
                db.StaffSkills.Add(new StaffSkill
                {
                    StaffProfileId = p.Id,
                    Name = s.Name,
                    MinRate = s.MinRate,
                    // Staff enters minimum desired rate only; keep MaxRate in sync for schema compat.
                    MaxRate = s.MinRate > 0 ? s.MinRate : s.MaxRate,
                    YearsExperience = s.YearsExperience,
                    Certification = s.Certification
                });
            }
        }

        await db.SaveChangesAsync(ct);

        // Reload skills for mapping
        await db.Entry(p).Collection(x => x.Skills).LoadAsync(ct);
        return MapProfile(user);
    }

    public async Task<IReadOnlyList<JobDto>> GetOpenJobsAsync(CancellationToken ct = default)
    {
        var jobs = await db.Jobs
            .Include(j => j.Organization)
            .Include(j => j.Payment)
            .Include(j => j.Review)
            .Include(j => j.ClinicReview)
            .Where(j => j.Status == JobStatus.Open || j.Status == JobStatus.Applied || j.Status == JobStatus.Selecting)
            .Where(j => j.Status != JobStatus.PendingPayment)
            .Where(j => j.Organization.Status == OrganizationStatus.Approved)
            .OrderBy(j => j.StartTime)
            .ToListAsync(ct);
        return jobs.Select(j => MapJob(j)).ToList();
    }

    public async Task<JobDto?> GetJobAsync(Guid jobId, CancellationToken ct = default)
    {
        var job = await db.Jobs.Include(j => j.Organization).Include(j => j.Payment).Include(j => j.Review).Include(j => j.ClinicReview)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct);
        return job == null ? null : MapJob(job);
    }

    public async Task ApplyForJobAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        var staff = user.StaffProfile!;
        EnsureStaffApproved(staff);
        EnsureLicenseValid(staff);

        if (!staff.IsAvailable)
            throw new InvalidOperationException("คุณปิดรับงานอยู่ กรุณาเปิด «พร้อมรับงาน» ในโปรไฟล์ก่อนสมัคร");

        var walletBalance = await db.Wallets
            .Where(w => w.StaffProfileId == staff.Id)
            .Select(w => (decimal?)w.Balance)
            .FirstOrDefaultAsync(ct);
        if (walletBalance is < 0)
            throw new InvalidOperationException("บัญชียอดติดลบ กรุณาชำระเงินเพื่อปลดล็อคก่อนสมัครงาน");

        var job = await db.Jobs.Include(j => j.Applications).Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.Organization.Status != OrganizationStatus.Approved)
            throw new InvalidOperationException("องค์กรนี้ยังไม่พร้อมรับสมัคร");

        if (job.Status is JobStatus.Confirmed or JobStatus.CheckedIn or JobStatus.InProgress or JobStatus.Completed or JobStatus.Cancelled or JobStatus.PendingPayment)
            throw new InvalidOperationException("งานนี้ไม่เปิดรับสมัครแล้ว");

        if (staff.ReliabilityScore < job.MinReliabilityScore)
            throw new InvalidOperationException("คะแนนความน่าเชื่อถือไม่ถึงเกณฑ์ของงาน");

        if (job.Applications.Any(a => a.StaffProfileId == staff.Id && a.Status is not (ApplicationStatus.Withdrawn or ApplicationStatus.Rejected)))
            throw new InvalidOperationException("คุณสมัครงานนี้แล้ว");

        await EnsureNoConflictAsync(staff.Id, job, ct);

        var waitlistCount = job.Applications.Count(a => a.Status == ApplicationStatus.Waitlist);
        var hasHired = job.HiredStaffProfileId.HasValue || job.Applications.Any(a => a.Status == ApplicationStatus.Hired);

        ApplicationStatus status;
        int? waitlistPos = null;
        if (hasHired)
        {
            if (waitlistCount >= 10)
                throw new InvalidOperationException("รายชื่อสำรองเต็มแล้ว");
            status = ApplicationStatus.Waitlist;
            waitlistPos = waitlistCount + 1;
        }
        else
        {
            status = ApplicationStatus.Pending;
            job.Status = job.Status == JobStatus.Open ? JobStatus.Applied : job.Status;
        }

        db.JobApplications.Add(new JobApplication
        {
            JobId = job.Id,
            StaffProfileId = staff.Id,
            Status = status,
            WaitlistPosition = waitlistPos
        });

        await AddNotificationAsync(user.Id, "สมัครงานสำเร็จ", $"คุณสมัครงาน \"{job.Title}\" แล้ว", NotificationType.ApplicationUpdate, job.Id, ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task WithdrawApplicationAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var app = await db.JobApplications.FirstOrDefaultAsync(a => a.JobId == jobId && a.StaffProfileId == staff.Id, ct)
            ?? throw new InvalidOperationException("ไม่พบการสมัคร");

        if (app.Status is not (ApplicationStatus.Pending or ApplicationStatus.Waitlist))
            throw new InvalidOperationException("ไม่สามารถถอนการสมัครในสถานะนี้ได้");

        app.Status = ApplicationStatus.Withdrawn;
        app.WaitlistPosition = null;
        app.UpdatedAt = DateTime.UtcNow;
        await ReorderWaitlistAsync(jobId, ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task CancelHiredJobAsync(Guid userId, Guid jobId, string? reason, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        var staff = user.StaffProfile!;
        var job = await db.Jobs.Include(j => j.Applications).FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        var app = job.Applications.FirstOrDefault(a => a.StaffProfileId == staff.Id && a.Status == ApplicationStatus.Hired)
            ?? throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status is not (JobStatus.Confirmed or JobStatus.Selecting or JobStatus.Applied))
            throw new InvalidOperationException("ไม่สามารถยกเลิกงานในสถานะนี้ได้");

        var hoursToStart = (job.StartTime - DateTime.UtcNow).TotalHours;
        var penalty = hoursToStart switch
        {
            >= 48 => 0m,
            >= 24 => 50m,
            _ => 100m
        };

        app.Status = ApplicationStatus.Withdrawn;
        app.CancelReason = reason;
        app.PenaltyAmount = penalty;
        job.HiredStaffProfileId = null;

        if (penalty > 0)
            await ApplyPenaltyAsync(staff, job.Id, penalty, $"ค่าปรับยกเลิกงาน: {job.Title}", ct);

        var next = job.Applications
            .Where(a => a.Status == ApplicationStatus.Waitlist)
            .OrderBy(a => a.WaitlistPosition)
            .ToList();

        JobApplication? promoted = null;
        foreach (var candidate in next)
        {
            var candidateStaff = await db.StaffProfiles.FirstAsync(s => s.Id == candidate.StaffProfileId, ct);
            if (candidateStaff.Status != StaffStatus.Approved)
                continue;
            promoted = candidate;
            break;
        }

        if (promoted != null)
        {
            promoted.Status = ApplicationStatus.Hired;
            promoted.WaitlistPosition = null;
            job.HiredStaffProfileId = promoted.StaffProfileId;
            job.Status = JobStatus.Confirmed;
            var promotedStaff = await db.StaffProfiles.FirstAsync(s => s.Id == promoted.StaffProfileId, ct);
            await AddNotificationAsync(promotedStaff.UserId, "ได้งานจากรายชื่อสำรอง",
                $"คุณถูกเลื่อนจาก waitlist สำหรับงาน \"{job.Title}\"", NotificationType.WaitlistPromoted, job.Id, ct);
            await ReorderWaitlistAsync(job.Id, ct);
        }
        else
        {
            job.Status = JobStatus.Open;
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<JobDto>> GetMyJobsAsync(Guid userId, string filter, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var query = db.JobApplications.Include(a => a.Job).ThenInclude(j => j.Organization)
            .Include(a => a.Job).ThenInclude(j => j.Payment)
            .Include(a => a.Job).ThenInclude(j => j.Review)
            .Include(a => a.Job).ThenInclude(j => j.ClinicReview)
            .Where(a => a.StaffProfileId == staff.Id);

        query = filter.ToLowerInvariant() switch
        {
            "hired" => query.Where(a => a.Status == ApplicationStatus.Hired),
            "waitlist" => query.Where(a => a.Status == ApplicationStatus.Waitlist),
            "pending" => query.Where(a => a.Status == ApplicationStatus.Pending),
            _ => query.Where(a =>
                a.Status == ApplicationStatus.Hired
                || a.Status == ApplicationStatus.Waitlist
                || a.Status == ApplicationStatus.Pending)
        };

        var apps = await query.OrderBy(a => a.Job.StartTime).ToListAsync(ct);
        return apps.Select(a => MapJob(a.Job)).ToList();
    }

    public async Task<WalletDto> GetWalletAsync(Guid userId, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var wallet = await db.Wallets.Include(w => w.Transactions)
            .FirstAsync(w => w.StaffProfileId == staff.Id, ct);
        return new WalletDto(
            wallet.Balance,
            wallet.Transactions.OrderByDescending(t => t.CreatedAt)
                .Select(t => new TransactionDto(t.Id, t.Type.ToString(), t.Amount, t.Status.ToString(), t.Description, t.BalanceBefore, t.BalanceAfter, t.CreatedAt, t.JobId))
                .ToList());
    }

    public async Task RequestWithdrawAsync(Guid userId, WithdrawRequest request, CancellationToken ct = default)
    {
        if (request.Amount <= 0)
            throw new InvalidOperationException("จำนวนเงินไม่ถูกต้อง");

        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        if (string.IsNullOrWhiteSpace(staff.BankAccountNumber) ||
            string.IsNullOrWhiteSpace(staff.BankName) ||
            string.IsNullOrWhiteSpace(staff.BankAccountName))
            throw new InvalidOperationException("กรุณาตั้งค่าบัญชีธนาคารก่อนถอนเงิน");

        if (!staff.BankAccountVerified)
            throw new InvalidOperationException("กรุณายืนยันบัญชีธนาคารในโปรไฟล์ก่อนถอนเงิน");

        var wallet = await db.Wallets.FirstAsync(w => w.StaffProfileId == staff.Id, ct);
        if (wallet.Balance < request.Amount)
            throw new InvalidOperationException("ยอดเงินไม่เพียงพอ");

        wallet.Balance -= request.Amount;
        wallet.UpdatedAt = DateTime.UtcNow;

        db.WalletTransactions.Add(new WalletTransaction
        {
            WalletId = wallet.Id,
            Type = TransactionType.Withdrawal,
            Amount = -request.Amount,
            Status = TransactionStatus.Pending,
            Description = "คำขอถอนเงิน",
            BalanceBefore = wallet.Balance + request.Amount,
            BalanceAfter = wallet.Balance
        });

        db.WithdrawalRequests.Add(new WithdrawalRequest
        {
            WalletId = wallet.Id,
            Amount = request.Amount,
            BankName = staff.BankName ?? "",
            BankAccountNumber = staff.BankAccountNumber ?? "",
            BankAccountName = staff.BankAccountName ?? ""
        });

        await db.SaveChangesAsync(ct);
    }

    public async Task<WalletDto> SettleNegativeBalanceAsync(
        Guid userId,
        SettleNegativeBalanceRequest? request = null,
        CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var wallet = await db.Wallets.Include(w => w.Transactions)
            .FirstAsync(w => w.StaffProfileId == staff.Id, ct);

        if (wallet.Balance >= 0)
            throw new InvalidOperationException("ไม่มียอดค้างชำระ");

        var amount = -wallet.Balance;
        var before = wallet.Balance;
        wallet.Balance = 0;
        wallet.UpdatedAt = DateTime.UtcNow;

        var reference = string.IsNullOrWhiteSpace(request?.PaymentReference)
            ? $"SIM-{DateTime.UtcNow:yyyyMMddHHmmss}"
            : request!.PaymentReference!.Trim();

        db.WalletTransactions.Add(new WalletTransaction
        {
            WalletId = wallet.Id,
            Type = TransactionType.Deposit,
            Amount = amount,
            Status = TransactionStatus.Completed,
            Description = $"ชำระยอดติดลบเพื่อปลดล็อคบัญชี (อ้างอิง: {reference})",
            BalanceBefore = before,
            BalanceAfter = wallet.Balance
        });

        await db.SaveChangesAsync(ct);

        await AddNotificationAsync(
            userId,
            "ปลดล็อคบัญชีแล้ว",
            $"ชำระยอดค้าง {amount:N2} บาท สำเร็จ บัญชียอดคงเหลือ 0 บาท",
            NotificationType.System,
            null,
            ct);

        return await GetWalletAsync(userId, ct);
    }

    public async Task<IReadOnlyList<CheckInRequirementDto>> GetCheckInRequirementsAsync(Guid jobId, CancellationToken ct = default)
    {
        var job = await db.Jobs.FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        var requirements = await db.CheckInRequirements
            .Where(r => r.JobId == jobId || (r.JobId == null && r.OrganizationId == job.OrganizationId) || (r.JobId == null && r.OrganizationId == null))
            .OrderBy(r => r.StepNumber)
            .ToListAsync(ct);

        // Prefer job-specific, else org, else system
        var jobSpecific = requirements.Where(r => r.JobId == jobId).ToList();
        if (jobSpecific.Count > 0) requirements = jobSpecific;
        else
        {
            var orgSpecific = requirements.Where(r => r.OrganizationId == job.OrganizationId).ToList();
            if (orgSpecific.Count > 0) requirements = orgSpecific;
            else requirements = requirements.Where(r => r.OrganizationId == null && r.JobId == null).ToList();
        }

        return requirements.Select(r => new CheckInRequirementDto(
            r.Id, r.StepNumber, r.TitleTh, r.ContentTh, r.Type, r.RequiresAcknowledgment, r.EstimatedReadTimeSeconds)).ToList();
    }

    public async Task CompleteCheckInAsync(Guid userId, Guid jobId, CompleteCheckInRequest request, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var job = await db.Jobs.FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.HiredStaffProfileId != staff.Id)
            throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status != JobStatus.Confirmed)
            throw new InvalidOperationException("ยังไม่สามารถเช็คอินได้");

        if (double.IsNaN(request.Latitude) || double.IsNaN(request.Longitude) ||
            Math.Abs(request.Latitude) > 90 || Math.Abs(request.Longitude) > 180)
            throw new InvalidOperationException("พิกัดไม่ถูกต้อง กรุณาเปิด GPS แล้วลองใหม่");

        var distanceKm = HaversineKm(request.Latitude, request.Longitude, job.Latitude, job.Longitude);
        var distanceMeters = distanceKm * 1000;
        const double maxCheckInMeters = 500;

        // Skip geofence only when job has no usable coordinates
        var jobHasLocation = Math.Abs(job.Latitude) > 0.0001 || Math.Abs(job.Longitude) > 0.0001;
        if (jobHasLocation && distanceMeters > maxCheckInMeters)
        {
            throw new InvalidOperationException(
                $"คุณอยู่ห่างจากสถานที่ทำงาน {distanceMeters:0} เมตร (ต้องอยู่ในระยะ {maxCheckInMeters:0} เมตร)");
        }

        var session = await db.CheckInSessions.FirstOrDefaultAsync(s => s.JobId == jobId, ct);
        if (session == null)
        {
            session = new CheckInSession { JobId = jobId, StaffProfileId = staff.Id };
            db.CheckInSessions.Add(session);
        }

        session.CompletedStepsJson = JsonSerializer.Serialize(request.CompletedSteps, JsonOptions);
        session.CompletedAt = DateTime.UtcNow;
        session.Latitude = request.Latitude;
        session.Longitude = request.Longitude;
        session.AccuracyMeters = request.AccuracyMeters;
        session.DistanceMeters = distanceMeters;
        session.UpdatedAt = DateTime.UtcNow;

        staff.CurrentLocationLat = request.Latitude;
        staff.CurrentLocationLng = request.Longitude;
        staff.UpdatedAt = DateTime.UtcNow;

        job.Status = JobStatus.CheckedIn;
        job.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task StartWorkAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var job = await db.Jobs.FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.HiredStaffProfileId != staff.Id)
            throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status != JobStatus.CheckedIn)
            throw new InvalidOperationException("ต้องเช็คอินก่อนเริ่มงาน");

        job.Status = JobStatus.InProgress;
        job.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task CompleteWorkAsync(Guid userId, Guid jobId, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var job = await db.Jobs
            .Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.HiredStaffProfileId != staff.Id)
            throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status != JobStatus.InProgress)
            throw new InvalidOperationException("ต้องเริ่มงานก่อนจึงจะปิดงานได้");

        var alreadyPaid = await db.WalletTransactions.AnyAsync(
            t => t.JobId == jobId && t.Type == TransactionType.Payment && t.Status == TransactionStatus.Completed,
            ct);
        if (alreadyPaid)
            throw new InvalidOperationException("งานนี้จ่ายค่าจ้างไปแล้ว");

        var wallet = await db.Wallets.FirstOrDefaultAsync(w => w.StaffProfileId == staff.Id, ct)
            ?? throw new InvalidOperationException("ไม่พบ wallet");

        await escrow.ReleaseToStaffAsync(job, staff, wallet, ct);

        job.Status = JobStatus.Completed;
        job.UpdatedAt = DateTime.UtcNow;

        var paidAmount = (await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct))?.StaffAmount
            ?? job.TotalPay;

        await notifications.NotifyAsync(
            userId,
            "ได้รับค่าตอบแทน",
            $"คุณได้รับ {paidAmount:N2} บาท จากงาน \"{job.Title}\"",
            NotificationType.PaymentReceived,
            job.Id,
            ct);

        var clinicUserIds = await db.OrganizationMembers
            .Where(m => m.OrganizationId == job.OrganizationId && m.IsActive)
            .Select(m => m.UserId)
            .ToListAsync(ct);
        foreach (var clinicUserId in clinicUserIds)
        {
            await notifications.NotifyAsync(
                clinicUserId,
                "พนักงานปิดงานแล้ว",
                $"{staff.FirstName} {staff.LastName} ปิดงาน \"{job.Title}\" แล้ว ระบบจ่ายค่าจ้างจาก escrow",
                NotificationType.ApplicationUpdate,
                job.Id,
                ct);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task RateClinicAsync(Guid userId, Guid jobId, RateJobRequest request, CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var job = await db.Jobs
            .Include(j => j.ClinicReview)
            .Include(j => j.Organization)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.HiredStaffProfileId != staff.Id)
            throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status != JobStatus.Completed)
            throw new InvalidOperationException("ให้คะแนนได้เฉพาะงานที่เสร็จและจ่ายเงินแล้ว");

        if (job.ClinicReview != null)
            throw new InvalidOperationException("คุณให้คะแนนคลินิกในงานนี้แล้ว");

        if (request.Rating is < 1 or > 5)
            throw new InvalidOperationException("คะแนนต้องอยู่ระหว่าง 1–5");

        var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        if (comment is { Length: > 1000 })
            throw new InvalidOperationException("ความคิดเห็นยาวเกินไป");

        db.JobClinicReviews.Add(new JobClinicReview
        {
            JobId = job.Id,
            StaffProfileId = staff.Id,
            OrganizationId = job.OrganizationId,
            RatedByUserId = userId,
            Rating = request.Rating,
            Comment = comment
        });

        var priorCount = await db.JobClinicReviews.CountAsync(r => r.OrganizationId == job.OrganizationId, ct);
        var priorAvg = await db.JobClinicReviews
            .Where(r => r.OrganizationId == job.OrganizationId)
            .Select(r => (double?)r.Rating)
            .AverageAsync(ct);
        var newAvg = priorCount == 0
            ? request.Rating
            : ((priorAvg ?? 0) * priorCount + request.Rating) / (priorCount + 1);
        job.Organization.Rating = Math.Round(newAvg, 2);
        job.Organization.UpdatedAt = DateTime.UtcNow;

        var clinicUserIds = await db.OrganizationMembers
            .Where(m => m.OrganizationId == job.OrganizationId && m.IsActive)
            .Select(m => m.UserId)
            .ToListAsync(ct);
        foreach (var clinicUserId in clinicUserIds)
        {
            await notifications.NotifyAsync(
                clinicUserId,
                "ได้รับการรีวิวจากพนักงาน",
                $"{staff.FirstName} ให้คะแนน {request.Rating}/5 สำหรับงาน \"{job.Title}\"",
                NotificationType.ApplicationUpdate,
                job.Id,
                ct);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task<JobIssueDto> ReportJobIssueAsync(
        Guid userId,
        Guid jobId,
        ReportJobIssueRequest request,
        CancellationToken ct = default)
    {
        var staff = (await GetStaffUserAsync(userId, ct)).StaffProfile!;
        var job = await db.Jobs.FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("ไม่พบงาน");

        if (job.HiredStaffProfileId != staff.Id)
            throw new InvalidOperationException("คุณไม่ได้ถูกจ้างในงานนี้");

        if (job.Status is not (JobStatus.CheckedIn or JobStatus.InProgress))
            throw new InvalidOperationException("รายงานปัญหาได้เฉพาะงานที่เช็คอินหรือกำลังทำงาน");

        var description = (request.Description ?? "").Trim();
        if (description.Length < 5)
            throw new InvalidOperationException("กรุณาระบุรายละเอียดอย่างน้อย 5 ตัวอักษร");
        if (description.Length > 2000)
            throw new InvalidOperationException("รายละเอียดยาวเกินไป");

        if (!Enum.TryParse<JobIssueCategory>(request.Category?.Trim(), ignoreCase: true, out var category))
            throw new InvalidOperationException("หมวดหมู่ไม่ถูกต้อง (Safety, Equipment, PatientCare, Schedule, Other)");

        var issue = new JobIssue
        {
            JobId = job.Id,
            StaffProfileId = staff.Id,
            OrganizationId = job.OrganizationId,
            Category = category,
            Description = description,
            Status = JobIssueStatus.Open
        };
        db.JobIssues.Add(issue);

        var clinicUserIds = await db.OrganizationMembers
            .Where(m => m.OrganizationId == job.OrganizationId && m.IsActive)
            .Select(m => m.UserId)
            .ToListAsync(ct);
        foreach (var clinicUserId in clinicUserIds)
        {
            await notifications.NotifyAsync(
                clinicUserId,
                "พนักงานรายงานปัญหา",
                $"{staff.FirstName} {staff.LastName} รายงานปัญหา ({category}) ในงาน \"{job.Title}\"",
                NotificationType.JobIssueReported,
                job.Id,
                ct);
        }

        await db.SaveChangesAsync(ct);

        return new JobIssueDto(
            issue.Id, issue.JobId, staff.Id, $"{staff.FirstName} {staff.LastName}",
            issue.Category.ToString(), issue.Description, issue.Status.ToString(),
            issue.CreatedAt, issue.ResolvedAt);
    }

    private static double HaversineKm(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6371;
        static double ToRad(double deg) => deg * Math.PI / 180;
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return r * c;
    }

    public async Task RegisterDeviceAsync(Guid userId, string token, string? platform, CancellationToken ct = default)
    {
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

    public async Task<IReadOnlyList<NotificationDto>> GetNotificationsAsync(Guid userId, CancellationToken ct = default)
    {
        return await db.Notifications.Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Select(n => new NotificationDto(n.Id, n.Title, n.Message, n.Type.ToString(), n.IsRead, n.CreatedAt, n.JobId))
            .ToListAsync(ct);
    }

    public async Task MarkNotificationReadAsync(Guid userId, Guid notificationId, CancellationToken ct = default)
    {
        var n = await db.Notifications.FirstOrDefaultAsync(x => x.Id == notificationId && x.UserId == userId, ct)
            ?? throw new InvalidOperationException("ไม่พบการแจ้งเตือน");
        n.IsRead = true;
        n.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task TestPushAsync(Guid userId, CancellationToken ct = default)
    {
        await GetStaffUserAsync(userId, ct);
        await notifications.NotifyAsync(
            userId,
            "ทดสอบ Push Notification",
            "MedShift ส่งข้อความทดสอบนี้สำเร็จ (หรือ dry-run ถ้ายังไม่ตั้ง Firebase Admin credentials)",
            NotificationType.System,
            null,
            ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task<IReadOnlyList<AnnouncementDto>> GetActiveAnnouncementsAsync(string locale, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var items = await db.Announcements
            .Where(a => a.IsActive && (a.ExpiresAt == null || a.ExpiresAt > now))
            .OrderByDescending(a => a.CreatedAt)
            .ToListAsync(ct);

        var isEn = locale.StartsWith("en", StringComparison.OrdinalIgnoreCase);
        return items.Select(a => new AnnouncementDto(
            a.Id,
            isEn ? a.TitleEn : a.TitleTh,
            isEn ? a.MessageEn : a.MessageTh,
            a.Type, a.CreatedAt, a.ExpiresAt)).ToList();
    }

    private async Task EnsureNoConflictAsync(Guid staffProfileId, Job job, CancellationToken ct)
    {
        var hiredJobIds = await db.JobApplications
            .Where(a => a.StaffProfileId == staffProfileId && a.Status == ApplicationStatus.Hired)
            .Select(a => a.JobId)
            .ToListAsync(ct);

        var conflicts = await db.Jobs
            .Where(j => hiredJobIds.Contains(j.Id))
            .Where(j => j.StartTime < job.EndTime && job.StartTime < j.EndTime)
            .AnyAsync(ct);

        if (conflicts)
            throw new InvalidOperationException("ตารางงานชนกับงานที่รับไว้แล้ว");
    }

    private async Task ApplyPenaltyAsync(StaffProfile staff, Guid jobId, decimal amount, string description, CancellationToken ct)
    {
        var wallet = await db.Wallets.FirstAsync(w => w.StaffProfileId == staff.Id, ct);
        var before = wallet.Balance;
        wallet.Balance -= amount;
        wallet.UpdatedAt = DateTime.UtcNow;
        db.WalletTransactions.Add(new WalletTransaction
        {
            WalletId = wallet.Id,
            JobId = jobId,
            Type = TransactionType.Penalty,
            Amount = -amount,
            Status = TransactionStatus.Completed,
            Description = description,
            BalanceBefore = before,
            BalanceAfter = wallet.Balance
        });
    }

    private async Task ReorderWaitlistAsync(Guid jobId, CancellationToken ct)
    {
        var list = await db.JobApplications
            .Where(a => a.JobId == jobId && a.Status == ApplicationStatus.Waitlist)
            .OrderBy(a => a.WaitlistPosition).ThenBy(a => a.CreatedAt)
            .ToListAsync(ct);
        for (var i = 0; i < list.Count; i++)
        {
            list[i].WaitlistPosition = i + 1;
            list[i].UpdatedAt = DateTime.UtcNow;
        }
    }

    private async Task AddNotificationAsync(Guid userId, string title, string message, NotificationType type, Guid? jobId, CancellationToken ct)
    {
        await notifications.NotifyAsync(userId, title, message, type, jobId, ct);
    }

    private async Task<User> GetStaffUserAsync(Guid userId, CancellationToken ct)
    {
        var user = await db.Users
            .Include(u => u.StaffProfile)!.ThenInclude(s => s!.Skills)
            .Include(u => u.StaffProfile)!.ThenInclude(s => s!.Documents)
            .FirstOrDefaultAsync(u => u.Id == userId && u.Role == UserRole.Staff, ct)
            ?? throw new InvalidOperationException("ไม่พบโปรไฟล์พนักงาน");
        if (user.StaffProfile == null)
            throw new InvalidOperationException("ไม่พบโปรไฟล์พนักงาน");
        return user;
    }

    public async Task<StaffDocumentDto> UploadDocumentAsync(
        Guid userId,
        string documentType,
        Stream content,
        string originalFileName,
        string? contentType,
        long fileSizeBytes,
        CancellationToken ct = default)
    {
        if (!Enum.TryParse<StaffDocumentType>(documentType, true, out var type))
            throw new InvalidOperationException("ประเภทเอกสารไม่ถูกต้อง");

        var user = await GetStaffUserAsync(userId, ct);
        var staff = user.StaffProfile!;

        var ext = Path.GetExtension(originalFileName).ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(ext))
            ext = contentType switch
            {
                "image/jpeg" or "image/jpg" => ".jpg",
                "image/png" => ".png",
                "image/webp" => ".webp",
                "application/pdf" => ".pdf",
                _ => ".bin"
            };

        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            { ".jpg", ".jpeg", ".png", ".webp", ".pdf" };
        if (!allowed.Contains(ext))
            throw new InvalidOperationException("รองรับเฉพาะ JPG, PNG, WEBP, PDF");

        var fileName = $"{staff.Id:N}_{type}_{DateTime.UtcNow:yyyyMMddHHmmss}{ext}";
        var url = await fileStorage.SaveAsync(content, "uploads/staff-docs", fileName, ct);

        // Replace previous file of the same type (keep one current per type for KYC).
        var existing = await db.StaffDocuments
            .Where(d => d.StaffProfileId == staff.Id && d.DocumentType == type)
            .ToListAsync(ct);
        if (existing.Count > 0)
            db.StaffDocuments.RemoveRange(existing);

        var doc = new StaffDocument
        {
            StaffProfileId = staff.Id,
            DocumentType = type,
            FileUrl = url,
            OriginalFileName = originalFileName,
            ContentType = contentType,
            FileSizeBytes = fileSizeBytes,
            VerificationStatus = DocumentVerificationStatus.Pending
        };
        db.StaffDocuments.Add(doc);
        staff.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);

        return MapDocument(doc);
    }

    public async Task<IReadOnlyList<StaffDocumentDto>> GetDocumentsAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await GetStaffUserAsync(userId, ct);
        return user.StaffProfile!.Documents
            .OrderByDescending(d => d.CreatedAt)
            .Select(MapDocument)
            .ToList();
    }

    private static void EnsureStaffApproved(StaffProfile staff)
    {
        if (staff.Status == StaffStatus.Approved)
            return;

        throw new InvalidOperationException(staff.Status switch
        {
            StaffStatus.Pending => "บัญชีของคุณรอ Admin อนุมัติก่อนจึงจะรับงานได้",
            StaffStatus.Rejected => $"บัญชีถูกปฏิเสธ: {staff.RejectionReason ?? "กรุณาติดต่อแอดมิน"}",
            StaffStatus.Suspended => $"บัญชีถูกระงับ: {staff.RejectionReason ?? "กรุณาติดต่อแอดมิน"}",
            _ => "บัญชียังไม่พร้อมรับงาน"
        });
    }

    private static void EnsureLicenseValid(StaffProfile staff)
    {
        if (staff.LicenseExpiryDate == null)
            throw new InvalidOperationException("กรุณาระบุวันหมดอายุใบอนุญาตในโปรไฟล์ก่อนสมัครงาน");

        if (staff.LicenseExpiryDate.Value.Date < DateTime.UtcNow.Date)
            throw new InvalidOperationException("ใบอนุญาตหมดอายุแล้ว ไม่สามารถสมัครงานได้ กรุณาอัปเดตใบอนุญาต");
    }

    private static void ApplyBankVerification(
        StaffProfile profile,
        string firstName,
        string lastName,
        bool? requestedVerified)
    {
        var hasPromptPay = !string.IsNullOrWhiteSpace(profile.PromptPayId);
        var completeBank = !string.IsNullOrWhiteSpace(profile.BankName)
            && !string.IsNullOrWhiteSpace(profile.BankAccountNumber)
            && !string.IsNullOrWhiteSpace(profile.BankAccountName);
        var nameOk = NamesMatch(firstName, lastName, profile.BankAccountName);

        if (hasPromptPay && !completeBank)
        {
            // PromptPay-only payout: mark verified when ID present (admin still reviews docs).
            profile.BankAccountVerified = requestedVerified ?? true;
            return;
        }

        if (!completeBank || !nameOk)
        {
            profile.BankAccountVerified = false;
            return;
        }

        if (requestedVerified.HasValue)
            profile.BankAccountVerified = requestedVerified.Value;
    }

    private static bool NamesMatch(string firstName, string lastName, string? accountName)
    {
        if (string.IsNullOrWhiteSpace(accountName)) return false;
        static string Norm(string s) =>
            string.Join(' ', s.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries)).ToLowerInvariant();
        return Norm(accountName) == Norm($"{firstName} {lastName}");
    }

    private static StaffDocumentDto MapDocument(StaffDocument d) =>
        new(d.Id, d.DocumentType.ToString(), d.FileUrl, d.OriginalFileName,
            d.VerificationStatus.ToString(), d.RejectionReason, d.CreatedAt);

    private static StaffProfileDto MapProfile(User user)
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
            p.Documents.OrderByDescending(d => d.CreatedAt).Select(MapDocument).ToList());
    }

    internal static JobDto MapJob(Job job, string? paymentQrImageBase64 = null)
    {
        var skills = new List<string>();
        try { skills = JsonSerializer.Deserialize<List<string>>(job.RequiredSkillsJson) ?? []; }
        catch { /* ignore */ }

        return new JobDto(
            job.Id, job.OrganizationId, job.Organization?.Name ?? "",
            job.Title, job.Description, job.LocationName, job.Address,
            job.Latitude, job.Longitude, job.StartTime, job.EndTime,
            job.HourlyRate, job.TotalPay, job.Status.ToString(),
            skills, job.RequiredCertification, job.MinReliabilityScore,
            job.HiredStaffProfileId,
            job.Review?.Rating,
            job.Review?.Comment,
            job.CreatedAt,
            job.Payment?.PlatformFee,
            job.Payment?.TotalCharged,
            job.Payment?.Status.ToString(),
            job.Payment?.GatewayReference,
            job.Payment?.MerchantReference,
            paymentQrImageBase64,
            job.ClinicReview?.Rating,
            job.ClinicReview?.Comment);
    }
}
