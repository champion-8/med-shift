import '../utils/number_formatter.dart';

enum TransactionType {
  payment,
  penalty,
  refund,
  bonus,
  withdrawal,
  deposit,
}

enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

class TransactionModel {
  final String id;
  final String staffId;
  final String? jobId;
  final TransactionType type;
  final double amount;
  final TransactionStatus status;
  final String description;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.staffId,
    this.jobId,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Supports MedShift API camelCase and legacy snake_case.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    TransactionType parseType(Object? raw) {
      final value = (raw ?? 'Payment').toString().toLowerCase();
      return TransactionType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionType.payment,
      );
    }

    TransactionStatus parseStatus(Object? raw) {
      final value = (raw ?? 'Completed').toString().toLowerCase();
      return TransactionStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionStatus.completed,
      );
    }

    final createdAt =
        DateTime.tryParse((pick('createdAt', 'created_at') ?? '').toString()) ??
            DateTime.now();
    final updatedAt = DateTime.tryParse(
          (pick('updatedAt', 'updated_at') ?? '').toString(),
        ) ??
        createdAt;

    return TransactionModel(
      id: (pick('id') ?? '').toString(),
      staffId: (pick('staffId', 'staff_id') ?? '').toString(),
      jobId: () {
        final raw = pick('jobId', 'job_id');
        if (raw == null) return null;
        final text = raw.toString();
        return text.isEmpty || text == 'null' ? null : text;
      }(),
      type: parseType(pick('type')),
      amount: (pick('amount') is num)
          ? (pick('amount') as num).toDouble()
          : double.tryParse('${pick('amount') ?? 0}') ?? 0,
      status: parseStatus(pick('status')),
      description: (pick('description') ?? '').toString(),
      balanceBefore: (pick('balanceBefore', 'balance_before') is num)
          ? (pick('balanceBefore', 'balance_before') as num).toDouble()
          : double.tryParse('${pick('balanceBefore', 'balance_before') ?? 0}') ??
              0,
      balanceAfter: (pick('balanceAfter', 'balance_after') is num)
          ? (pick('balanceAfter', 'balance_after') as num).toDouble()
          : double.tryParse('${pick('balanceAfter', 'balance_after') ?? 0}') ??
              0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'jobId': jobId,
      'type': type.name,
      'amount': amount,
      'status': status.name,
      'description': description,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? staffId,
    String? jobId,
    TransactionType? type,
    double? amount,
    TransactionStatus? status,
    String? description,
    double? balanceBefore,
    double? balanceAfter,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      jobId: jobId ?? this.jobId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      description: description ?? this.description,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isNegative => amount < 0;

  String get formattedAmount {
    return '${NumberFormatter.formatAmountWithSign(amount)} THB';
  }
}
