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

  /// Parse date string or DateTime into Indonesian time (WIB / WITA / WIT).
  /// If input is in UTC, converts to Indonesian timezone.
  static DateTime? parseToIndonesianTime(dynamic dateInput) {
    if (dateInput == null) return null;
    if (dateInput is DateTime) {
      return _convertToIndonesianTime(dateInput);
    }
    final dateStr = dateInput.toString().trim();
    if (dateStr.isEmpty || dateStr == 'null') return null;

    DateTime? dt = DateTime.tryParse(dateStr);
    if (dt == null) {
      try {
        dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
      } catch (_) {
        try {
          dt = DateFormat('yyyy-MM-dd').parse(dateStr);
        } catch (_) {
          return null;
        }
      }
    }

    return _convertToIndonesianTime(dt);
  }

  static DateTime _convertToIndonesianTime(DateTime dt) {
    if (dt.isUtc) {
      final localOffset = DateTime.now().timeZoneOffset.inHours;
      if (localOffset >= 7 && localOffset <= 9) {
        return dt.toLocal();
      } else {
        // Default to WIB (UTC+7)
        return dt.add(const Duration(hours: 7));
      }
    }
    return dt;
  }

  /// Returns Indonesian timezone abbreviation ('WIB', 'WITA', or 'WIT').
  static String getTimeZoneSuffix([DateTime? date]) {
    final target = date ?? DateTime.now();
    final offset = target.isUtc ? 7 : DateTime.now().timeZoneOffset.inHours;
    if (offset == 8) return 'WITA';
    if (offset == 9) return 'WIT';
    return 'WIB';
  }

  /// Format date string or DateTime into Indonesian standard format.
  /// Output example with time: "10 Sep 2026, 16:04 WIB"
  /// Output example without time: "10 Sep 2026"
  static String formatDate(
    dynamic dateInput, {
    bool withTime = true,
    bool withTimeZone = true,
  }) {
    if (dateInput == null) return '-';
    final str = dateInput.toString().trim();
    if (str.isEmpty || str == 'null') return '-';

    final dt = parseToIndonesianTime(dateInput);
    if (dt == null) return str;

    // Detect if original input had time component
    final hasTime = str.contains('T') || str.contains(':');

    try {
      if (hasTime && withTime) {
        final formatted = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
        if (withTimeZone) {
          final tz = getTimeZoneSuffix(dt);
          return '$formatted $tz';
        }
        return formatted;
      } else {
        return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {
      // Robust fallback if locale data is not loaded
      final day = dt.day.toString().padLeft(2, '0');
      final month = _indonesianMonthsShort[dt.month - 1];
      final year = dt.year;
      if (hasTime && withTime) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final tz = withTimeZone ? ' ${getTimeZoneSuffix(dt)}' : '';
        return '$day $month $year, $hour:$minute$tz';
      }
      return '$day $month $year';
    }
  }

  /// Formats DateTime object directly with Indonesian time and timezone.
  static String formatDateTime(
    DateTime? date, {
    bool withTimeZone = true,
  }) {
    if (date == null) return '-';
    return formatDate(date, withTime: true, withTimeZone: withTimeZone);
  }

  static String formatDateOnly(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static const List<String> _indonesianMonthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
}
