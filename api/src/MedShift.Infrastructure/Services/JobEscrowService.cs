using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using MedShift.Infrastructure.Payments;
using MedShift.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace MedShift.Infrastructure.Services;

/// <summary>
/// Clinic pays TotalPay + platform fee at job post.
/// StaffAmount is escrowed until complete; fee is platform revenue (non-refundable on cancel).
/// </summary>
public class JobEscrowService(
    MedShiftDbContext db,
    IPaymentGateway gateway)
{
    public const string FeePercentKey = "platform_fee_percent";
    public const decimal DefaultFeePercent = 10m;

    public bool IsSynchronousGateway => gateway.IsSynchronous;

    public string GatewayProviderName => gateway.ProviderName;

    public async Task<decimal> GetFeePercentAsync(CancellationToken ct = default)
    {
        var setting = await db.SystemSettings.AsNoTracking()
            .FirstOrDefaultAsync(s => s.Key == FeePercentKey, ct);
        if (setting == null || !decimal.TryParse(setting.Value, out var pct) || pct < 0)
            return DefaultFeePercent;
        return pct;
    }

    public static (decimal staffAmount, decimal platformFee, decimal totalCharged) Calculate(
        decimal staffAmount,
        decimal feePercent)
    {
        var fee = Math.Round(staffAmount * feePercent / 100m, 2);
        return (staffAmount, fee, staffAmount + fee);
    }

    /// <summary>Simulated: charge + Held immediately. Returns payment.</summary>
    public async Task<JobPayment> ChargeAndHoldAsync(
        Job job,
        Guid organizationId,
        CancellationToken ct = default)
    {
        var feePercent = await GetFeePercentAsync(ct);
        var (staffAmount, platformFee, totalCharged) = Calculate(job.TotalPay, feePercent);

        var charge = await gateway.ChargeAsync(
            organizationId,
            totalCharged,
            $"MedShift job post: {job.Title} (staff {staffAmount:N2} + fee {platformFee:N2})",
            ct);

        if (!charge.Success)
            throw new InvalidOperationException(charge.Message ?? "ชำระเงินผ่าน payment gateway ไม่สำเร็จ");

        var payment = new JobPayment
        {
            JobId = job.Id,
            OrganizationId = organizationId,
            StaffAmount = staffAmount,
            PlatformFee = platformFee,
            TotalCharged = totalCharged,
            FeePercent = feePercent,
            GatewayReference = charge.Reference,
            MerchantReference = charge.Reference.Length > 15 ? charge.Reference[..15] : charge.Reference,
            GatewayProvider = charge.Provider,
            Status = JobPaymentStatus.Held
        };
        db.JobPayments.Add(payment);
        AddPlatformFeeLedger(job, organizationId, platformFee, feePercent, charge.Reference);
        return payment;
    }

    /// <summary>GB QR: create Pending payment + QR session.</summary>
    public async Task<(JobPayment Payment, PaymentQrSession Qr)> CreatePendingQrPaymentAsync(
        Job job,
        Guid organizationId,
        CancellationToken ct = default)
    {
        var feePercent = await GetFeePercentAsync(ct);
        var (staffAmount, platformFee, totalCharged) = Calculate(job.TotalPay, feePercent);
        var merchantRef = BuildMerchantReference(job.Id);

        var qr = await gateway.CreateQrChargeAsync(
            organizationId,
            job.Id,
            totalCharged,
            $"MedShift:{job.Title}",
            merchantRef,
            ct);

        if (!qr.Success)
            throw new InvalidOperationException(qr.Message ?? "สร้าง QR PromptPay ไม่สำเร็จ");

        var payment = new JobPayment
        {
            JobId = job.Id,
            OrganizationId = organizationId,
            StaffAmount = staffAmount,
            PlatformFee = platformFee,
            TotalCharged = totalCharged,
            FeePercent = feePercent,
            GatewayReference = merchantRef,
            MerchantReference = merchantRef,
            GatewayProvider = qr.Provider,
            Status = JobPaymentStatus.Pending
        };
        db.JobPayments.Add(payment);
        return (payment, qr);
    }

    /// <summary>Confirm paid → Held + Open job + platform fee ledger. Idempotent.</summary>
    public async Task<bool> ConfirmPaymentAsync(
        string merchantReference,
        string? gbpReferenceNo,
        decimal? paidAmount,
        CancellationToken ct = default)
    {
        var payment = await db.JobPayments
            .Include(p => p.Job)
            .FirstOrDefaultAsync(p => p.MerchantReference == merchantReference, ct);

        if (payment == null)
            return false;

        if (payment.Status is JobPaymentStatus.Held or JobPaymentStatus.Released)
            return true;

        if (payment.Status != JobPaymentStatus.Pending)
            return false;

        if (paidAmount.HasValue && Math.Abs(paidAmount.Value - payment.TotalCharged) > 0.01m)
            throw new InvalidOperationException(
                $"ยอดชำระไม่ตรง Expected={payment.TotalCharged} Got={paidAmount}");

        payment.Status = JobPaymentStatus.Held;
        payment.GbpReferenceNo = gbpReferenceNo;
        if (!string.IsNullOrWhiteSpace(gbpReferenceNo))
            payment.GatewayReference = gbpReferenceNo;
        payment.UpdatedAt = DateTime.UtcNow;

        if (payment.Job.Status == JobStatus.PendingPayment)
        {
            payment.Job.Status = JobStatus.Open;
            payment.Job.UpdatedAt = DateTime.UtcNow;
        }

        var alreadyLedger = await db.PlatformLedgerEntries.AnyAsync(
            e => e.JobId == payment.JobId && e.Type == "JobPlatformFee", ct);
        if (!alreadyLedger && payment.PlatformFee > 0)
        {
            AddPlatformFeeLedger(
                payment.Job,
                payment.OrganizationId,
                payment.PlatformFee,
                payment.FeePercent,
                payment.GatewayReference);
        }

        return true;
    }

    public async Task SyncPaymentStatusFromGatewayAsync(JobPayment payment, CancellationToken ct = default)
    {
        if (payment.Status != JobPaymentStatus.Pending || string.IsNullOrWhiteSpace(payment.MerchantReference))
            return;

        if (gateway.IsSynchronous)
            return;

        var query = await gateway.QueryStatusAsync(payment.MerchantReference, ct);
        if (query.Paid)
            await ConfirmPaymentAsync(payment.MerchantReference, query.GbpReferenceNo, query.Amount, ct);
    }

    public async Task ReleaseToStaffAsync(
        Job job,
        StaffProfile staff,
        Wallet wallet,
        CancellationToken ct = default)
    {
        var alreadyPaid = await db.WalletTransactions.AnyAsync(
            t => t.JobId == job.Id && t.Type == TransactionType.Payment && t.Status == TransactionStatus.Completed,
            ct);
        if (alreadyPaid)
            return;

        var payment = await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct);
        var amount = payment?.StaffAmount ?? job.TotalPay;

        if (payment != null)
        {
            if (payment.Status == JobPaymentStatus.Released)
                return;
            if (payment.Status == JobPaymentStatus.Refunded)
                throw new InvalidOperationException("ยอด escrow ถูกคืนคลินิกแล้ว ไม่สามารถจ่ายพนักงานได้");
            if (payment.Status == JobPaymentStatus.Pending)
                throw new InvalidOperationException("ยังไม่ได้ชำระเงินค่าประกาศงาน");

            payment.Status = JobPaymentStatus.Released;
            payment.ReleasedAt = DateTime.UtcNow;
            payment.UpdatedAt = DateTime.UtcNow;
        }

        var before = wallet.Balance;
        wallet.Balance += amount;
        wallet.UpdatedAt = DateTime.UtcNow;

        db.WalletTransactions.Add(new WalletTransaction
        {
            WalletId = wallet.Id,
            JobId = job.Id,
            Type = TransactionType.Payment,
            Amount = amount,
            Status = TransactionStatus.Completed,
            Description = $"ค่าจ้างงาน: {job.Title}",
            BalanceBefore = before,
            BalanceAfter = wallet.Balance
        });

        staff.TotalJobsCompleted += 1;
        staff.TotalEarnings += amount;
        staff.ReliabilityScore = Math.Min(100, staff.ReliabilityScore + 2);
        staff.UpdatedAt = DateTime.UtcNow;
    }

    public async Task RefundStaffEscrowAsync(Job job, string reason, CancellationToken ct = default)
    {
        var payment = await db.JobPayments.FirstOrDefaultAsync(p => p.JobId == job.Id, ct);
        if (payment == null)
            return;
        if (payment.Status == JobPaymentStatus.Pending)
        {
            // Unpaid QR — just mark refunded/cancelled without gateway call
            payment.Status = JobPaymentStatus.Refunded;
            payment.RefundedAt = DateTime.UtcNow;
            payment.UpdatedAt = DateTime.UtcNow;
            return;
        }
        if (payment.Status != JobPaymentStatus.Held)
            return;

        await gateway.RefundAsync(
            payment.GatewayReference,
            payment.MerchantReference,
            payment.GbpReferenceNo,
            payment.StaffAmount,
            reason,
            ct);

        payment.Status = JobPaymentStatus.Refunded;
        payment.RefundedAt = DateTime.UtcNow;
        payment.UpdatedAt = DateTime.UtcNow;
    }

    private void AddPlatformFeeLedger(
        Job job,
        Guid organizationId,
        decimal platformFee,
        decimal feePercent,
        string gatewayReference)
    {
        if (platformFee <= 0) return;
        db.PlatformLedgerEntries.Add(new PlatformLedgerEntry
        {
            JobId = job.Id,
            OrganizationId = organizationId,
            Amount = platformFee,
            Type = "JobPlatformFee",
            Description = $"ค่าธรรมเนียมแพลตฟอร์ม {feePercent}% จากงาน \"{job.Title}\"",
            GatewayReference = gatewayReference
        });
    }

    /// <summary>GB requires referenceNo max 15 chars, unique.</summary>
    public static string BuildMerchantReference(Guid jobId)
    {
        // 15 chars: time(8) + hex(7) from job id
        var time = DateTime.UtcNow.ToString("yyMMddHH");
        var hex = jobId.ToString("N")[..7];
        return time + hex;
    }
}
