using MedShift.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace MedShift.Infrastructure.Persistence;

public class MedShiftDbContext(DbContextOptions<MedShiftDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<StaffProfile> StaffProfiles => Set<StaffProfile>();
    public DbSet<StaffSkill> StaffSkills => Set<StaffSkill>();
    public DbSet<StaffDocument> StaffDocuments => Set<StaffDocument>();
    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<OrganizationMember> OrganizationMembers => Set<OrganizationMember>();
    public DbSet<Job> Jobs => Set<Job>();
    public DbSet<JobApplication> JobApplications => Set<JobApplication>();
    public DbSet<Wallet> Wallets => Set<Wallet>();
    public DbSet<WalletTransaction> WalletTransactions => Set<WalletTransaction>();
    public DbSet<WithdrawalRequest> WithdrawalRequests => Set<WithdrawalRequest>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<CheckInRequirement> CheckInRequirements => Set<CheckInRequirement>();
    public DbSet<CheckInSession> CheckInSessions => Set<CheckInSession>();
    public DbSet<JobReview> JobReviews => Set<JobReview>();
    public DbSet<JobClinicReview> JobClinicReviews => Set<JobClinicReview>();
    public DbSet<JobIssue> JobIssues => Set<JobIssue>();
    public DbSet<JobPayment> JobPayments => Set<JobPayment>();
    public DbSet<PlatformLedgerEntry> PlatformLedgerEntries => Set<PlatformLedgerEntry>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<SystemSetting> SystemSettings => Set<SystemSetting>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.Email).HasMaxLength(256);
            e.Property(x => x.PreferredLocale).HasMaxLength(10);
        });

        modelBuilder.Entity<StaffProfile>(e =>
        {
            e.HasOne(x => x.User).WithOne(x => x.StaffProfile).HasForeignKey<StaffProfile>(x => x.UserId);
            e.Property(x => x.TotalEarnings).HasPrecision(18, 2);
            e.Property(x => x.NationalId).HasMaxLength(20);
            e.Property(x => x.LaserCode).HasMaxLength(32);
            e.Property(x => x.LicenseNumber).HasMaxLength(64);
            e.Property(x => x.PromptPayId).HasMaxLength(32);
        });

        modelBuilder.Entity<StaffDocument>(e =>
        {
            e.HasOne(x => x.StaffProfile).WithMany(x => x.Documents).HasForeignKey(x => x.StaffProfileId);
            e.HasIndex(x => new { x.StaffProfileId, x.DocumentType });
            e.Property(x => x.FileUrl).HasMaxLength(512);
            e.Property(x => x.OriginalFileName).HasMaxLength(256);
            e.Property(x => x.ContentType).HasMaxLength(128);
        });

        modelBuilder.Entity<StaffSkill>(e =>
        {
            e.Property(x => x.MinRate).HasPrecision(18, 2);
            e.Property(x => x.MaxRate).HasPrecision(18, 2);
        });

        modelBuilder.Entity<Organization>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(256);
            e.HasIndex(x => x.TaxId);
        });

        modelBuilder.Entity<OrganizationMember>(e =>
        {
            e.HasIndex(x => new { x.OrganizationId, x.UserId }).IsUnique();
            e.HasOne(x => x.Organization).WithMany(x => x.Members).HasForeignKey(x => x.OrganizationId);
            e.HasOne(x => x.User).WithMany(x => x.OrganizationMemberships).HasForeignKey(x => x.UserId);
        });

        modelBuilder.Entity<Job>(e =>
        {
            e.Property(x => x.HourlyRate).HasPrecision(18, 2);
            e.Property(x => x.TotalPay).HasPrecision(18, 2);
            e.HasOne(x => x.Organization).WithMany(x => x.Jobs).HasForeignKey(x => x.OrganizationId);
            e.HasOne(x => x.HiredStaffProfile).WithMany().HasForeignKey(x => x.HiredStaffProfileId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<JobApplication>(e =>
        {
            e.HasIndex(x => new { x.JobId, x.StaffProfileId }).IsUnique();
            e.Property(x => x.PenaltyAmount).HasPrecision(18, 2);
            e.HasOne(x => x.Job).WithMany(x => x.Applications).HasForeignKey(x => x.JobId);
            e.HasOne(x => x.StaffProfile).WithMany(x => x.Applications).HasForeignKey(x => x.StaffProfileId);
        });

        modelBuilder.Entity<Wallet>(e =>
        {
            e.HasIndex(x => x.StaffProfileId).IsUnique();
            e.Property(x => x.Balance).HasPrecision(18, 2);
            e.HasOne(x => x.StaffProfile).WithOne(x => x.Wallet).HasForeignKey<Wallet>(x => x.StaffProfileId);
        });

        modelBuilder.Entity<WalletTransaction>(e =>
        {
            e.Property(x => x.Amount).HasPrecision(18, 2);
            e.Property(x => x.BalanceBefore).HasPrecision(18, 2);
            e.Property(x => x.BalanceAfter).HasPrecision(18, 2);
        });

        modelBuilder.Entity<WithdrawalRequest>(e =>
        {
            e.Property(x => x.Amount).HasPrecision(18, 2);
        });

        modelBuilder.Entity<CheckInSession>(e =>
        {
            e.HasIndex(x => x.JobId).IsUnique();
            e.HasOne(x => x.Job).WithOne(x => x.CheckInSession).HasForeignKey<CheckInSession>(x => x.JobId);
        });

        modelBuilder.Entity<JobReview>(e =>
        {
            e.HasIndex(x => x.JobId).IsUnique();
            e.HasOne(x => x.Job).WithOne(x => x.Review).HasForeignKey<JobReview>(x => x.JobId);
            e.Property(x => x.Comment).HasMaxLength(1000);
        });

        modelBuilder.Entity<JobClinicReview>(e =>
        {
            e.HasIndex(x => x.JobId).IsUnique();
            e.HasOne(x => x.Job).WithOne(x => x.ClinicReview).HasForeignKey<JobClinicReview>(x => x.JobId);
            e.Property(x => x.Comment).HasMaxLength(1000);
            e.HasOne(x => x.StaffProfile).WithMany().HasForeignKey(x => x.StaffProfileId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<JobIssue>(e =>
        {
            e.HasIndex(x => x.JobId);
            e.Property(x => x.Description).HasMaxLength(2000);
            e.HasOne(x => x.Job).WithMany(x => x.Issues).HasForeignKey(x => x.JobId);
            e.HasOne(x => x.StaffProfile).WithMany().HasForeignKey(x => x.StaffProfileId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<JobPayment>(e =>
        {
            e.HasIndex(x => x.JobId).IsUnique();
            e.HasIndex(x => x.MerchantReference);
            e.Property(x => x.StaffAmount).HasPrecision(18, 2);
            e.Property(x => x.PlatformFee).HasPrecision(18, 2);
            e.Property(x => x.TotalCharged).HasPrecision(18, 2);
            e.Property(x => x.FeePercent).HasPrecision(5, 2);
            e.Property(x => x.GatewayReference).HasMaxLength(64);
            e.Property(x => x.GatewayProvider).HasMaxLength(64);
            e.Property(x => x.MerchantReference).HasMaxLength(15);
            e.Property(x => x.GbpReferenceNo).HasMaxLength(64);
            e.HasOne(x => x.Job).WithOne(x => x.Payment).HasForeignKey<JobPayment>(x => x.JobId);
        });

        modelBuilder.Entity<PlatformLedgerEntry>(e =>
        {
            e.Property(x => x.Amount).HasPrecision(18, 2);
            e.Property(x => x.Type).HasMaxLength(64);
            e.Property(x => x.Description).HasMaxLength(500);
            e.Property(x => x.GatewayReference).HasMaxLength(64);
        });

        modelBuilder.Entity<PasswordResetToken>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.Code });
            e.Property(x => x.Code).HasMaxLength(12);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SystemSetting>(e =>
        {
            e.HasIndex(x => x.Key).IsUnique();
        });

        modelBuilder.Entity<DeviceToken>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.FirebaseDeviceToken }).IsUnique();
        });
    }
}
