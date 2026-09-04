import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,###', 'id_ID');

  static String format(num? amount) {
    if (amount == null) return 'Rp 0';
    return _currencyFormat.format(amount);
  }

  static String formatNumber(num? number) {
    if (number == null) return '0';
    return _numberFormat.format(number);
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDateOnly(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
