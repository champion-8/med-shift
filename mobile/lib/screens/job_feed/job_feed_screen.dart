import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/job_model.dart';
import '../../models/notification_model.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/smart_route_helper.dart';
import '../../utils/number_formatter.dart';
import '../job_detail/job_detail_screen.dart';
import '../notifications/notification_screen.dart';
import '../../widgets/staff_approval_banner.dart';
import 'package:intl/intl.dart';

class JobFeedScreen extends StatefulWidget {
  const JobFeedScreen({super.key});

  @override
  State<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends State<JobFeedScreen> {
  double? _maxDistanceKm; // null = any
  String _skillQuery = '';
  bool _meetReliabilityOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final staffId = auth.currentUser?.id;
      context.read<JobProvider>().fetchJobs();
      if (staffId != null && staffId.isNotEmpty) {
        context.read<NotificationProvider>().fetchNotifications(staffId);
      }
    });
  }

  List<JobModel> _filterJobs(
    List<JobModel> jobs, {
    required double reliability,
    required double currentLat,
    required double currentLng,
  }) {
    return jobs.where((job) {
      if (_meetReliabilityOnly && reliability < job.minReliabilityScore) {
        return false;
      }
      final skill = _skillQuery.trim().toLowerCase();
      if (skill.isNotEmpty) {
        final hay = [
          job.title,
          job.description,
          ...job.requiredSkills,
        ].join(' ').toLowerCase();
        if (!hay.contains(skill)) return false;
      }
      if (_maxDistanceKm != null) {
        final km = SmartRouteHelper.calculateDistance(
          startLat: currentLat,
          startLng: currentLng,
          endLat: job.latitude,
          endLng: job.longitude,
        );
        if (km > _maxDistanceKm!) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showFilterSheet({
    required double reliability,
  }) async {
    double? draftDistance = _maxDistanceKm;
    final skillCtrl = TextEditingController(text: _skillQuery);
    var draftReliability = _meetReliabilityOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('job_feed_filter'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('job_feed_filter_distance')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.tr('job_feed_filter_any')),
                        selected: draftDistance == null,
                        onSelected: (_) => setModal(() => draftDistance = null),
                      ),
                      for (final km in [5.0, 10.0, 20.0, 50.0])
                        ChoiceChip(
                          label: Text('${km.toInt()} km'),
                          selected: draftDistance == km,
                          onSelected: (_) =>
                              setModal(() => draftDistance = km),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: skillCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('job_feed_filter_skill'),
                      hintText: context.tr('job_feed_filter_skill_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('job_feed_filter_reliability')),
                    subtitle: Text(
                      '${context.tr('job_feed_filter_reliability_sub')} (${reliability.toInt()}%)',
                    ),
                    value: draftReliability,
                    onChanged: (v) => setModal(() => draftReliability = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _maxDistanceKm = null;
                              _skillQuery = '';
                              _meetReliabilityOnly = false;
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(context.tr('job_feed_filter_clear')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _maxDistanceKm = draftDistance;
                              _skillQuery = skillCtrl.text.trim();
                              _meetReliabilityOnly = draftReliability;
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(context.tr('job_feed_filter_apply')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    skillCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.currentUser;
    final reliability = profile?.reliabilityScore ?? 75.0;
    final currentLat = profile?.currentLocationLat ?? 13.7563;
    final currentLng = profile?.currentLocationLng ?? 100.5018;
    final hasFilter = _maxDistanceKm != null ||
        _skillQuery.isNotEmpty ||
        _meetReliabilityOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('job_feed_title')),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(reliability: reliability),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<JobProvider>().fetchJobs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const StaffApprovalBanner(),
          Expanded(
            child: Consumer<JobProvider>(
              builder: (context, jobProvider, child) {
                if (jobProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (jobProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          jobProvider.error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            jobProvider.clearError();
                            jobProvider.fetchJobs();
                          },
                          child: Text(context.tr('ok')),
                        ),
                      ],
                    ),
                  );
                }

                final jobs = _filterJobs(
                  jobProvider.availableJobs,
                  reliability: reliability,
                  currentLat: currentLat,
                  currentLng: currentLng,
                );

                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.work_off_outlined,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('job_feed_empty'),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('job_feed_empty_subtitle'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (hasFilter) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _maxDistanceKm = null;
                                _skillQuery = '';
                                _meetReliabilityOnly = false;
                              });
                            },
                            child: Text(context.tr('job_feed_filter_clear')),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Consumer<NotificationProvider>(
                  builder: (context, notificationProvider, _) {
                    final unreadNewJobIds = notificationProvider.notifications
                        .where((n) =>
                            n.type == NotificationType.newJob &&
                            !n.isRead &&
                            n.jobId != null)
                        .map((n) => n.jobId!)
                        .toSet();

                    return RefreshIndicator(
                      onRefresh: () => jobProvider.fetchJobs(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];

                          return JobCard(
                            job: job,
                            currentLat: currentLat,
                            currentLng: currentLng,
                            userReliabilityScore: reliability,
                            hasUnreadNotification:
                                unreadNewJobIds.contains(job.id),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobDetailScreen(job: job),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class JobCard extends StatelessWidget {
  final JobModel job;
  final double? currentLat;
  final double? currentLng;
  final double userReliabilityScore;
  final bool hasUnreadNotification;
  final VoidCallback onTap;

  const JobCard({
    super.key,
    required this.job,
    this.currentLat,
    this.currentLng,
    required this.userReliabilityScore,
    this.hasUnreadNotification = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    String? travelInfo;
    if (currentLat != null && currentLng != null) {
      travelInfo = SmartRouteHelper.getTravelInfo(
        startLat: currentLat!,
        startLng: currentLng!,
        endLat: job.latitude,
        endLng: job.longitude,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Stack(
        children: [
          InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Clinic Name, Job Title, and Price Badge
              Text(
                job.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                job.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 12),

              // Smart Route Row
              if (travelInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.infoColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 20,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          travelInfo,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.navigation,
                        size: 18,
                        color: AppTheme.infoColor,
                      ),
                    ],
                  ),
                ),
                // const SizedBox(height: 12),
              ],

              // Reliability Badge
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //   decoration: BoxDecoration(
              //     color: meetsReliability
              //         ? AppTheme.successColor.withOpacity(0.1)
              //         : AppTheme.warningColor.withOpacity(0.1),
              //     borderRadius: BorderRadius.circular(8),
              //     border: Border.all(
              //       color: meetsReliability
              //           ? AppTheme.successColor.withOpacity(0.3)
              //           : AppTheme.warningColor.withOpacity(0.3),
              //     ),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Icon(
              //         meetsReliability ? Icons.verified : Icons.info_outline,
              //         size: 18,
              //         color: meetsReliability
              //             ? AppTheme.successColor
              //             : AppTheme.warningColor,
              //       ),
              //       const SizedBox(width: 6),
              //       Flexible(
              //         child: Text(
              //           meetsReliability
              //               ? context.tr('job_available')
              //               : '${context.tr('job_feed_filter')}: ${job.minReliabilityScore.toInt()}% ${context.l10n.isThai ? 'à¸„à¸§à¸²à¸¡à¸™à¹ˆà¸²à¹€à¸Šà¸·à¹ˆà¸­à¸–à¸·à¸­' : 'Reliability'}',
              //           style: Theme.of(context).textTheme.bodySmall?.copyWith(
              //                 color: meetsReliability
              //                     ? AppTheme.successColor
              //                     : AppTheme.warningColor,
              //                 fontWeight: FontWeight.w600,
              //               ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),


              // Skills Preview
              if (job.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: job.requiredSkills.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        skill,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Date & Time + Price Badge (bottom row)
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(job.startTime),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${timeFormat.format(job.startTime)} - ${timeFormat.format(job.endTime)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      NumberFormatter.formatCurrencyWhole(job.totalPay),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
          
          // Red triangle badge for new jobs with unread notification
          if (hasUnreadNotification)
            Positioned(
              top: 0,
              right: 0,
              child: ClipPath(
                clipper: _TriangleClipper(),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5, right: 2),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Transform.rotate(
                        angle: 0.785398, // 45 degrees in radians
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom clipper for triangle shape in top-right corner
class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0); // Top-right
    path.lineTo(size.width, size.height); // Bottom-right
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
