import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_localizations.dart';
import '../../providers/auth_provider.dart';

/// Banner shown when staff account is not yet approved to take jobs.
class StaffApprovalBanner extends StatelessWidget {
  const StaffApprovalBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        if (user == null || user.canApplyForJobs) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        final Color bg;
        final Color fg;
        final String title;
        final String message;

        switch (user.status.toLowerCase()) {
          case 'rejected':
            bg = const Color(0xFFFFEBEE);
            fg = const Color(0xFFC62828);
            title = l10n.tr('approval_rejected_title');
            message = user.rejectionReason?.isNotEmpty == true
                ? user.rejectionReason!
                : l10n.tr('approval_rejected_body');
            break;
          case 'suspended':
            bg = const Color(0xFFFFF3E0);
            fg = const Color(0xFFE65100);
            title = l10n.tr('approval_suspended_title');
            message = user.rejectionReason?.isNotEmpty == true
                ? user.rejectionReason!
                : l10n.tr('approval_suspended_body');
            break;
          default:
            bg = const Color(0xFFFFF8E1);
            fg = const Color(0xFFF57F17);
            title = l10n.tr('approval_pending_title');
            message = l10n.tr('approval_pending_body');
        }

        return Material(
          color: bg,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 10 : 14,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: fg, size: compact ? 20 : 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 13 : 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: fg.withOpacity(0.9),
                          fontSize: compact ? 12 : 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StaffStatusChip extends StatelessWidget {
  const StaffStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (key) {
      case 'approved':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = l10n.tr('approval_status_approved');
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = l10n.tr('approval_status_rejected');
        break;
      case 'suspended':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = l10n.tr('approval_status_suspended');
        break;
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        label = l10n.tr('approval_status_pending');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
