import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // 10.0.2.2 only works from the Android emulator.
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return 'http://127.0.0.1:8000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000';
    }
  }

  // Auth
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';

  // Menu
  static const String menu = '/api/menu';
  static String menuItem(int id) => '/api/menu/$id';
  static String toggleAvailability(int id) => '/api/menu/$id/toggle';

  // Bills
  static const String bills = '/api/bills';
  static String bill(int id) => '/api/bills/$id';
  static const String billSearch = '/api/bills/search';
  static String cancelBill(int id) => '/api/bills/$id/cancel';
  static String confirmCash(int id) => '/api/bills/$id/confirm-cash';

  // Payments
  static String initiatePayment(int id) => '/api/bills/$id/payment';
  static String paymentStatus(int id) => '/api/payments/$id/status';

  // UPI Accounts
  static const String upiAccounts = '/api/upi-accounts';
  static String upiAccount(int id) => '/api/upi-accounts/$id';
  static String setDefaultUpi(int id) => '/api/upi-accounts/$id/default';

  // Reports
  static const String dailyReport = '/api/reports/daily';
  static const String rangeReport = '/api/reports/range';
}
