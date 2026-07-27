enum JobStatus {
  open('Open', 'เปิดรับสมัคร'),
  pendingPayment('PendingPayment', 'รอชำระเงิน'),
  applied('Applied', 'มีการสมัคร'),
  selecting('Selecting', 'กำลังพิจารณา'),
  confirmed('Confirmed', 'ยืนยันการจ้างแล้ว'),
  checkedIn('CheckedIn', 'เช็คอินแล้ว'),
  inProgress('InProgress', 'กำลังทำงาน'),
  completed('Completed', 'เสร็จสิ้น'),
  cancelled('Cancelled', 'ยกเลิก');

  final String value;
  final String description;

  const JobStatus(this.value, this.description);

  static JobStatus fromString(String status) {
    final normalized = status.trim();
    return JobStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == normalized.toLowerCase(),
      orElse: () => JobStatus.open,
    );
  }

  String get displayText => description;

  bool get canApply => this == JobStatus.open || this == JobStatus.applied;

  bool get canCheckIn => this == JobStatus.confirmed;

  bool get canStartWork => this == JobStatus.checkedIn;

  bool get canCompleteWork => this == JobStatus.inProgress;

  bool get canReportIssue =>
      this == JobStatus.checkedIn || this == JobStatus.inProgress;

  bool get canRateClinic => this == JobStatus.completed;

  bool get isActive =>
      this == JobStatus.confirmed ||
      this == JobStatus.checkedIn ||
      this == JobStatus.inProgress;
}

enum ApplicationStatus {
  pending('Pending', 'Application submitted'),
  waitlist('Waitlist', 'On waitlist'),
  hired('Hired', 'Hired for this job'),
  rejected('Rejected', 'Not selected'),
  withdrawn('Withdrawn', 'Staff withdrew'),
  noShow('NoShow', 'No-show');

  final String value;
  final String description;

  const ApplicationStatus(this.value, this.description);

  static ApplicationStatus fromString(String status) {
    final normalized = status.trim();
    return ApplicationStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == normalized.toLowerCase(),
      orElse: () => ApplicationStatus.pending,
    );
  }
}
