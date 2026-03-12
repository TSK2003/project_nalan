import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../local/offline_pos_store.dart';
import '../network/api_client.dart';

enum AppMode { offline, cloud }

class PosDataException implements Exception {
  final String message;

  const PosDataException(this.message);

  @override
  String toString() => message;
}

class PosDataService {
  PosDataService._();

  static final PosDataService instance = PosDataService._();

  static const _modeValue = String.fromEnvironment(
    'APP_MODE',
    defaultValue: 'offline',
  );

  AppMode get mode =>
      _modeValue.toLowerCase() == 'cloud' ? AppMode.cloud : AppMode.offline;

  bool get isCloudMode => mode == AppMode.cloud;

  String _dioMessage(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return error.message ?? fallback;
  }

  PosDataException _error(Object error, {required String fallback}) {
    if (error is PosDataException) {
      return error;
    }
    if (error is OfflineStoreException) {
      return PosDataException(error.message);
    }
    if (error is DioException) {
      return PosDataException(_dioMessage(error, fallback: fallback));
    }
    return PosDataException(fallback);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.post(
          ApiEndpoints.login,
          data: {'username': username, 'password': password},
        );
        return Map<String, dynamic>.from(response.data as Map);
      }

      if (username.trim().isEmpty || password.isEmpty) {
        throw const PosDataException('Username and password are required');
      }
      return {
        'token': 'offline-${DateTime.now().millisecondsSinceEpoch}',
        'refresh_token': 'offline-refresh-token',
        'cashier_name': username.trim(),
        'user_id': 1,
      };
    } catch (error) {
      throw _error(error, fallback: 'Login failed. Please try again.');
    }
  }

  Future<List<Map<String, dynamic>>> getMenu({
    bool availableOnly = false,
  }) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.get(
          ApiEndpoints.menu,
          queryParameters: availableOnly ? {'available': true} : null,
        );
        return List<Map<String, dynamic>>.from(
          (response.data as List<dynamic>).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
      }
      return OfflinePosStore.instance.getMenu(availableOnly: availableOnly);
    } catch (error) {
      throw _error(error, fallback: 'Failed to load menu');
    }
  }

  Future<Map<String, dynamic>> saveMenuItem({
    int? id,
    required String name,
    required String category,
    required double price,
    bool isAvailable = true,
  }) async {
    try {
      if (isCloudMode) {
        final payload = {
          'name': name.trim(),
          'category': category,
          'price': price,
          if (id != null) 'is_available': isAvailable,
        };
        final response =
            id == null
                ? await ApiClient().dio.post(ApiEndpoints.menu, data: payload)
                : await ApiClient().dio.put(
                  ApiEndpoints.menuItem(id),
                  data: payload,
                );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.saveMenuItem(
        id: id,
        name: name,
        category: category,
        price: price,
        isAvailable: isAvailable,
      );
    } catch (error) {
      throw _error(error, fallback: 'Failed to save menu item');
    }
  }

  Future<void> toggleMenuAvailability(int id) async {
    try {
      if (isCloudMode) {
        await ApiClient().dio.patch(ApiEndpoints.toggleAvailability(id));
        return;
      }
      await OfflinePosStore.instance.toggleMenuAvailability(id);
    } catch (error) {
      throw _error(error, fallback: 'Failed to update availability');
    }
  }

  Future<void> deleteMenuItem(int id) async {
    try {
      if (isCloudMode) {
        await ApiClient().dio.delete(ApiEndpoints.menuItem(id));
        return;
      }
      await OfflinePosStore.instance.deleteMenuItem(id);
    } catch (error) {
      throw _error(error, fallback: 'Failed to delete menu item');
    }
  }

  Future<Map<String, dynamic>> createBill({
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (isCloudMode) {
        final payloadItems =
            items
                .map(
                  (item) => {
                    'menu_item_id': item['menu_item_id'],
                    'quantity': item['quantity'],
                  },
                )
                .toList();
        final response = await ApiClient().dio.post(
          ApiEndpoints.bills,
          data: {
            'items': payloadItems,
            'discount_amount': 0,
            'discount_percent': 0,
          },
        );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.createBill(items: items);
    } catch (error) {
      throw _error(error, fallback: 'Failed to create bill');
    }
  }

  Future<Map<String, dynamic>> getBill(int billId) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.get(ApiEndpoints.bill(billId));
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.getBill(billId);
    } catch (error) {
      throw _error(error, fallback: 'Bill not found');
    }
  }

  Future<List<Map<String, dynamic>>> listBills({String query = ''}) async {
    try {
      if (isCloudMode) {
        final endpoint =
            query.trim().isEmpty ? ApiEndpoints.bills : ApiEndpoints.billSearch;
        final response = await ApiClient().dio.get(
          endpoint,
          queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
        );
        return List<Map<String, dynamic>>.from(
          (response.data as List<dynamic>).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
      }
      return OfflinePosStore.instance.listBills(query: query);
    } catch (error) {
      throw _error(error, fallback: 'Failed to load bills');
    }
  }

  Future<List<Map<String, dynamic>>> listUpiAccounts() async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.get(ApiEndpoints.upiAccounts);
        return List<Map<String, dynamic>>.from(
          (response.data as List<dynamic>).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
      }
      return OfflinePosStore.instance.listUpiAccounts();
    } catch (error) {
      throw _error(error, fallback: 'Failed to load UPI accounts');
    }
  }

  Future<Map<String, dynamic>> saveUpiAccount({
    int? id,
    required String label,
    required String upiId,
  }) async {
    try {
      if (isCloudMode) {
        final payload = {'label': label.trim(), 'upi_id': upiId.trim()};
        final response =
            id == null
                ? await ApiClient().dio.post(
                  ApiEndpoints.upiAccounts,
                  data: payload,
                )
                : await ApiClient().dio.put(
                  ApiEndpoints.upiAccount(id),
                  data: payload,
                );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.saveUpiAccount(
        id: id,
        label: label,
        upiId: upiId,
      );
    } catch (error) {
      throw _error(error, fallback: 'Failed to save UPI account');
    }
  }

  Future<void> setDefaultUpiAccount(int id) async {
    try {
      if (isCloudMode) {
        await ApiClient().dio.patch(ApiEndpoints.setDefaultUpi(id));
        return;
      }
      await OfflinePosStore.instance.setDefaultUpiAccount(id);
    } catch (error) {
      throw _error(error, fallback: 'Failed to set default UPI');
    }
  }

  Future<void> deleteUpiAccount(int id) async {
    try {
      if (isCloudMode) {
        await ApiClient().dio.delete(ApiEndpoints.upiAccount(id));
        return;
      }
      await OfflinePosStore.instance.deleteUpiAccount(id);
    } catch (error) {
      throw _error(error, fallback: 'Failed to delete UPI account');
    }
  }

  Future<Map<String, dynamic>> confirmCashPayment(
    int billId, {
    required double cashReceived,
  }) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.post(
          ApiEndpoints.confirmCash(billId),
          data: {'cash_received': cashReceived},
        );
        return response.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(response.data as Map)
            : {'status': 'PAID'};
      }
      return OfflinePosStore.instance.confirmCashPayment(
        billId,
        cashReceived: cashReceived,
      );
    } catch (error) {
      throw _error(error, fallback: 'Payment failed');
    }
  }

  Future<Map<String, dynamic>> initiateUpiPayment(
    int billId, {
    required int upiAccountId,
  }) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.post(
          ApiEndpoints.initiatePayment(billId),
          queryParameters: {
            'payment_type': 'UPI',
            'upi_account_id': upiAccountId,
          },
        );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.initiateUpiPayment(
        billId,
        upiAccountId: upiAccountId,
      );
    } catch (error) {
      throw _error(error, fallback: 'Failed to generate UPI QR');
    }
  }

  Future<Map<String, dynamic>> initiateSplitPayment(
    int billId, {
    required double cashAmount,
    required int upiAccountId,
  }) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.post(
          ApiEndpoints.initiatePayment(billId),
          queryParameters: {
            'payment_type': 'SPLIT',
            'upi_account_id': upiAccountId,
          },
          data: {'cash_amount': cashAmount},
        );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.initiateSplitPayment(
        billId,
        cashAmount: cashAmount,
        upiAccountId: upiAccountId,
      );
    } catch (error) {
      throw _error(error, fallback: 'Failed to start split payment');
    }
  }

  Future<Map<String, dynamic>> paymentStatus(int billId) async {
    try {
      if (isCloudMode) {
        final response = await ApiClient().dio.get(
          ApiEndpoints.paymentStatus(billId),
        );
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.paymentStatus(billId);
    } catch (error) {
      throw _error(error, fallback: 'Failed to load payment status');
    }
  }

  Future<Map<String, dynamic>> simulateUpiWebhookSuccess(int billId) async {
    try {
      if (isCloudMode) {
        final bill = await getBill(billId);
        final total = bill['total_amount'];
        final response = await ApiClient().dio.post(
          '/api/webhooks/upi/callback',
          data: {
            'transaction_id': 'SIM_${DateTime.now().millisecondsSinceEpoch}',
            'bill_number': bill['bill_number'],
            'amount': total,
            'status': 'SUCCESS',
            'upi_ref_id': 'TXN${DateTime.now().millisecondsSinceEpoch}',
          },
        );
        return response.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(response.data as Map)
            : {'status': 'PAID'};
      }
      return OfflinePosStore.instance.simulateUpiWebhookSuccess(billId);
    } catch (error) {
      throw _error(error, fallback: 'Failed to simulate UPI payment');
    }
  }

  Future<Map<String, dynamic>> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      if (isCloudMode) {
        final response =
            fromDate != null && toDate != null
                ? await ApiClient().dio.get(
                  ApiEndpoints.rangeReport,
                  queryParameters: {
                    'from':
                        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
                    'to':
                        '${toDate.year.toString().padLeft(4, '0')}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
                  },
                )
                : await ApiClient().dio.get(ApiEndpoints.dailyReport);
        return Map<String, dynamic>.from(response.data as Map);
      }
      return OfflinePosStore.instance.getSummary(
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (error) {
      throw _error(error, fallback: 'Failed to load summary');
    }
  }

  Future<void> clearLocalData() async {
    await OfflinePosStore.instance.clearAll();
  }
}
