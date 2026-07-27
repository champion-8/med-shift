import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/locale/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/job_model.dart';
import '../../core/enums/status_enums.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../check_in/check_in_screen.dart';
import '../job_detail/job_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String? get _staffId => context.read<AuthProvider>().currentUser?.id;

  Future<void> _refreshJobs() async {
    final staffId = _staffId;
    if (staffId == null || staffId.isEmpty) return;
    final jobProvider = context.read<JobProvider>();
    await jobProvider.fetchMyHiredJobs(staffId);
    await jobProvider.fetchMyWaitlistJobs(staffId);
    await jobProvider.fetchMyPendingJobs(staffId);
    await jobProvider.fetchJobs();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('calendar_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshJobs();
            },
          ),
        ],
      ),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          if (jobProvider.isLoading &&
              jobProvider.myHiredJobs.isEmpty &&
              jobProvider.myWaitlistJobs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refreshJobs,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Calendar Widget
                  _buildCalendar(jobProvider),

                  // Legend
                  _buildLegend(),

                  const SizedBox(height: 16),

                  // Selected Day Jobs
                  if (_selectedDay != null) _buildSelectedDayJobs(jobProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(JobProvider jobProvider) {
    final allJobs = [
      ...jobProvider.myHiredJobs,
      ...jobProvider.myWaitlistJobs,
      ...jobProvider.myPendingJobs,
      ...jobProvider.availableJobs,
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: (day) {
          return _getEventsForDay(day, allJobs);
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: AppTheme.accentColor,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          outsideDaysVisible: false,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          formatButtonTextStyle: const TextStyle(color: Colors.white),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();

            final jobsOnDay = _getJobsForDay(date, allJobs);
            final hiredCount = jobsOnDay
                .where((j) => jobProvider.myHiredJobs.contains(j))
                .length;
            final waitlistCount = jobsOnDay
                .where((j) => jobProvider.myWaitlistJobs.contains(j))
                .length;
            final pendingCount = jobsOnDay
                .where((j) => jobProvider.myPendingJobs.contains(j))
                .length;
            final availableCount = jobsOnDay
                .where((j) => jobProvider.availableJobs.contains(j))
                .length;

            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hiredCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (waitlistCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (pendingCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.infoColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (availableCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.dividerColor, width: 1.5),
      ),
      child: GridView.count(
        shrinkWrap: true, // เพื่อให้กริดยุบตัวตามขนาดข้อมูล ไม่ขยายเต็มหน้าจอ
        physics:
            const NeverScrollableScrollPhysics(), // ปิดการสกรอลล์เพราะเราจะใช้เป็นแค่เลย์เอาต์เลเจนด์
        crossAxisCount: 2, // บังคับ 2 คอลัมน์
        mainAxisSpacing: 1, // ระยะห่างระหว่างแถว (แนวตั้ง)
        crossAxisSpacing: 16, // ระยะห่างระหว่างไอเทม (แนวนอน)
        childAspectRatio:
            6, // ปรับสัดส่วน กว้าง:สูง ของไอเทมแต่ละตัว (ลองปรับเลขนี้เพื่อให้เหมาะสมกับข้อความ)
        children: [
          _buildLegendItem(
            color: AppTheme.successColor,
            label: context.tr('calendar_hired'),
          ),
          _buildLegendItem(color: AppTheme.warningColor, label: context.tr('calendar_waitlist')),
          _buildLegendItem(color: AppTheme.infoColor, label: context.tr('calendar_pending')),
          _buildLegendItem(color: AppTheme.errorColor, label: context.tr('calendar_available')),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildSelectedDayJobs(JobProvider jobProvider) {
    final allJobs = [
      ...jobProvider.myHiredJobs,
      ...jobProvider.myWaitlistJobs,
      ...jobProvider.myPendingJobs,
      ...jobProvider.availableJobs,
    ];
    final jobsOnSelectedDay = _getJobsForDay(_selectedDay!, allJobs);

    if (jobsOnSelectedDay.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: AppTheme.textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('calendar_no_jobs_selected'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('d MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "${context.tr('calendar_jobs_on')} ${dateFormat.format(_selectedDay!)}",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...jobsOnSelectedDay.map((job) {
          final isHired = jobProvider.myHiredJobs.contains(job);
          final isWaitlist = jobProvider.myWaitlistJobs.contains(job);
          final isPending = jobProvider.myPendingJobs.contains(job);
          final isAvailable = jobProvider.availableJobs.contains(job);
          return _buildJobCard(
            job,
            isHired,
            isWaitlist,
            isPending,
            isAvailable,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildJobCard(
    JobModel job,
    bool isHired,
    bool isWaitlist,
    bool isPending,
    bool isAvailable,
  ) {
    final timeFormat = DateFormat('HH:mm');

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isHired) {
      statusColor = AppTheme.successColor;
      statusLabel = context.tr('calendar_hired_status');
      statusIcon = Icons.check_circle;
    } else if (isWaitlist) {
      statusColor = AppTheme.warningColor;
      statusLabel = context.tr('calendar_waitlist');
      statusIcon = Icons.schedule;
    } else if (isPending) {
      statusColor = AppTheme.infoColor;
      statusLabel = context.tr('calendar_pending');
      statusIcon = Icons.hourglass_empty;
    } else {
      statusColor = AppTheme.errorColor;
      statusLabel = context.tr('calendar_available');
      statusIcon = Icons.work_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailScreen(job: job),
            ),
          );
          if (mounted) await _refreshJobs();
        },
        onLongPress: () {
          _showJobDetail(job, isHired, isWaitlist, isPending, isAvailable);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.7), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: Color.lerp(statusColor, Colors.black, 0.25)!),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Color.lerp(statusColor, Colors.black, 0.25)!,
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '฿${NumberFormatter.formatCurrency(job.totalPay)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Job Title
              Text(
                job.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              // Hospital Name
              Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.hospitalName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Time
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(job.startTime)} - ${timeFormat.format(job.endTime)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${job.endTime.difference(job.startTime).inHours} ${context.tr('job_hours_suffix')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Location
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.hospitalAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetail(
    JobModel job,
    bool isHired,
    bool isWaitlist,
    bool isPending,
    bool isAvailable,
  ) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM yyyy');

    Color statusColor;
    String statusLabel;

    if (isHired) {
      if (job.status == JobStatus.completed) {
        statusColor = AppTheme.successColor;
        statusLabel = context.tr('calendar_completed');
      } else if (job.status == JobStatus.inProgress) {
        statusColor = AppTheme.infoColor;
        statusLabel = context.tr('calendar_in_progress');
      } else if (job.status == JobStatus.checkedIn) {
        statusColor = AppTheme.successColor;
        statusLabel = context.tr('calendar_checked_in');
      } else {
        statusColor = AppTheme.successColor;
        statusLabel = context.tr('calendar_hired_status');
      }
    } else if (isWaitlist) {
      statusColor = AppTheme.warningColor;
      statusLabel = context.tr('calendar_waitlist');
    } else if (isPending) {
      statusColor = AppTheme.infoColor;
      statusLabel = context.tr('calendar_pending');
    } else {
      statusColor = AppTheme.errorColor;
      statusLabel = context.tr('calendar_available');
    }

    // Check-in: Confirmed + same calendar day. Start work: CheckedIn.
    final now = DateTime.now();
    final isSameJobDay =
        now.year == job.startTime.year &&
        now.month == job.startTime.month &&
        now.day == job.startTime.day;
    final isCheckInReady =
        isHired && isSameJobDay && job.status.canCheckIn;
    final isStartWorkReady = isHired && job.status.canStartWork;
    final isCompleteWorkReady = isHired && job.status.canCompleteWork;
    final canCancelHired = isHired &&
        job.status != JobStatus.inProgress &&
        job.status != JobStatus.completed &&
        job.status != JobStatus.cancelled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.7), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHired ? Icons.check_circle : Icons.schedule,
                          size: 16,
                          color: Color.lerp(statusColor, Colors.black, 0.25)!,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Color.lerp(statusColor, Colors.black, 0.25)!,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details
                  _buildDetailRow(
                    icon: Icons.local_hospital,
                    label: context.tr('job_hospital'),
                    value: job.hospitalName,
                  ),
                  _buildDetailRow(
                    icon: Icons.location_on,
                    label: context.tr('job_location'),
                    value: job.hospitalAddress,
                  ),
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    label: context.tr('job_date'),
                    value: dateFormat.format(job.startTime),
                  ),
                  _buildDetailRow(
                    icon: Icons.access_time,
                    label: context.tr('job_time'),
                    value:
                        '${timeFormat.format(job.startTime)} - ${timeFormat.format(job.endTime)}',
                  ),
                  _buildDetailRow(
                    icon: Icons.timer,
                    label: context.tr('job_duration'),
                    value:
                        '${job.endTime.difference(job.startTime).inHours} ${context.tr('job_hours_suffix')}',
                  ),
                  _buildDetailRow(
                    icon: Icons.payments,
                    label: context.tr('job_pay'),
                    value: '฿${NumberFormatter.formatCurrency(job.totalPay)}',
                    valueColor: AppTheme.primaryColor,
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    context.tr('job_description'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // Skills Required
                  if (job.requiredSkills.isNotEmpty) ...[
                    Text(
                      context.tr('job_required_skills'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.requiredSkills
                          .map(
                            (skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                skill,
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Waitlist warning
                  if (isWaitlist) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.warningColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.warningColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('calendar_waitlist_hint'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.warningColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Pending job info
                  if (isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.infoColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.infoColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('calendar_pending_hint'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.infoColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Available job info
                  if (isAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.errorColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.errorColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('calendar_available_hint'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.errorColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  if (isHired) ...[
                    // Check-in Button (Confirmed + same day)
                    if (isCheckInReady) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _handleCheckIn(context, job.id);
                          },
                          icon: const Icon(Icons.login),
                          label: Text(context.tr('calendar_check_in')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Start Work (after check-in)
                    if (isStartWorkReady) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _handleStartWork(context, job.id);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(context.tr('calendar_start_work')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.infoColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Complete Work (after start)
                    if (isCompleteWorkReady) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _handleCompleteWork(context, job.id);
                          },
                          icon: const Icon(Icons.done_all),
                          label: Text(context.tr('calendar_complete_work')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isCheckInReady || isStartWorkReady) ...[
                      const SizedBox(height: 12),
                      // Warning separator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.warningColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('calendar_cancel_may_penalty'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.warningColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Cancel Job Button (for hired jobs only, before work starts)
                    if (canCancelHired) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCancelJobDialog(context, job);
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(context.tr('cancel')),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFC62828),
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ] else if (isWaitlist) ...[
                    // Withdraw from Waitlist Button (for waitlist jobs)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showWithdrawWaitlistDialog(context, job);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        label: Text(context.tr('calendar_withdraw_waitlist')),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Color(0xFFF57C00),
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Color(0xFFF57C00),
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (isAvailable) ...[
                    // Apply for Job Button (for available jobs)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showApplyJobDialog(context, job);
                        },
                        icon: const Icon(Icons.work),
                        label: Text(context.tr('job_apply')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(context.tr('close')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelJobDialog(BuildContext context, JobModel job) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM yyyy');
    final hoursUntilStart = job.startTime.difference(DateTime.now()).inHours;

    // Calculate penalty
    double penaltyAmount = 0;
    String penaltyMessage = '';

    if (hoursUntilStart < 0) {
      // Job has already started
      penaltyMessage = context.tr('calendar_cancel_started');
    } else if (hoursUntilStart < 24) {
      penaltyAmount = 100.0;
      penaltyMessage = context.tr('calendar_cancel_lt24');
    } else if (hoursUntilStart < 48) {
      penaltyAmount = 50.0;
      penaltyMessage = context.tr('calendar_cancel_lt48');
    } else {
      penaltyMessage = context.tr('calendar_cancel_ok');
    }

    if (hoursUntilStart < 0) {
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          icon: const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 48,
          ),
          title: Text(context.tr('error')),
          content: Text(
            context.l10n.isThai
                ? context.tr('calendar_cancel_too_late')
                : 'Job has started and cannot be cancelled.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(context.tr('ok')),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.errorColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('calendar_confirm_cancel'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.dividerColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Time until start
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.infoColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${context.tr('calendar_hours_left_prefix')} $hoursUntilStart ${context.tr('calendar_hours_left_suffix')}",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Penalty Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: penaltyAmount > 0
                      ? AppTheme.errorColor.withOpacity(0.1)
                      : AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: penaltyAmount > 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          penaltyAmount > 0
                              ? Icons.payment
                              : Icons.check_circle,
                          color: penaltyAmount > 0
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            penaltyMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: penaltyAmount > 0
                                      ? AppTheme.errorColor
                                      : AppTheme.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (penaltyAmount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.tr('calendar_penalty_from_wallet'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              
              const SizedBox(height: 16),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.warningColor, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('calendar_cancel_reliability'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reason TextField
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: context.tr('calendar_cancel_reason'),
                  hintText: context.tr('calendar_cancel_reason_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                maxLines: 3,
              ),

            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final jobProvider = context.read<JobProvider>();
                    final walletProvider = context.read<WalletProvider>();
                    final notificationProvider = context
                        .read<NotificationProvider>();

                    final result = await jobProvider.cancelHiredJob(
                      jobId: job.id,
                      staffId: (context.read<AuthProvider>().currentUser?.id ?? ''),
                      reason: reasonController.text.isNotEmpty
                          ? reasonController.text
                          : null,
                      onWaitlistPromoted: (promotedStaffId, jobId, jobTitle) {
                        // Create notification for the promoted staff
                        notificationProvider
                            .createWaitlistPromotionNotification(
                              staffId: promotedStaffId,
                              jobId: jobId,
                              jobTitle: jobTitle,
                            );
                      },
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading

                      if (result['success'] == true) {
                        final penalty = result['penalty_amount'] as double;
                        final promotedStaffId =
                            result['promoted_staff_id'] as String?;

                        // Apply penalty if needed
                        if (penalty > 0) {
                          await walletProvider.applyCancellationPenalty(
                            staffId: (context.read<AuthProvider>().currentUser?.id ?? ''),
                            jobId: job.id,
                            reason: '${context.tr('tx_penalty')}: ${job.title}',
                          );
                        }

                        // Refresh calendar data
                        await jobProvider.fetchMyHiredJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyWaitlistJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyPendingJobs((context.read<AuthProvider>().currentUser?.id ?? ''));

                        if (context.mounted) {
                          // Show success dialog with promotion info
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    context.tr('calendar_cancel_success'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  if (penalty > 0)
                                    Text(
                                      "${context.tr('calendar_penalty_prefix')} ${NumberFormatter.formatCurrency(penalty)} ${context.tr('calendar_penalty_suffix')}",
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    )
                                  else
                                    Text(
                                      context.tr('calendar_no_penalty'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  if (promotedStaffId != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.infoColor.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppTheme.infoColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: AppTheme.infoColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              promotedStaffId == (context.read<AuthProvider>().currentUser?.id ?? '')
                                                  ? context.tr('calendar_promoted_you')
                                                  : context.tr('calendar_promoted_other'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.infoColor,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              actions: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(context.tr('done')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      } else {
                        // Show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              jobProvider.error ??
                                  context.tr('calendar_cancel_error'),
                            ),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('confirm')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawWaitlistDialog(BuildContext context, JobModel job) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM yyyy');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: AppTheme.warningColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('calendar_withdraw_waitlist'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.dividerColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // No Penalty Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.successColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('calendar_withdraw_no_penalty'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.infoColor, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('calendar_withdraw_hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(context.tr('calendar_withdrawing')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    // Withdraw from waitlist
                    final jobProvider = context.read<JobProvider>();

                    final success = await jobProvider.withdrawFromWaitlist(
                      jobId: job.id,
                      staffId: (context.read<AuthProvider>().currentUser?.id ?? ''),
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading

                      if (success) {
                        // Refresh calendar data
                        await jobProvider.fetchMyHiredJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyWaitlistJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyPendingJobs((context.read<AuthProvider>().currentUser?.id ?? ''));

                        if (context.mounted) {
                          // Show success dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    context.tr('calendar_withdraw_success'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('calendar_withdraw_success_msg'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              actions: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(context.tr('done')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      } else {
                        // Show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              jobProvider.error ?? context.tr('calendar_withdraw_error'),
                            ),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF57C00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('calendar_withdraw')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showApplyJobDialog(BuildContext context, JobModel job) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM yyyy');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.work, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('calendar_confirm_apply'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.dividerColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.hospitalName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(job.startTime),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.payments,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '฿${NumberFormatter.formatCurrency(job.totalPay)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.infoColor, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('calendar_apply_hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog

                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(context.tr('calendar_applying')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    // Apply for job
                    final jobProvider = context.read<JobProvider>();

                    final success = await jobProvider.applyForJob(
                      jobId: job.id,
                      staffId: (context.read<AuthProvider>().currentUser?.id ?? ''),
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading

                      if (success) {
                        // Refresh calendar data
                        await jobProvider.fetchMyHiredJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyWaitlistJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchMyPendingJobs((context.read<AuthProvider>().currentUser?.id ?? ''));
                        await jobProvider.fetchJobs();

                        if (context.mounted) {
                          // Show success dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    context.tr('calendar_apply_success'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('calendar_apply_success_msg'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              actions: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(context.tr('done')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      } else {
                        // Show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              jobProvider.error ??
                                  context.tr('calendar_apply_error'),
                            ),
                            backgroundColor: AppTheme.errorColor,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('job_apply')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckIn(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(context.tr('calendar_check_in_title')),
        content: Text(context.tr('calendar_check_in_confirm')),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('close')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckInScreen(jobId: jobId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('calendar_check_in')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartWork(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(context.tr('calendar_start_work_title')),
        content: Text(context.tr('calendar_start_work_confirm')),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('close')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.infoColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('calendar_start_work')),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final jobProvider = context.read<JobProvider>();
    final ok = await jobProvider.startWork(jobId: jobId, staffId: _staffId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('calendar_start_work_success')
              : (jobProvider.error ?? context.tr('calendar_start_work_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );

    if (ok) await _refreshJobs();
  }

  Future<void> _handleCompleteWork(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(context.tr('calendar_complete_work_title')),
        content: Text(context.tr('calendar_complete_work_confirm')),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('close')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('calendar_complete_work')),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final jobProvider = context.read<JobProvider>();
    final ok = await jobProvider.completeWork(jobId: jobId, staffId: _staffId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('calendar_complete_work_success')
              : (jobProvider.error ??
                  context.tr('calendar_complete_work_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );

    if (ok) {
      await _refreshJobs();
      if (context.mounted) {
        await context.read<WalletProvider>().fetchWallet(_staffId);
      }
    }
  }

  // Helper methods
  List<JobModel> _getEventsForDay(DateTime day, List<JobModel> jobs) {
    return jobs.where((job) {
      return isSameDay(job.startTime, day);
    }).toList();
  }

  List<JobModel> _getJobsForDay(DateTime day, List<JobModel> jobs) {
    return jobs.where((job) {
      return isSameDay(job.startTime, day);
    }).toList();
  }
}
