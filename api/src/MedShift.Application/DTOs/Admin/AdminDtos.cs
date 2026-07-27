using MedShift.Application.DTOs.Staff;

namespace MedShift.Application.DTOs.Admin;

public record WithdrawalDto(
    Guid Id,
    Guid StaffProfileId,
    string StaffName,
    decimal Amount,
    string BankName,
    string BankAccountNumber,
    string BankAccountName,
    string Status,
    DateTime CreatedAt);

public record CreateAnnouncementRequest(
    string TitleTh,
    string TitleEn,
    string MessageTh,
    string MessageEn,
    string Type,
    DateTime? ExpiresAt);

public record DashboardDto(
    int TotalStaff,
    int PendingStaff,
    int TotalClinics,
    int PendingClinics,
    int OpenJobs,
    int PendingWithdrawals,
    decimal TotalWalletBalance);
