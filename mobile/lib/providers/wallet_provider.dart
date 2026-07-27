import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_constants.dart';
import '../utils/number_formatter.dart';

class WalletProvider with ChangeNotifier {
  final ApiClient _apiClient;

  double _balance = 0.0;
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  WalletProvider(this._apiClient);

  double get balance => _balance;
  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasNegativeBalance => _balance < 0;

  double get pendingBalance => hasNegativeBalance ? _balance.abs() : 0.0;

  /// Load balance + transactions from GET /api/staff/wallet
  Future<void> fetchWallet([String? staffId]) async {
    _setLoading(true);
    _error = null;

    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock wallet');
        await Future.delayed(const Duration(milliseconds: 300));
        _balance = 2450000.50;
        _transactions = _generateMockTransactions();
        _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        return;
      }

      final response =
          await _apiClient.get('${AppConstants.staffApiPrefix}/wallet');

      if (response.statusCode == 200) {
        _applyWalletPayload(response.data);
        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching wallet: ${e.message}');
    } catch (e) {
      _error = 'Failed to load wallet';
      debugPrint('Error fetching wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch wallet balance for staff (compat — uses same wallet endpoint)
  Future<void> fetchBalance(String staffId) async {
    await fetchWallet(staffId);
  }

  /// Fetch transaction history (compat — uses same wallet endpoint)
  Future<void> fetchTransactions(String staffId) async {
    await fetchWallet(staffId);
  }

  void _applyWalletPayload(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);

    final bal = map['balance'];
    if (bal is num) {
      _balance = bal.toDouble();
    } else if (bal != null) {
      _balance = double.tryParse(bal.toString()) ?? _balance;
    }

    final list = map['transactions'];
    if (list is List) {
      final parsed = <TransactionModel>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          parsed.add(
            TransactionModel.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (e) {
          debugPrint('Skip bad transaction: $e item=$item');
        }
      }
      _transactions = parsed;
      _transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  /// Penalty is applied server-side when cancelling a hired job.
  /// Refresh wallet after cancel; keep signature for calendar callers.
  Future<bool> applyCancellationPenalty({
    required String staffId,
    required String jobId,
    String? reason,
  }) async {
    try {
      await fetchWallet(staffId);
      return true;
    } catch (e) {
      debugPrint('Error refreshing wallet after penalty: $e');
      return false;
    }
  }

  /// Payments are credited by clinic complete-job on the server.
  Future<bool> addPayment({
    required String staffId,
    required String jobId,
    required double amount,
  }) async {
    await fetchWallet(staffId);
    return true;
  }

  bool canAcceptNewJobs({double threshold = -500.0}) {
    return _balance >= threshold;
  }

  String get formattedBalance {
    return NumberFormatter.formatBalance(_balance);
  }

  List<TransactionModel> getTransactionsByType(TransactionType type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  List<TransactionModel> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _transactions.where((t) {
      return t.createdAt.isAfter(startDate) && t.createdAt.isBefore(endDate);
    }).toList();
  }

  double get totalEarnings {
    return _transactions
        .where((t) =>
            t.type == TransactionType.payment &&
            t.status == TransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalPenalties {
    return _transactions
        .where((t) =>
            t.type == TransactionType.penalty &&
            t.status == TransactionStatus.completed)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
  }

  /// Withdraw money — POST /api/staff/wallet/withdraw
  Future<bool> withdrawMoney({
    required String staffId,
    required double amount,
    String? bankAccount,
  }) async {
    if (amount <= 0) {
      _error = 'จำนวนเงินต้องมากกว่า 0';
      notifyListeners();
      return false;
    }

    if (amount > _balance) {
      _error = 'ยอดเงินไม่เพียงพอ';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Processing withdrawal');
        await Future.delayed(const Duration(milliseconds: 500));

        final balanceBefore = _balance;
        final balanceAfter = _balance - amount;
        _balance = balanceAfter;

        _transactions.insert(
          0,
          TransactionModel(
            id: 'txn-withdraw-${DateTime.now().millisecondsSinceEpoch}',
            staffId: staffId,
            jobId: null,
            type: TransactionType.withdrawal,
            amount: -amount,
            status: TransactionStatus.pending,
            description: 'ถอนเงินเข้าบัญชี ${bankAccount ?? "****"}',
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        notifyListeners();
        return true;
      }

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/wallet/withdraw',
        data: {'amount': amount},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchWallet(staffId);
        return true;
      }

      _error = 'การถอนเงินล้มเหลว';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error withdrawing money: ${e.message}');
      return false;
    } catch (e) {
      _error = 'การถอนเงินล้มเหลว';
      debugPrint('Error withdrawing money: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Pay outstanding negative balance — POST /api/staff/wallet/settle
  Future<bool> settleNegativeBalance({String? staffId, String? paymentReference}) async {
    if (!hasNegativeBalance) {
      _error = 'ไม่มียอดค้างชำระ';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/wallet/settle',
        data: {
          if (paymentReference != null && paymentReference.isNotEmpty)
            'paymentReference': paymentReference,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          _applyWalletPayload(response.data);
          notifyListeners();
        } else {
          await fetchWallet(staffId);
        }
        return true;
      }

      _error = 'ชำระยอดติดลบไม่สำเร็จ';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error settling negative balance: ${e.message}');
      return false;
    } catch (e) {
      _error = 'ชำระยอดติดลบไม่สำเร็จ';
      debugPrint('Error settling negative balance: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List<TransactionModel> _generateMockTransactions() {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'txn-001',
        staffId: AppConstants.mockUserId,
        jobId: 'job-hired-today',
        type: TransactionType.payment,
        amount: 32000.0,
        status: TransactionStatus.completed,
        description: 'พยาบาลตรวจสุขภาพ - บริษัทเอกชน',
        balanceBefore: 1000.50,
        balanceAfter: 42000.50,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      TransactionModel(
        id: 'txn-002',
        staffId: AppConstants.mockUserId,
        jobId: 'job-hired-001',
        type: TransactionType.payment,
        amount: 34200.0,
        status: TransactionStatus.completed,
        description: 'พยาบาลประจำคลินิก - กะเช้า',
        balanceBefore: 42000.50,
        balanceAfter: 76200.50,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      TransactionModel(
        id: 'txn-003',
        staffId: AppConstants.mockUserId,
        jobId: 'job-hired-002',
        type: TransactionType.penalty,
        amount: -50.0,
        status: TransactionStatus.completed,
        description: 'พยาบาลฉีดวัคซีน - โรงเรียน',
        balanceBefore: 76200.50,
        balanceAfter: 75700.50,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }
}
