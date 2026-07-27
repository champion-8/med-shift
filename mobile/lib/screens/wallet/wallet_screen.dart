import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/job_model.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

enum TransactionFilter { all, earnings, withdrawals, penalties }

enum DateFilter { all, today, lastWeek, lastMonth, last3Months, custom }

class _WalletScreenState extends State<WalletScreen> {
  TransactionFilter _selectedFilter = TransactionFilter.all;
  DateFilter _selectedDateFilter = DateFilter.all;
  DateTimeRange? _selectedDateRange;

  String? get _staffId => context.read<AuthProvider>().currentUser?.id;

  Future<void> _refreshWallet() async {
    final staffId = _staffId;
    if (staffId == null || staffId.isEmpty) return;
    final walletProvider = context.read<WalletProvider>();
    final jobProvider = context.read<JobProvider>();
    await walletProvider.fetchWallet(staffId);
    await jobProvider.fetchJobs();
    await jobProvider.fetchMyHiredJobs(staffId);
    await jobProvider.fetchMyWaitlistJobs(staffId);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('wallet_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Download Income Certificate',
            onPressed: () {
              _showIncomeCertificateDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshWallet();
            },
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading && walletProvider.transactions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshWallet,
            child: CustomScrollView(
              slivers: [
                // Balance Card
                SliverToBoxAdapter(
                  child: _buildBalanceCard(context, walletProvider),
                ),

                // Summary Cards
                SliverToBoxAdapter(
                  child: _buildSummaryCards(context, walletProvider),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: _buildFilterChips(context),
                ),

                // Transactions Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction History',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${_getFilteredTransactions(walletProvider.transactions).length} items',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transaction List
                _buildFilteredTransactionList(context, walletProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTransactionTap(BuildContext context, TransactionModel transaction) {
    // Only navigate if transaction has a job ID
    if (transaction.jobId == null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('ธุรกรรมนี้ไม่มีข้อมูลงาน'),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
      return;
    }

    final jobProvider = context.read<JobProvider>();
    
    // Try to get job from different sources
    JobModel? job = jobProvider.getJobById(transaction.jobId!);
    
    // If not found in all jobs, try to find in hired or waitlist jobs
    if (job == null) {
      // Try to find in hired jobs
      try {
        job = jobProvider.myHiredJobs.firstWhere(
          (j) => j.id == transaction.jobId,
        );
      } catch (e) {
        // Not found in hired jobs, try waitlist
        try {
          job = jobProvider.myWaitlistJobs.firstWhere(
            (j) => j.id == transaction.jobId,
          );
        } catch (e) {
          // Not found anywhere
          job = null;
        }
      }
    }

    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('wallet_job_not_found')),
          backgroundColor: AppTheme.warningColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show job detail modal
    _showJobDetailModal(context, job, transaction);
  }

  void _showJobDetailModal(BuildContext context, JobModel job, TransactionModel transaction) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('d MMM yyyy');
    
    // Determine job status from transaction type and current state
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    switch (transaction.type) {
      case TransactionType.payment:
        statusColor = AppTheme.successColor;
        statusLabel = context.tr('tx_payment');
        statusIcon = Icons.check_circle;
        break;
      case TransactionType.penalty:
        statusColor = AppTheme.errorColor;
        statusLabel = context.tr('tx_penalty');
        statusIcon = Icons.warning_amber_rounded;
        break;
      case TransactionType.refund:
        statusColor = AppTheme.infoColor;
        statusLabel = context.tr('tx_refund');
        statusIcon = Icons.replay;
        break;
      case TransactionType.bonus:
        statusColor = AppTheme.warningColor;
        statusLabel = context.tr('tx_bonus');
        statusIcon = Icons.star;
        break;
      case TransactionType.withdrawal:
        statusColor = AppTheme.infoColor;
        statusLabel = context.tr('tx_withdrawal');
        statusIcon = Icons.account_balance;
        break;
      case TransactionType.deposit:
        statusColor = AppTheme.successColor;
        statusLabel = context.tr('tx_negative_pay');
        statusIcon = Icons.lock_open;
        break;
    }

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

                // Transaction Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withOpacity(0.7),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: Color.lerp(statusColor, Colors.black, 0.25)!,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Color.lerp(statusColor, Colors.black, 0.25)!,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Transaction Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: transaction.isNegative 
                        ? AppTheme.errorColor.withOpacity(0.1)
                        : AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: transaction.isNegative 
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('wallet_amount'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        transaction.formattedAmount,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: transaction.isNegative
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Job Title
                Text(
                  job.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 24),

                // Details
                _buildDetailRow(
                  context,
                  icon: Icons.local_hospital,
                  label: context.tr('job_hospital'),
                  value: job.hospitalName,
                ),
                _buildDetailRow(
                  context,
                  icon: Icons.location_on,
                  label: context.tr('job_location'),
                  value: job.hospitalAddress,
                ),
                _buildDetailRow(
                  context,
                  icon: Icons.calendar_today,
                  label: context.tr('job_date'),
                  value: dateFormat.format(job.startTime),
                ),
                _buildDetailRow(
                  context,
                  icon: Icons.access_time,
                  label: context.tr('job_time'),
                  value:
                      '${timeFormat.format(job.startTime)} - ${timeFormat.format(job.endTime)}',
                ),
                _buildDetailRow(
                  context,
                  icon: Icons.timer,
                  label: context.tr('job_duration'),
                  value:
                      '${job.endTime.difference(job.startTime).inHours} ${context.tr('job_hours_suffix')}',
                ),
                _buildDetailRow(
                  context,
                  icon: Icons.payments,
                  label: context.tr('job_pay'),
                  value: '฿${NumberFormatter.formatCurrency(job.totalPay)}',
                  valueColor: AppTheme.primaryColor,
                ),

                const SizedBox(height: 24),

                // Description
                Text(
                  context.tr('job_details_title'),
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
                              style: const TextStyle(
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

                // Transaction Info
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: AppTheme.infoColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('wallet_transaction_detail'),
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppTheme.infoColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        transaction.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.infoColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('wallet_transaction_date') + ' ' + DateFormat('d MMM yyyy HH:mm').format(transaction.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.infoColor,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Download Receipt Button (for penalties)
                if (transaction.type == TransactionType.penalty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadReceipt(context, transaction),
                      icon: const Icon(Icons.download),
                      label: Text(context.tr('wallet_download_receipt')),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
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

  Widget _buildDetailRow(
    BuildContext context, {
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
          Icon(
            icon,
            size: 20,
            color: AppTheme.textSecondaryColor,
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

  Widget _buildBalanceCard(BuildContext context, WalletProvider provider) {
    final hasNegativeBalance = provider.hasNegativeBalance;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasNegativeBalance
              ? [AppTheme.errorColor, const Color(0xFFD32F2F)]
              : [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: (hasNegativeBalance
                    ? AppTheme.errorColor
                    : AppTheme.primaryColor)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + icon on same row
          Row(
            children: [
              Text(
                context.tr('wallet_balance'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasNegativeBalance
                      ? Icons.warning_rounded
                      : Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amount full-width right-aligned
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '฿${NumberFormatter.formatCurrency(provider.balance.abs())}',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: hasNegativeBalance ? Colors.red[200] : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 48,
                  ),
            ),
          ),
          if (hasNegativeBalance) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Account Limited',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account has a negative balance. Complete jobs or pay to unlock full access.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showPaymentDialog(context, provider);
                      },
                      icon: const Icon(Icons.payment),
                      label: Text(context.tr('wallet_pay_unlock')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.errorColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showWithdrawDialog(context, provider);
                    },
                    icon: const Icon(Icons.account_balance),
                    label: Text(context.tr('wallet_withdraw')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account in good standing',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WalletProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              context,
              'Total Earnings',
              NumberFormatter.formatCurrencyWhole(provider.totalEarnings),
              AppTheme.successColor,
              Icons.trending_up,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              context,
              'Total Penalties',
              NumberFormatter.formatCurrencyWhole(provider.totalPenalties),
              AppTheme.errorColor,
              Icons.trending_down,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
              FilterChip(
                label: Text(context.tr('wallet_filter_all')),
                selected: _selectedFilter == TransactionFilter.all,
                labelStyle: TextStyle(
                  color: _selectedFilter == TransactionFilter.all
                      ? Color.lerp(AppTheme.primaryColor, Colors.black, 0.45)!
                      : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = TransactionFilter.all;
                  });
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: Color.lerp(AppTheme.primaryColor, Colors.black, 0.35)!,
                side: BorderSide(
                  color: _selectedFilter == TransactionFilter.all
                      ? AppTheme.primaryColor
                      : AppTheme.dividerColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(context.tr('wallet_filter_earnings')),
                selected: _selectedFilter == TransactionFilter.earnings,
                labelStyle: TextStyle(
                  color: _selectedFilter == TransactionFilter.earnings
                      ? Color.lerp(AppTheme.successColor, Colors.black, 0.35)!
                      : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = TransactionFilter.earnings;
                  });
                },
                selectedColor: AppTheme.successColor.withOpacity(0.2),
                checkmarkColor: Color.lerp(AppTheme.successColor, Colors.black, 0.25)!,
                side: BorderSide(
                  color: _selectedFilter == TransactionFilter.earnings
                      ? AppTheme.successColor
                      : AppTheme.dividerColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(context.tr('wallet_filter_withdrawals')),
                selected: _selectedFilter == TransactionFilter.withdrawals,
                labelStyle: TextStyle(
                  color: _selectedFilter == TransactionFilter.withdrawals
                      ? Color.lerp(AppTheme.infoColor, Colors.black, 0.35)!
                      : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = TransactionFilter.withdrawals;
                  });
                },
                selectedColor: AppTheme.infoColor.withOpacity(0.2),
                checkmarkColor: Color.lerp(AppTheme.infoColor, Colors.black, 0.25)!,
                side: BorderSide(
                  color: _selectedFilter == TransactionFilter.withdrawals
                      ? AppTheme.infoColor
                      : AppTheme.dividerColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(context.tr('wallet_filter_penalties')),
                selected: _selectedFilter == TransactionFilter.penalties,
                labelStyle: TextStyle(
                  color: _selectedFilter == TransactionFilter.penalties
                      ? Color.lerp(AppTheme.errorColor, Colors.black, 0.25)!
                      : AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = TransactionFilter.penalties;
                  });
                },
                selectedColor: AppTheme.errorColor.withOpacity(0.2),
                checkmarkColor: Color.lerp(AppTheme.errorColor, Colors.black, 0.15)!,
                side: BorderSide(
                  color: _selectedFilter == TransactionFilter.penalties
                      ? AppTheme.errorColor
                      : AppTheme.dividerColor,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDateFilterSheet(context),
                  icon: Icon(
                    _selectedDateFilter != DateFilter.all ? Icons.date_range : Icons.calendar_today,
                    size: 18,
                  ),
                  label: Text(_getDateFilterLabel(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _selectedDateFilter != DateFilter.all
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    side: BorderSide(
                      color: _selectedDateFilter != DateFilter.all
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor,
                      width: 1.5,
                    ),
                    backgroundColor: _selectedDateFilter != DateFilter.all
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              // if (_selectedDateFilter != DateFilter.all) ...[
              //   const SizedBox(width: 8),
              //   Expanded(
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //         decoration: BoxDecoration(
              //           color: AppTheme.primaryColor.withOpacity(0.1),
              //           borderRadius: BorderRadius.circular(4),
              //           border: Border.all(
              //             color: AppTheme.primaryColor,
              //             width: 1.5,
              //           ),
              //         ),
              //         child: Row(
              //           children: [
              //             const Icon(
              //               Icons.date_range,
              //               size: 16,
              //               color: AppTheme.primaryColor,
              //             ),
              //             const SizedBox(width: 8),
              //             Expanded(
              //               child: Text(
              //                 _getDateFilterRangeText(),
              //                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
              //                       color: AppTheme.primaryColor,
              //                       fontWeight: FontWeight.bold,
              //                     ),
              //                 overflow: TextOverflow.ellipsis,
              //               ),
              //             ),
              //             const SizedBox(width: 4),
              //             InkWell(
              //               onTap: () {
              //                 setState(() {
              //                   _selectedDateFilter = DateFilter.all;
              //                   _selectedDateRange = null;
              //                 });
              //               },
              //               child: const Icon(
              //                 Icons.close,
              //                 size: 16,
              //                 color: AppTheme.primaryColor,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              // ],
            ],
          ),
        ],
      ),
    );
  }

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> transactions) {
    var filtered = transactions;
    
    // Filter by type
    switch (_selectedFilter) {
      case TransactionFilter.all:
        break;
      case TransactionFilter.earnings:
        filtered = filtered.where((t) => 
          t.type == TransactionType.payment || t.type == TransactionType.bonus
        ).toList();
        break;
      case TransactionFilter.withdrawals:
        filtered = filtered.where((t) => t.type == TransactionType.withdrawal).toList();
        break;
      case TransactionFilter.penalties:
        filtered = filtered.where((t) => 
          t.type == TransactionType.penalty || t.type == TransactionType.refund
        ).toList();
        break;
    }
    
    // Filter by date range
    final range = _getActiveDateRange();
    if (range != null) {
      final startDate = DateTime(range.start.year, range.start.month, range.start.day);
      final endDate = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      
      filtered = filtered.where((t) {
        final createdAt = t.createdAt;
        return createdAt.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
               createdAt.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();
    }
    
    return filtered;
  }

  String _getDateFilterLabel(BuildContext context) {
    switch (_selectedDateFilter) {
      case DateFilter.all:
        return context.tr('wallet_filter_date_btn');
      case DateFilter.today:
        return context.tr('wallet_today');
      case DateFilter.lastWeek:
        return context.tr('wallet_last_week');
      case DateFilter.lastMonth:
        return context.tr('wallet_last_month');
      case DateFilter.last3Months:
        return context.tr('wallet_last_3months');
      case DateFilter.custom:
        return context.tr('wallet_custom_period');
    }
  }

  String _getDateFilterRangeText() {
    final range = _getActiveDateRange();
    if (range == null) return '';
    final fmt = DateFormat('d MMM yyyy');
    if (_selectedDateFilter == DateFilter.today) {
      return fmt.format(range.start);
    }
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  DateTimeRange? _getActiveDateRange() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case DateFilter.all:
        return null;
      case DateFilter.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
      case DateFilter.lastWeek:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case DateFilter.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, now.day),
          end: now,
        );
      case DateFilter.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: now,
        );
      case DateFilter.custom:
        return _selectedDateRange;
    }
  }

  void _showDateFilterSheet(BuildContext context) {
    final outerContext = context; // capture before sheet opens
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 16),
                    Text(
                      sheetContext.tr('wallet_filter_date_title'),
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildDateFilterOptions(sheetContext, outerContext),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDateFilterOptions(BuildContext sheetContext, BuildContext outerContext) {
    final options = [
      (DateFilter.all, Icons.clear_all, outerContext.tr('wallet_filter_all'), outerContext.tr('wallet_filter_all_sub')),
      (DateFilter.today, Icons.today, outerContext.tr('wallet_today'), outerContext.tr('wallet_filter_today_sub')),
      (DateFilter.lastWeek, Icons.date_range, outerContext.tr('wallet_last_week'), outerContext.tr('wallet_filter_lastweek_sub')),
      (DateFilter.lastMonth, Icons.calendar_month, outerContext.tr('wallet_last_month'), outerContext.tr('wallet_filter_lastmonth_sub')),
      (DateFilter.last3Months, Icons.calendar_today, outerContext.tr('wallet_last_3months'), outerContext.tr('wallet_filter_last3months_sub')),
      (DateFilter.custom, Icons.tune, outerContext.tr('wallet_custom_period'), outerContext.tr('wallet_filter_custom_sub')),
    ];

    return options.map((option) {
      final (filter, icon, label, subtitle) = option;
      final isSelected = _selectedDateFilter == filter;
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.15)
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(sheetContext)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.textSecondaryColor),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onTap: () async {
          Navigator.pop(sheetContext); // close sheet with sheetContext
          if (filter == DateFilter.custom) {
            await _showDateRangePicker(outerContext); // use valid outer context
          } else {
            setState(() {
              _selectedDateFilter = filter;
              _selectedDateRange = null;
            });
          }
        },
      );
    }).toList();
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    DateTime startDate = _selectedDateRange?.start ?? DateTime(now.year, now.month, 1);
    DateTime endDate = _selectedDateRange?.end ?? now;

    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _CustomDateRangeDialog(
        initialStart: startDate,
        initialEnd: endDate,
        firstYear: 2020,
        lastYear: now.year,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDateFilter = DateFilter.custom;
        _selectedDateRange = result;
      });
    }
  }

  Widget _buildFilteredTransactionList(BuildContext context, WalletProvider walletProvider) {
    final filteredTransactions = _getFilteredTransactions(walletProvider.transactions);
    
    if (filteredTransactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('wallet_no_transactions'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('wallet_no_transactions_sub'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Group by date
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final t in filteredTransactions) {
      final day = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      grouped.putIfAbsent(day, () => []).add(t);
    }
    final sortedDays = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Build flat list: [header, card, card, header, card, ...]
    final items = <Widget>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final headerFmt = DateFormat('d MMMM yyyy');

    for (final day in sortedDays) {
      String label;
      if (day == today) {
        label = context.tr('wallet_today');
      } else if (day == yesterday) {
        label = context.tr('wallet_yesterday');
      } else {
        label = headerFmt.format(day);
      }
      items.add(_DateHeader(label: label));
      for (final t in grouped[day]!) {
        items.add(TransactionCard(
          transaction: t,
          onTap: () => _handleTransactionTap(context, t),
        ));
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => items[index],
        childCount: items.length,
      ),
    );
  }

  void _showIncomeCertificateDialog(BuildContext context) {
    final walletProvider = context.read<WalletProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Income Certificate'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('wallet_income_cert_title'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildCertificateOption(
              context,
              context.tr('wallet_income_monthly'),
              context.tr('wallet_income_monthly_sub'),
              Icons.calendar_today,
              AppTheme.primaryColor,
              () {
                Navigator.pop(context);
                _showMonthPickerDialog(context, walletProvider);
              },
            ),
            const SizedBox(height: 12),
            _buildCertificateOption(
              context,
              context.tr('wallet_income_yearly'),
              context.tr('wallet_income_yearly_sub'),
              Icons.calendar_view_month,
              AppTheme.successColor,
              () {
                Navigator.pop(context);
                _showYearPickerDialog(context, walletProvider);
              },
            ),
          ],
        ),
        actions: [
          OutlinedButton(
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
            ),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPickerDialog(BuildContext context, WalletProvider provider) {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.tr('wallet_select_month')),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Year selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerColor, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        items: List.generate(5, (index) {
                          final year = now.year - index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text('${context.tr('wallet_year_prefix')} ${context.l10n.isThai ? year + 543 : year}'), // Thai year
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == selectedMonth;
                  final monthNames = [
                    'ม.ค.', 'กุ.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
                    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
                  ];
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedMonth = month;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        monthNames[index],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isSelected ? Colors.white : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  );
                },
              ),
                ],
              ),
            ),
            ),
          ),
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
                    onPressed: () {
                      final selectedDate =
                          DateTime(selectedYear, selectedMonth);
                      Navigator.pop(context);
                      _downloadIncomeCertificate(
                        this.context,
                        provider,
                        selectedDate: selectedDate,
                        isMonthly: true,
                      );
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
      ),
    );
  }

  void _showYearPickerDialog(BuildContext context, WalletProvider provider) {
    final now = DateTime.now();
    int selectedYear = now.year;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.calendar_view_day,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.tr('wallet_select_year')),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Text(
                  context.tr('wallet_income_yearly_sub'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                // Year list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: 10, // Last 10 years
                  itemBuilder: (context, index) {
                    final year = now.year - index;
                    final isSelected = year == selectedYear;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedYear = year;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.successColor
                                : AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.successColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ปี ${year + 543} (${year})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: isSelected ? Colors.white : AppTheme.successColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ],
            ),
            ),
          ),
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
                    onPressed: () {
                      final selectedDate = DateTime(selectedYear);
                      Navigator.pop(context);
                      _downloadIncomeCertificate(
                        this.context,
                        provider,
                        selectedDate: selectedDate,
                        isMonthly: false,
                      );
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
      ),
    );
  }

  Future<void> _downloadIncomeCertificate(
    BuildContext context,
    WalletProvider provider, {
    required DateTime selectedDate,
    required bool isMonthly,
  }) async {
    final period = isMonthly
        ? DateFormat('MMMM yyyy').format(selectedDate)
        : DateFormat('yyyy').format(selectedDate);

    final filteredTransactions = provider.transactions.where((t) {
      if (isMonthly) {
        return t.createdAt.year == selectedDate.year &&
            t.createdAt.month == selectedDate.month;
      }
      return t.createdAt.year == selectedDate.year;
    }).toList();

    final incomeTxns = filteredTransactions
        .where((t) =>
            t.type == TransactionType.payment ||
            t.type == TransactionType.bonus)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totalIncome = incomeTxns.fold<double>(
      0,
      (sum, t) => sum + t.amount.abs(),
    );

    final profile = context.read<AuthProvider>().currentUser;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dayFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final certId =
        'INC-${selectedDate.year}${isMonthly ? selectedDate.month.toString().padLeft(2, '0') : 'YR'}-${now.millisecondsSinceEpoch % 100000}';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating certificate...'),
                ],
              ),
            ),
          ),
        ),
      );

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context ctx) => [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'MedShift Thailand',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#00BDF8'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Medical Staffing Marketplace',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2, color: PdfColor.fromHex('#00BDF8')),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'INCOME CERTIFICATE',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'No. $certId',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'This is to certify that the following medical staff member has earned income through MedShift Thailand during the stated period.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfRow(
                    'Full name:',
                    profile?.fullName.isNotEmpty == true
                        ? profile!.fullName
                        : '-',
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfRow(
                    'Specialty:',
                    profile?.specialty.isNotEmpty == true
                        ? profile!.specialty
                        : '-',
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfRow(
                    'License No.:',
                    profile?.licenseNumber.isNotEmpty == true
                        ? profile!.licenseNumber
                        : '-',
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfRow('Email:', profile?.email ?? '-'),
                  pw.SizedBox(height: 10),
                  _buildPdfRow('Period:', period),
                  pw.SizedBox(height: 10),
                  _buildPdfRow(
                    'Total income:',
                    '${NumberFormatter.formatCurrency(totalIncome)} THB',
                    isBold: true,
                    fontSize: 14,
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow(
                    'Earnings entries:',
                    '${incomeTxns.length}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Income breakdown',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (incomeTxns.isEmpty)
              pw.Text(
                'No payment or bonus transactions in this period.',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Type', 'Description', 'Amount (THB)'],
                data: incomeTxns.map((t) {
                  final typeLabel =
                      t.type == TransactionType.bonus ? 'Bonus' : 'Payment';
                  final desc = t.description.length > 42
                      ? '${t.description.substring(0, 42)}…'
                      : t.description;
                  return [
                    dayFormat.format(t.createdAt.toLocal()),
                    typeLabel,
                    desc,
                    NumberFormatter.formatCurrency(t.amount.abs()),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(0.9),
                  2: const pw.FlexColumnWidth(2.4),
                  3: const pw.FlexColumnWidth(1.2),
                },
              ),
            pw.SizedBox(height: 28),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Digital attestation',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Digitally attested by MedShift Thailand based on wallet ledger records as of ${dateFormat.format(now)}.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      lineSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'MedShift Thailand Co., Ltd.',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This document is generated automatically from platform records.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (context.mounted) Navigator.pop(context); // close loading

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'income_certificate_$certId.pdf',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('wallet_cert_generated') +
                ' — $period · ${NumberFormatter.formatCurrencyWithSymbol(totalIncome)}',
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // close loading if still open
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate certificate: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showPaymentDialog(BuildContext context, WalletProvider provider) {
    var isPaying = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(context.tr('wallet_pay_outstanding')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('wallet_pay_amount'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormatter.formatCurrencyWithSymbol(provider.balance.abs()),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('wallet_pay_msg'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPaying ? null : () => Navigator.pop(dialogContext),
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
                    onPressed: isPaying
                        ? null
                        : () async {
                            setDialogState(() => isPaying = true);
                            final ok = await provider.settleNegativeBalance();
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? context.tr('wallet_pay_success')
                                      : (provider.error ??
                                          context.tr('wallet_pay_error')),
                                ),
                                backgroundColor: ok
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isPaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.tr('wallet_pay_proceed')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WalletProvider provider) {
    final profile = context.read<AuthProvider>().currentUser;

    // Check: no bank account info
    if (profile == null ||
        profile.bankAccountNumber == null ||
        profile.bankAccountNumber!.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.account_balance, color: AppTheme.warningColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('wallet_no_bank'))),
            ],
          ),
          content: Text(context.tr('wallet_no_bank_msg')),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      );
      return;
    }

    if (!profile.bankAccountVerified) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: AppTheme.warningColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(context.tr('bank_unverified'))),
            ],
          ),
          content: Text(
            context.tr('wallet_bank_unverified_msg'),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      );
      return;
    }

    // Bank account on file — API accepts withdraw; admin approves transfer
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.account_balance, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('wallet_withdraw'))),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance
              Text(context.tr('wallet_balance_current'),
                  style: Theme.of(dialogCtx).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                NumberFormatter.formatCurrencyWithSymbol(provider.balance),
                style: Theme.of(dialogCtx).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Bank info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 18, color: AppTheme.successColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.bankName ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(profile.bankAccountNumber ?? '',
                              style: const TextStyle(fontSize: 13)),
                          Text(profile.bankAccountName ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Amount field
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: context.tr('wallet_amount_label'),
                  prefixText: '฿ ',
                  hintText: '0.00',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return context.tr('wallet_amount_enter');
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return context.tr('wallet_amount_invalid');
                  if (amount > provider.balance) return context.tr('wallet_insufficient');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppTheme.infoColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('wallet_transfer_note'),
                        style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                              color: AppTheme.infoColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final amount = double.parse(amountController.text);
                      Navigator.pop(dialogCtx);
                      _showWithdrawConfirmDialog(context, provider, amount, profile);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('next')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawConfirmDialog(
    BuildContext context,
    WalletProvider provider,
    double amount,
    dynamic profile,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('wallet_confirm_withdraw'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _confirmRow(context.tr('wallet_amount'),
                      NumberFormatter.formatCurrencyWithSymbol(amount),
                      valueColor: AppTheme.primaryColor,
                      valueBold: true),
                  const Divider(height: 20),
                  _confirmRow(context.tr('bank_name'), profile.bankName ?? ''),
                  const SizedBox(height: 6),
                  _confirmRow(context.tr('bank_account_no'), profile.bankAccountNumber ?? ''),
                  const SizedBox(height: 6),
                  _confirmRow(context.tr('wallet_bank_name'), profile.bankAccountName ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('wallet_irreversible'),
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final staffId =
                        context.read<AuthProvider>().currentUser?.id ?? '';
                    final success = await provider.withdrawMoney(
                      staffId: staffId,
                      amount: amount,
                      bankAccount: profile.bankAccountNumber ?? '',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons.error,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  success
                                      ? context.tr('wallet_withdraw_success')
                                      : provider.error ?? context.tr('wallet_withdraw_failed'),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor:
                              success ? AppTheme.successColor : AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('wallet_confirm_btn')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value,
      {Color? valueColor, bool valueBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondaryColor)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadReceipt(BuildContext context, TransactionModel transaction) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'MedShift Thailand',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#00BDF8'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Medical Staffing Marketplace',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Divider(thickness: 2, color: PdfColor.fromHex('#00BDF8')),
                  pw.SizedBox(height: 20),

                  // Receipt Title
                  pw.Center(
                    child: pw.Text(
                      'RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Transaction Details
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 1.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildPdfRow('Transaction ID:', transaction.id),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Date:', dateFormat.format(transaction.createdAt)),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Description:', transaction.description),
                        pw.SizedBox(height: 12),
                        _buildPdfRow('Type:', 'Penalty'),
                        pw.SizedBox(height: 16),
                        pw.Divider(),
                        pw.SizedBox(height: 16),
                        _buildPdfRow(
                          'Amount:',
                          NumberFormatter.formatCurrency(transaction.amount.abs()),
                          isBold: true,
                          fontSize: 16,
                        ),
                        pw.SizedBox(height: 12),
                        _buildPdfRow(
                          'Balance After:',
                          NumberFormatter.formatCurrency(transaction.balanceAfter),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 30),

                  // Job Details (if available)
                  if (transaction.jobId != null) ...[
                    pw.Text(
                      'Job Details',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow('Job ID:', transaction.jobId ?? '-'),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 30),
                  ],

                  pw.Spacer(),

                  // Footer
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'MedShift Thailand Co., Ltd.',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'This document is generated automatically',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Printed: ${dateFormat.format(now)}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Show PDF preview and print/save dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'receipt_${transaction.id}.pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Receipt ready'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to generate receipt: $e'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 3,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Date group header
// ─────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
          ),
          // const SizedBox(width: 8),
          // const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final isNegative = transaction.isNegative;

    IconData icon;
    Color iconColor;

    switch (transaction.type) {
      case TransactionType.payment:
        icon = Icons.attach_money;
        iconColor = AppTheme.successColor;
        break;
      case TransactionType.penalty:
        icon = Icons.warning_amber_rounded;
        iconColor = AppTheme.errorColor;
        break;
      case TransactionType.refund:
        icon = Icons.replay;
        iconColor = AppTheme.infoColor;
        break;
      case TransactionType.bonus:
        icon = Icons.star;
        iconColor = AppTheme.warningColor;
        break;
      case TransactionType.withdrawal:
        icon = Icons.account_balance;
        iconColor = AppTheme.infoColor;
        break;
      case TransactionType.deposit:
        icon = Icons.lock_open;
        iconColor = AppTheme.successColor;
        break;
    }

    String typeLabel;
    switch (transaction.type) {
      case TransactionType.payment:
        typeLabel = context.tr('tx_payment');
        break;
      case TransactionType.penalty:
        typeLabel = context.tr('tx_penalty');
        break;
      case TransactionType.refund:
        typeLabel = context.tr('tx_refund');
        break;
      case TransactionType.bonus:
        typeLabel = context.tr('tx_bonus');
        break;
      case TransactionType.withdrawal:
        typeLabel = context.tr('tx_withdrawal');
        break;
      case TransactionType.deposit:
        typeLabel = context.tr('tx_negative_pay');
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Row 2: เวลา (ซ้าย) | ยอดเงิน (ขวา)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateFormat.format(transaction.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          transaction.formattedAmount,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isNegative
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Row 1: ประเภท (ซ้าย) | ดูงาน (ขวา)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (transaction.jobId != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.expand_more,
                                size: 16,
                                color: AppTheme.primaryColor,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom Date Range Dialog – เลือกปี/เดือน/วัน แบบปฏิทิน
// ─────────────────────────────────────────────────────────────
class _CustomDateRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final int firstYear;
  final int lastYear;

  const _CustomDateRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateTime _startViewMonth = DateTime.now();
  DateTime _endViewMonth = DateTime.now();

  static const _weekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
  static const _monthNames = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _startViewMonth = DateTime(_startDate.year, _startDate.month);
    _endViewMonth = DateTime(_endDate.year, _endDate.month);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isValid() => !_startDate.isAfter(_endDate);

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year + 543}';

  Widget _buildCalendarView({
    required DateTime viewMonth,
    required DateTime selectedDate,
    required bool isStart,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required VoidCallback onPrevMonth,
    required VoidCallback onNextMonth,
    required ValueChanged<DateTime> onDaySelected,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0=Sun
    // Normalize range endpoints (time stripped)
    final rStart = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final rEnd = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
    final hasRange = rEnd.isAfter(rStart);

    return Column(
      children: [
        // Month/Year navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevMonth,
              padding: EdgeInsets.zero,
            ),
            Text(
              '${_monthNames[viewMonth.month - 1]} ${viewMonth.year + 543}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextMonth,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Weekday headers
        Row(
          children: _weekdays.map((d) => Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: d == 'อา' ? Colors.red[400] : AppTheme.textSecondaryColor,
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        // Days grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.1,
            mainAxisSpacing: 2,
            crossAxisSpacing: 0,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday) return const SizedBox();
            final day = index - startWeekday + 1;
            final date = DateTime(viewMonth.year, viewMonth.month, day);
            final isFuture = date.isAfter(today);
            final isSelected = _isSameDay(date, selectedDate);
            final isRangeStart = _isSameDay(date, rStart);
            final isRangeEnd = _isSameDay(date, rEnd);
            final isToday = _isSameDay(date, today);
            final isSunday = date.weekday == DateTime.sunday;
            // In range (exclusive of endpoints — endpoints have their own style)
            final inRange = hasRange &&
                date.isAfter(rStart) &&
                date.isBefore(rEnd);

            // Determine column position within the week (0=Sun)
            final col = (startWeekday + day - 1) % 7;
            final isFirstInRow = col == 0;
            final isLastInRow = col == 6;

            return GestureDetector(
              onTap: isFuture ? null : () => onDaySelected(date),
              child: Stack(
                children: [
                  // Range background band
                  if ((inRange || isRangeStart || isRangeEnd) && hasRange)
                    Positioned.fill(
                      child: Row(
                        children: [
                          // Left half: fill if not start-of-range
                          Expanded(
                            child: Container(
                              color: (isRangeStart && !isFirstInRow) || (!isRangeStart && !isRangeEnd && !isFirstInRow) || inRange
                                  ? (isRangeStart
                                      ? Colors.transparent
                                      : AppTheme.primaryColor.withOpacity(0.15))
                                  : Colors.transparent,
                            ),
                          ),
                          // Right half: fill if not end-of-range
                          Expanded(
                            child: Container(
                              color: (isRangeEnd && !isLastInRow) || (!isRangeStart && !isRangeEnd && !isLastInRow) || inRange
                                  ? (isRangeEnd
                                      ? Colors.transparent
                                      : AppTheme.primaryColor.withOpacity(0.15))
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Range background simplified
                  if (inRange)
                    Positioned.fill(
                      child: Container(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                      ),
                    ),
                  if (isRangeStart && hasRange)
                    Positioned.fill(
                      child: Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          Expanded(
                            child: Container(
                              color: AppTheme.primaryColor.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isRangeEnd && hasRange)
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: AppTheme.primaryColor.withOpacity(0.12),
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  // Day circle
                  Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected || isRangeStart || isRangeEnd
                            ? AppTheme.primaryColor
                            : isToday
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday || isRangeStart || isRangeEnd
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected || isRangeStart || isRangeEnd
                              ? Colors.white
                              : isFuture
                                  ? AppTheme.textSecondaryColor.withOpacity(0.35)
                                  : inRange
                                      ? AppTheme.primaryColor
                                      : isSunday
                                          ? Colors.red[400]
                                          : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isValid();
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title + summary
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('wallet_select_date_range'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('wallet_start_short'), style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                              Text(_formatDate(_startDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppTheme.textSecondaryColor),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.secondaryColor, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('wallet_end_short'), style: TextStyle(fontSize: 10, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                              Text(_formatDate(_endDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              indicatorColor: AppTheme.primaryColor,
              tabs: [
                Tab(text: context.tr('date_start')),
                Tab(text: context.tr('date_end')),
              ],
            ),
            // Calendar content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Start date calendar
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildCalendarView(
                      viewMonth: _startViewMonth,
                      selectedDate: _startDate,
                      isStart: true,
                      rangeStart: _startDate,
                      rangeEnd: _endDate,
                      onPrevMonth: () => setState(() {
                        _startViewMonth = DateTime(_startViewMonth.year, _startViewMonth.month - 1);
                      }),
                      onNextMonth: () => setState(() {
                        _startViewMonth = DateTime(_startViewMonth.year, _startViewMonth.month + 1);
                      }),
                      onDaySelected: (date) => setState(() {
                        _startDate = date;
                        // auto-fix: if start > end, move end to start
                        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
                        // Switch to end tab
                        _endViewMonth = DateTime(_endDate.year, _endDate.month);
                        _tabController.animateTo(1);
                      }),
                    ),
                  ),
                  // End date calendar
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildCalendarView(
                      viewMonth: _endViewMonth,
                      selectedDate: _endDate,
                      isStart: false,
                      rangeStart: _startDate,
                      rangeEnd: _endDate,
                      onPrevMonth: () => setState(() {
                        _endViewMonth = DateTime(_endViewMonth.year, _endViewMonth.month - 1);
                      }),
                      onNextMonth: () => setState(() {
                        _endViewMonth = DateTime(_endViewMonth.year, _endViewMonth.month + 1);
                      }),
                      onDaySelected: (date) => setState(() {
                        _endDate = date;
                        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            if (!valid) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  context.tr('date_invalid'),
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                ),
              ),
            ],
            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(context.tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: valid
                        ? () => Navigator.pop(context, DateTimeRange(start: _startDate, end: _endDate))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(context.tr('confirm')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
