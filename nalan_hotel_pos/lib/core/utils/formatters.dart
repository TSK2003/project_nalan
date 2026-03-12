import 'package:intl/intl.dart';

class AppFormatters {
  static String currency(double amount) {
    return '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  static String currencyExact(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String date(DateTime dt) {
    return DateFormat('dd-MMM-yyyy').format(dt);
  }

  static String time(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  static String dateTime(DateTime dt) {
    return '${date(dt)} · ${time(dt)}';
  }

  static String apiDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }
}
