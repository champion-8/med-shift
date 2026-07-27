import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/job_model.dart';
import '../../providers/job_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/locale/app_localizations.dart';
import '../../core/enums/status_enums.dart';
import '../../utils/number_formatter.dart';
import '../../utils/maps_helper.dart';
import '../../widgets/staff_approval_banner.dart';
import '../check_in/check_in_screen.dart';
import 'package:intl/intl.dart';

class JobDetailScreen extends StatelessWidget {
  final JobModel job;

  const JobDetailScreen({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('job_detail_title')),
      ),
      body: Column(
        children: [
          const StaffApprovalBanner(compact: true),
          Expanded(
            child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: AppTheme.primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.hospitalName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pay',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                          ),
                          Text(
                            NumberFormatter.formatCurrencyWhole(job.totalPay),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Hourly Rate',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                          ),
                          Text(
                            '${NumberFormatter.formatCurrencyWhole(job.hourlyRate)}/hr',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Time Section
                  _buildSectionTitle(context, 'Schedule'),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today,
                    'Date',
                    dateFormat.format(job.startTime),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.access_time,
                    'Time',
                    '${timeFormat.format(job.startTime)} - ${timeFormat.format(job.endTime)}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.timer,
                    'Duration',
                    '${NumberFormatter.formatNumber(job.durationInHours)} hours',
                  ),

                  const SizedBox(height: 24),

                  // Location Section
                  _buildSectionTitle(context, 'Location'),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    context,
                    Icons.location_on,
                    'Address',
                    job.hospitalAddress,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Google Map (Mobile only)
                  if (!kIsWeb)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(job.latitude, job.longitude),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: MarkerId(job.id),
                              position: LatLng(job.latitude, job.longitude),
                              infoWindow: InfoWindow(
                                title: job.hospitalName,
                                snippet: job.hospitalAddress,
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              ),
                            ),
                          },
                          myLocationButtonEnabled: true,
                          myLocationEnabled: true,
                          zoomControlsEnabled: true,
                          mapType: MapType.normal,
                          onTap: (LatLng position) {
                            // Open in external maps app
                            _openInMaps(context, job);
                          },
                        ),
                      ),
                    ),
                  
                  // Web placeholder with coordinates
                  if (kIsWeb)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('maps_mobile_only'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.trParams('coords_label', {'lat': job.latitude.toStringAsFixed(4), 'lng': job.longitude.toStringAsFixed(4)}),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _openInMaps(context, job),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(context.tr('maps_open_google')),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Map Actions (Mobile only)
                  if (!kIsWeb)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openDirections(context, job),
                            icon: const Icon(Icons.directions, size: 20),
                            label: Text(context.tr('maps_directions')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showFullMap(context, job),
                            icon: const Icon(Icons.fullscreen, size: 20),
                            label: Text(context.tr('maps_fullscreen')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Description
                  _buildSectionTitle(context, 'Description'),
                  const SizedBox(height: 12),
                  Text(
                    job.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  // Required Skills
                  if (job.requiredSkills.isNotEmpty) ...[
                    _buildSectionTitle(context, 'Required Skills'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.requiredSkills.map((skill) => _buildSkillChip(skill)).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Certification
                  if (job.requiredCertification != null) ...[
                    _buildSectionTitle(context, 'Required Certification'),
                    const SizedBox(height: 12),
                    Text(
                      job.requiredCertification!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Status
                  _buildSectionTitle(context, 'Status'),
                  const SizedBox(height: 12),
                  _buildStatusChip(job.status),
                ],
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionBar(context),
    );
  }

  Widget? _buildActionBar(BuildContext context) {
    return Consumer2<JobProvider, AuthProvider>(
      builder: (context, jobs, auth, _) {
        final live = jobs.getJobById(job.id) ?? job;
        final isHired = jobs.isHiredJob(live.id);
        final now = DateTime.now();
        final sameDay = now.year == live.startTime.year &&
            now.month == live.startTime.month &&
            now.day == live.startTime.day;

        if (isHired) {
          final buttons = <Widget>[];
          if (sameDay && live.status.canCheckIn) {
            buttons.add(
              ElevatedButton.icon(
                onPressed: () => _openCheckIn(context, live.id),
                icon: const Icon(Icons.login),
                label: Text(context.tr('calendar_check_in')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }
          if (live.status.canStartWork) {
            buttons.add(
              ElevatedButton.icon(
                onPressed: () => _startWork(context, live.id),
                icon: const Icon(Icons.play_arrow),
                label: Text(context.tr('calendar_start_work')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.infoColor,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }
          if (live.status.canCompleteWork) {
            buttons.add(
              ElevatedButton.icon(
                onPressed: () => _completeWork(context, live.id),
                icon: const Icon(Icons.done_all),
                label: Text(context.tr('calendar_complete_work')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }
          if (live.status.canRateClinic && live.staffClinicRating == null) {
            buttons.add(
              ElevatedButton.icon(
                onPressed: () => _rateClinic(context, live.id),
                icon: const Icon(Icons.star_rate),
                label: Text(context.tr('job_rate_clinic')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFFED6C02),
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }
          if (live.status.canRateClinic && live.staffClinicRating != null) {
            buttons.add(
              Text(
                context.tr('job_rate_clinic_done').replaceAll(
                      '{rating}',
                      live.staffClinicRating!.toStringAsFixed(0),
                    ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            );
          }
          if (live.status.canReportIssue) {
            buttons.add(
              OutlinedButton.icon(
                onPressed: () => _reportIssue(context, live.id),
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(context.tr('job_report_issue')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: AppTheme.warningColor,
                  side: const BorderSide(color: AppTheme.warningColor, width: 2),
                ),
              ),
            );
          }
          if (buttons.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    buttons[i],
                  ],
                ],
              ),
            ),
          );
        }

        if (!live.isAvailable) return const SizedBox.shrink();

        final user = auth.currentUser;
        final approved = user?.status.toLowerCase() == 'approved';
        final available = user?.isAvailable ?? false;
        final canApply = approved && available;
        final blockedMsg = !approved
            ? context.tr('approval_apply_blocked')
            : context.tr('availability_apply_blocked');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: canApply
                  ? () => _applyForJob(context)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(blockedMsg)),
                      );
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor:
                    canApply ? AppTheme.primaryColor : Colors.grey.shade400,
                foregroundColor: Colors.white,
                elevation: 2,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(canApply ? context.tr('job_apply') : blockedMsg),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCheckIn(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(context.tr('calendar_check_in_title')),
        content: Text(context.tr('calendar_check_in_confirm')),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
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
                  ),
                  child: Text(context.tr('calendar_check_in')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckInScreen(jobId: jobId)),
    );
    if (context.mounted) {
      final staffId = context.read<AuthProvider>().currentUser?.id;
      if (staffId != null && staffId.isNotEmpty) {
        await context.read<JobProvider>().fetchMyHiredJobs(staffId);
      }
    }
  }

  Future<void> _startWork(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    final staffId = context.read<AuthProvider>().currentUser?.id;
    final jobs = context.read<JobProvider>();
    final ok = await jobs.startWork(jobId: jobId, staffId: staffId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('calendar_start_work_success')
              : (jobs.error ?? context.tr('calendar_start_work_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _completeWork(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    final staffId = context.read<AuthProvider>().currentUser?.id;
    final jobs = context.read<JobProvider>();
    final ok = await jobs.completeWork(jobId: jobId, staffId: staffId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('calendar_complete_work_success')
              : (jobs.error ?? context.tr('calendar_complete_work_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
    if (ok && context.mounted) {
      await context.read<WalletProvider>().fetchWallet(staffId);
    }
  }

  Future<void> _rateClinic(BuildContext context, String jobId) async {
    var rating = 5;
    final commentController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text(context.tr('job_rate_clinic_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('job_rate_clinic_hint')),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  return IconButton(
                    onPressed: () => setLocal(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFED6C02),
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr('job_rate_clinic_comment'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.tr('close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED6C02),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('job_rate_clinic_submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !context.mounted) return;
    final staffId = context.read<AuthProvider>().currentUser?.id;
    final jobs = context.read<JobProvider>();
    final ok = await jobs.rateClinic(
      jobId: jobId,
      rating: rating,
      comment: commentController.text,
      staffId: staffId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('job_rate_clinic_success')
              : (jobs.error ?? context.tr('job_rate_clinic_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _reportIssue(BuildContext context, String jobId) async {
    String category = 'Other';
    final descriptionController = TextEditingController();
    final categories = const [
      'Safety',
      'Equipment',
      'PatientCare',
      'Schedule',
      'Other',
    ];

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text(context.tr('job_report_issue')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.tr('job_report_category')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(context.tr('job_report_cat_$c')),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: context.tr('job_report_description'),
                    border: const OutlineInputBorder(),
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
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.tr('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('job_report_submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final description = descriptionController.text.trim();
    descriptionController.dispose();
    if (submitted != true || !context.mounted) return;

    if (description.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('job_report_description_short')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final jobs = context.read<JobProvider>();
    final ok = await jobs.reportJobIssue(
      jobId: jobId,
      category: category,
      description: description,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('job_report_success')
              : (jobs.error ?? context.tr('job_report_error')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryColor,
        ),
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
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(JobStatus status) {
    final baseColor = AppTheme.getJobStatusColor(status.value);
    final textColor = Color.lerp(baseColor, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.6), width: 1),
      ),
      child: Text(
        status.value,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  
  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  void _applyForJob(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user?.status.toLowerCase() != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('approval_apply_blocked'))),
      );
      return;
    }
    if (user?.isAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('availability_apply_blocked'))),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Job'),
        content: const Text(
          'Do you want to apply for this job? '
          'You will be notified if you are selected or placed on the waitlist.',
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
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
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final staffId = auth.currentUser?.id;
      if (staffId == null || staffId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in again')),
        );
        return;
      }

      final jobProvider = context.read<JobProvider>();
      final success = await jobProvider.applyForJob(
        jobId: job.id,
        staffId: staffId,
      );

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(jobProvider.error ?? 'Failed to apply'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _openInMaps(BuildContext context, JobModel job) async {
    final ok = await MapsHelper.openLocation(
      latitude: job.latitude,
      longitude: job.longitude,
      label: job.displayName,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('maps_open_failed'))),
      );
    }
  }

  Future<void> _openDirections(BuildContext context, JobModel job) async {
    final ok = await MapsHelper.openDirections(
      latitude: job.latitude,
      longitude: job.longitude,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('maps_open_failed'))),
      );
    }
  }

  void _showFullMap(BuildContext context, JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullMapScreen(job: job),
      ),
    );
  }
}

// Full screen map view
class FullMapScreen extends StatefulWidget {
  final JobModel job;

  const FullMapScreen({super.key, required this.job});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  late GoogleMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.hospitalName),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(widget.job.latitude, widget.job.longitude),
                  15,
                ),
              );
            },
            tooltip: context.tr('maps_recenter'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.job.latitude, widget.job.longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId(widget.job.id),
            position: LatLng(widget.job.latitude, widget.job.longitude),
            infoWindow: InfoWindow(
              title: widget.job.hospitalName,
              snippet: widget.job.hospitalAddress,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        },
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        zoomControlsEnabled: true,
        mapType: MapType.normal,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'directions',
            onPressed: () => MapsHelper.openDirections(
              latitude: widget.job.latitude,
              longitude: widget.job.longitude,
            ),
            child: const Icon(Icons.directions),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'info',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.errorColor,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.job.hospitalName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.map, size: 20, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.job.hospitalAddress,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 20, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Lat: ${widget.job.latitude.toStringAsFixed(6)}, '
                              'Lng: ${widget.job.longitude.toStringAsFixed(6)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            MapsHelper.openDirections(
                              latitude: widget.job.latitude,
                              longitude: widget.job.longitude,
                            );
                          },
                          icon: const Icon(Icons.directions),
                          label: Text(context.tr('maps_directions')),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
            label: Text(context.tr('maps_place_info')),
          ),
        ],
      ),
    );
  }
}

