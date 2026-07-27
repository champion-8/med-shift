import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/check_in_requirement_model.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/smart_route_helper.dart';
import '../../core/locale/app_localizations.dart';

class CheckInScreen extends StatefulWidget {
  final String jobId;

  const CheckInScreen({super.key, required this.jobId});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int _currentStepIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _canProceed = false;
  bool _isLocating = false;
  double? _checkInLat;
  double? _checkInLng;
  double? _checkInAccuracy;

  @override
  void initState() {
    super.initState();
    
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().startCheckInSession(widget.jobId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
          _canProceed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await _showExitConfirmation();
        if (shouldExit == true && context.mounted) {
          context.read<NotificationProvider>().cancelCheckInSession();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('checkin_title_job')),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldExit = await _showExitConfirmation();
              if (shouldExit == true && context.mounted) {
                context.read<NotificationProvider>().cancelCheckInSession();
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.currentCheckInSession == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final session = provider.currentCheckInSession;
            if (session == null) {
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
                      provider.error ?? context.tr('checkin_load_error'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('back')),
                    ),
                  ],
                ),
              );
            }

            // No clinic docs required — confirm check-in directly
            if (session.requirements.isEmpty) {
              return _buildEmptyRequirementsCheckIn(provider);
            }

            final currentRequirement = session.requirements[_currentStepIndex];

            return Column(
              children: [
                // Progress Bar
                _buildProgressBar(session),

                // Step Indicator
                _buildStepIndicator(session),

                // Content
                Expanded(
                  child: _buildStepContent(currentRequirement, session),
                ),

                // Bottom Navigation
                _buildBottomNavigation(session, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar(CheckInSession session) {
    final progress = (_currentStepIndex + 1) / session.requirements.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.trParams('checkin_step_of', {'current': '${_currentStepIndex + 1}', 'total': '${session.requirements.length}'}),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(CheckInSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        border: const Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Step ${_currentStepIndex + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              session.requirements[_currentStepIndex].title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    CheckInRequirementModel requirement,
    CheckInSession session,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          SelectableText(
            requirement.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),

          const SizedBox(height: 24),

          // Scroll instruction
          if (!_hasScrolledToBottom)
            Container(
              padding: const EdgeInsets.all(16),
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
                    Icons.arrow_downward,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('checkin_read_scroll'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.successColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('checkin_read_complete'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(
    CheckInSession session,
    NotificationProvider provider,
  ) {
    final isLastStep = _currentStepIndex == session.requirements.length - 1;
    final currentRequirement = session.requirements[_currentStepIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor,
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLastStep) ...[
              _buildLocationCard(),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                // Back Button
                if (_currentStepIndex > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentStepIndex--;
                          _hasScrolledToBottom = false;
                          _canProceed = false;
                          _scrollController.jumpTo(0);
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.tr('back')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                if (_currentStepIndex > 0) const SizedBox(width: 12),

                // Next/Complete Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _canProceed && !_isLocating
                        ? () => _handleNextOrComplete(
                              session,
                              currentRequirement,
                              provider,
                              isLastStep,
                            )
                        : null,
                    icon: Icon(
                        isLastStep ? Icons.check_circle : Icons.arrow_forward),
                    label: Text(isLastStep ? context.tr('checkin_now') : context.tr('next')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor:
                          _canProceed ? const Color(0xFF2E7D32) : Colors.grey[400],
                      foregroundColor: Colors.white,
                      elevation: _canProceed ? 2 : 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRequirementsCheckIn(NotificationProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fact_check_outlined,
            size: 72,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('checkin_ready'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('checkin_no_docs_body'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: 24),
          _buildLocationCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading || _isLocating
                  ? null
                  : () => _completeCheckIn(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(provider.isLoading ? context.tr('checkin_saving') : context.tr('checkin_confirm')),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              provider.cancelCheckInSession();
              Navigator.pop(context);
            },
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }

  void _handleNextOrComplete(
    CheckInSession session,
    CheckInRequirementModel requirement,
    NotificationProvider provider,
    bool isLastStep,
  ) {
    // Mark current step as completed
    provider.completeStep(requirement.id);

    if (isLastStep) {
      // Complete check-in
      _completeCheckIn(provider);
    } else {
      // Move to next step
      setState(() {
        _currentStepIndex++;
        _hasScrolledToBottom = false;
        _canProceed = false;
        _scrollController.jumpTo(0);
      });
    }
  }

  Widget _buildLocationCard() {
    final hasFix = _checkInLat != null && _checkInLng != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasFix
              ? AppTheme.successColor.withOpacity(0.4)
              : AppTheme.textSecondaryColor.withOpacity(0.25),
        ),
        borderRadius: BorderRadius.circular(4),
        color: hasFix
            ? AppTheme.successColor.withOpacity(0.06)
            : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFix ? Icons.location_on : Icons.location_searching,
                color: hasFix ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasFix
                      ? '${_checkInLat!.toStringAsFixed(5)}, ${_checkInLng!.toStringAsFixed(5)}'
                      : context.tr('checkin_geo_within'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLocating ? null : _captureLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_isLocating ? context.tr('checkin_locating') : context.tr('checkin_use_location')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    final position = await SmartRouteHelper.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('checkin_location_denied')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _checkInLat = position.latitude;
      _checkInLng = position.longitude;
      _checkInAccuracy = position.accuracy;
    });
  }

  Future<void> _completeCheckIn(NotificationProvider provider) async {
    if (_checkInLat == null || _checkInLng == null) {
      await _captureLocation();
      if (_checkInLat == null || _checkInLng == null) return;
    }

    // Show loading dialog
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
                Text(context.tr('checkin_saving_detail')),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await provider.completeCheckIn(
      widget.jobId,
      latitude: _checkInLat!,
      longitude: _checkInLng!,
      accuracyMeters: _checkInAccuracy,
    );

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
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
                  context.tr('checkin_success_title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('checkin_success_body_full'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close success dialog
                    Navigator.pop(context); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('checkin_done')),
                ),
              ),
            ],
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? context.tr('checkin_error')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(context.tr('checkin_cancel_title')),
        content: Text(
          context.tr('checkin_cancel_body_full'),
        ),
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
                  child: Text(context.tr('checkin_continue')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
