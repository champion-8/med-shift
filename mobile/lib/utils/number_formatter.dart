import 'package:intl/intl.dart';

/// Utility class for formatting numbers with thousand separators
class NumberFormatter {
  // Private constructor to prevent instantiation
  NumberFormatter._();

  /// Format currency with comma separator (e.g., 2,450.50)
  /// [amount] - The amount to format
  /// [decimals] - Number of decimal places (default: 2)
  static String formatCurrency(double amount, {int decimals = 2}) {
    if (decimals == 0) {
      final formatter = NumberFormat('#,##0', 'en_US');
      return formatter.format(amount);
    }
    final formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    return formatter.format(amount);
  }

  /// Format currency with THB symbol (e.g., ฿2,450.50)
  /// [amount] - The amount to format
  /// [decimals] - Number of decimal places (default: 2)
  static String formatCurrencyWithSymbol(double amount, {int decimals = 2}) {
    return '฿${formatCurrency(amount, decimals: decimals)}';
  }

  /// Format currency without decimals (e.g., ฿2,450)
  /// [amount] - The amount to format
  static String formatCurrencyWhole(double amount) {
    return formatCurrencyWithSymbol(amount, decimals: 0);
  }

  /// Format amount with sign (e.g., +2,450.50 or -50.00)
  /// [amount] - The amount to format
  /// [decimals] - Number of decimal places (default: 2)
  static String formatAmountWithSign(double amount, {int decimals = 2}) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${formatCurrency(amount, decimals: decimals)}';
  }

  /// Format balance with sign and THB (e.g., +2,450.50 THB)
  /// [balance] - The balance to format
  /// [decimals] - Number of decimal places (default: 2)
  static String formatBalance(double balance, {int decimals = 2}) {
    final sign = balance >= 0 ? '' : '-';
    return '$sign${formatCurrency(balance.abs(), decimals: decimals)} THB';
  }

  /// Format number with comma separator (e.g., 1,234.5)
  /// [number] - The number to format
  /// [decimals] - Number of decimal places (default: 1)
  static String formatNumber(double number, {int decimals = 1}) {
    final formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    return formatter.format(number);
  }

  /// Format compact number (e.g., 1.2K, 3.5M)
  /// [number] - The number to format
  static String formatCompact(double number) {
    final formatter = NumberFormat.compact(locale: 'en_US');
    return formatter.format(number);
  }
}
