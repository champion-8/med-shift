import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff_profile_model.dart';
import '../../models/skill_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/number_formatter.dart';
import '../../widgets/staff_approval_banner.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final profile = auth.currentUser;

        if (auth.isLoading && profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('profile_title'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('profile_title'))),
            body: Center(child: Text(context.tr('login_failed'))),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('profile_title')),
            actions: [
              // Language Toggle
              Consumer<LocaleProvider>(
                builder: (context, localeProvider, _) => IconButton(
                  icon: const Icon(Icons.language),
                  tooltip: context.tr('change_language'),
                  onPressed: localeProvider.toggleLocale,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => auth.refreshProfile(),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(profile: profile),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const StaffApprovalBanner(),
                // Profile Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: profile.resolvedProfileImageUrl != null
                            ? NetworkImage(profile.resolvedProfileImageUrl!)
                            : null,
                        child: profile.resolvedProfileImageUrl == null
                            ? Text(
                                '${profile.firstName.isNotEmpty ? profile.firstName[0] : '?'}${profile.lastName.isNotEmpty ? profile.lastName[0] : ''}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.fullName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.specialty,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      StaffStatusChip(status: profile.status),
                      if (profile.rejectionReason != null &&
                          profile.rejectionReason!.isNotEmpty &&
                          profile.status.toLowerCase() != 'approved') ...[
                        const SizedBox(height: 8),
                        Text(
                          profile.rejectionReason!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            NumberFormatter.formatNumber(profile.rating),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${profile.totalJobsCompleted} jobs)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reliability Score Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          color: _getReliabilityColor(profile.reliabilityScore),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ReliabilityGauge(
                                score: profile.reliabilityScore,
                                size: 88,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('profile_reliability_score'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getReliabilityColor(
                                          profile.reliabilityScore,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getReliabilityColor(
                                            profile.reliabilityScore,
                                          ).withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        _getReliabilityLevel(
                                          profile.reliabilityScore,
                                        ),
                                        style: TextStyle(
                                          color: _getReliabilityColor(
                                            profile.reliabilityScore,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: profile.reliabilityScore / 100,
                                        minHeight: 8,
                                        backgroundColor: AppTheme.dividerColor,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _getReliabilityColor(
                                                profile.reliabilityScore,
                                              ),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${NumberFormatter.formatNumber(profile.reliabilityScore)} / 100',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Statistics Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.attach_money,
                          title: context.tr('profile_earnings'),
                          value: NumberFormatter.formatCurrencyWhole(
                            profile.totalEarnings,
                          ),
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.check_circle,
                          title: context.tr('profile_completed_jobs'),
                          value: '${profile.totalJobsCompleted}',
                          color: AppTheme.infoColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.people,
                          title: context.tr('profile_referrals'),
                          value: '${profile.referralCount}',
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Verified Skills Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_verified_skills_title')),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                (profile.verifiedSkills.isNotEmpty
                                        ? profile.verifiedSkills
                                        : profile.skillNames)
                                    .map((skill) {
                                      return _buildSkillChip(context, skill);
                                    })
                                    .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Detailed Skills Section with Rates
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('skill_section')),
                      const SizedBox(height: 12),
                      ..._skillsFromProfile(
                        profile,
                      ).map((skill) => _buildDetailedSkillCard(context, skill)),
                      if (_skillsFromProfile(profile).isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 48,
                                    color: AppTheme.textSecondaryColor
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('skill_no_skills'),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditProfileScreen(
                                                profile: profile,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.add),
                                    label: Text(context.tr('skill_add')),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Contact Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_contact')),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              context,
                              Icons.email,
                              context.tr('profile_email'),
                              profile.email,
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildInfoTile(
                              context,
                              Icons.phone,
                              context.tr('profile_phone'),
                              profile.phone,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bank account
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('bank_title')),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              context,
                              Icons.account_balance,
                              context.tr('bank_name'),
                              profile.bankName?.isNotEmpty == true
                                  ? profile.bankName!
                                  : context.tr('profile_not_set'),
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildInfoTile(
                              context,
                              Icons.credit_card,
                              context.tr('bank_account_no'),
                              profile.bankAccountNumber?.isNotEmpty == true
                                  ? profile.bankAccountNumber!
                                  : '—',
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildInfoTile(
                              context,
                              Icons.badge_outlined,
                              context.tr('wallet_bank_name'),
                              profile.bankAccountName?.isNotEmpty == true
                                  ? profile.bankAccountName!
                                  : '—',
                            ),
                            const Divider(height: 1, indent: 56),
                            ListTile(
                              leading: Icon(
                                profile.bankAccountVerified
                                    ? Icons.verified
                                    : Icons.pending_outlined,
                                color: profile.bankAccountVerified
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                              ),
                              title: Text(
                                context.tr('profile_account_status'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                              subtitle: Text(
                                profile.bankAccountVerified
                                    ? context.tr('profile_verified')
                                    : context.tr('profile_unverified'),
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Current location
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_location')),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              context,
                              Icons.my_location,
                              context.tr('profile_coordinates'),
                              profile.currentLocationLat != null &&
                                      profile.currentLocationLng != null
                                  ? '${profile.currentLocationLat!.toStringAsFixed(5)}, ${profile.currentLocationLng!.toStringAsFixed(5)}'
                                  : context.tr('profile_location_unset'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Professional Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_professional')),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            _buildInfoTile(
                              context,
                              Icons.work,
                              context.tr('profile_specialty'),
                              profile.specialty,
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildInfoTile(
                              context,
                              Icons.badge,
                              context.tr('profile_license'),
                              profile.licenseNumber,
                            ),
                            const Divider(height: 1, indent: 56),
                            _buildInfoTile(
                              context,
                              Icons.access_time,
                              context.tr('profile_years_of_experience'),
                              '${profile.yearsExperience} years',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // All Skills Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_all_skills')),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.skills.map((skill) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  skill.name,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Certifications Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, context.tr('profile_certifications')),
                      const SizedBox(height: 12),
                      Card(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: profile.certifications.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(
                                Icons.verified_outlined,
                                color: AppTheme.primaryColor,
                              ),
                              title: Text(profile.certifications[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Availability Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: SwitchListTile(
                      title: Text(
                        context.tr('profile_available'),
                      ),
                      subtitle: Text(
                        profile.isAvailable
                            ? context.tr('profile_available_on')
                            : context.tr('profile_available_off'),
                      ),
                      value: profile.isAvailable,
                      activeColor: AppTheme.primaryColor,
                      onChanged: auth.isLoading
                          ? null
                          : (value) async {
                              final ok = await auth.setAvailability(value);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? (value
                                              ? context.tr('profile_available_on_snack')
                                              : context.tr('profile_available_off_snack'))
                                        : (auth.errorMessage ??
                                              context.tr('profile_update_failed')),
                                  ),
                                  backgroundColor: ok
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                ),
                              );
                            },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Logout Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            title: Text(
                              context.tr('logout'),
                            ),
                            content: Text(
                              context.tr('logout_confirm'),
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            actions: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        side: const BorderSide(
                                          color: AppTheme.primaryColor,
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(context.tr('cancel')),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(
                                        context.tr('logout'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          await authProvider.logout();
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(
                        context.tr('logout'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(
                          color: AppTheme.errorColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(BuildContext context, String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            skill,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<SkillModel> _skillsFromProfile(StaffProfileModel profile) =>
      profile.skills;

  // Build detailed skill card with rate and experience
  Widget _buildDetailedSkillCard(BuildContext context, SkillModel skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              skill.isVerified ? 32 : 16,
            ),
            child: Row(
              children: [
                // Skill Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              NumberFormatter.formatCurrencyWhole(skill.minRate > 0 ? skill.minRate : skill.maxRate) + context.tr('min_rate_suffix'),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppTheme.textSecondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('skill_experience_prefix') + ' ' + skill.experienceLabel(context.tr, trParams: context.trParams),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),
                          if (skill.certification != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.card_membership,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  skill.certification!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (skill.isVerified)
            Positioned(
              right: 12,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified,
                    size: 13,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    context.tr('profile_verified'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Mock profile removed — data comes from AuthProvider
  String _getReliabilityLevel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  Color _getReliabilityColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 75) return const Color(0xFF8BC34A);
    if (score >= 60) return const Color(0xFFFFA726);
    return const Color(0xFFE53935);
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
      ),
      subtitle: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Custom Reliability Gauge Widget
class ReliabilityGauge extends StatelessWidget {
  final double score;
  final double size;

  const ReliabilityGauge({super.key, required this.score, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0.0, 100.0);
    final color = _getGaugeColor(clampedScore);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clampedScore / 100,
              strokeWidth: size * 0.1,
              backgroundColor: AppTheme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                NumberFormatter.formatNumber(clampedScore),
                style: TextStyle(
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: size * 0.14,
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGaugeColor(double score) {
    if (score >= 90) return AppTheme.successColor;
    if (score >= 75) return const Color(0xFF66BB6A);
    if (score >= 60) return AppTheme.warningColor;
    if (score >= 40) return const Color(0xFFFFA726);
    return AppTheme.errorColor;
  }
}
