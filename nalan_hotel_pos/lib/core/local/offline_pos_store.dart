import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflineStoreException implements Exception {
  final String message;

  const OfflineStoreException(this.message);

  @override
  String toString() => message;
}

class OfflinePosStore {
  OfflinePosStore._();

  static final OfflinePosStore instance = OfflinePosStore._();

  static const _fileName = 'offline_pos_store_v1.json';

  Future<File> _stateFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _loadState() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      final initialState = _defaultState();
      await _saveState(initialState);
      return initialState;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      final initialState = _defaultState();
      await _saveState(initialState);
      return initialState;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return _normalizeState(decoded);
  }

  Future<void> _saveState(Map<String, dynamic> state) async {
    final file = await _stateFile();
    await file.writeAsString(jsonEncode(state), flush: true);
  }

  Map<String, dynamic> _defaultState() {
    final now = DateTime.now().toIso8601String();
    final menu = <Map<String, dynamic>>[
      _seedMenuItem(1, 'Idli', 'TIFFIN', 35, now),
      _seedMenuItem(2, 'Plain Dosa', 'TIFFIN', 55, now),
      _seedMenuItem(3, 'Meals', 'LUNCH', 120, now),
      _seedMenuItem(4, 'Veg Fried Rice', 'LUNCH', 140, now),
      _seedMenuItem(5, 'Chapati Set', 'DINNER', 90, now),
      _seedMenuItem(6, 'Parotta', 'DINNER', 60, now),
      _seedMenuItem(7, 'Tea', 'BEVERAGES', 18, now),
      _seedMenuItem(8, 'Coffee', 'BEVERAGES', 25, now),
    ];

    return {
      'next_menu_item_id': 9,
      'next_bill_id': 1,
      'next_bill_sequence': 1,
      'next_upi_id': 1,
      'next_user_id': 1,
      'menu_items': menu,
      'bills': <Map<String, dynamic>>[],
      'upi_accounts': <Map<String, dynamic>>[],
      'auth_users': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _normalizeState(Map<String, dynamic> state) {
    return {
      'next_menu_item_id': state['next_menu_item_id'] as int? ?? 1,
      'next_bill_id': state['next_bill_id'] as int? ?? 1,
      'next_bill_sequence': state['next_bill_sequence'] as int? ?? 1,
      'next_upi_id': state['next_upi_id'] as int? ?? 1,
      'next_user_id': state['next_user_id'] as int? ?? 1,
      'menu_items': List<Map<String, dynamic>>.from(
        (state['menu_items'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      'bills': List<Map<String, dynamic>>.from(
        (state['bills'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      'upi_accounts': List<Map<String, dynamic>>.from(
        (state['upi_accounts'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      'auth_users': List<Map<String, dynamic>>.from(
        (state['auth_users'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
    };
  }

  Map<String, dynamic> _seedMenuItem(
    int id,
    String name,
    String category,
    double price,
    String now,
  ) {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'is_available': true,
      'created_at': now,
      'updated_at': now,
    };
  }

  Map<String, dynamic> _copyJsonMap(Map<String, dynamic> value) {
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _copyJsonList(List<dynamic> value) {
    return List<Map<String, dynamic>>.from(
      (jsonDecode(jsonEncode(value)) as List<dynamic>).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  String _buildBillNumber(int sequence, DateTime now) {
    final datePrefix =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'BILL-$datePrefix-${sequence.toString().padLeft(4, '0')}';
  }

  List<Map<String, dynamic>> _registeredAuthUsers(Map<String, dynamic> state) {
    return List<Map<String, dynamic>>.from(
      (state['auth_users'] as List).where(
        (user) => (user as Map<String, dynamic>)['is_active'] != false,
      ),
    );
  }

  Map<String, dynamic> _buildAuthPayload(Map<String, dynamic> user) {
    final displayName =
        (user['full_name'] as String?)?.trim().isNotEmpty == true
            ? user['full_name']
            : user['mobile_number'];
    return {
      'token': 'offline-${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': 'offline-refresh-token',
      'cashier_name': displayName,
      'user_id': user['id'] as int? ?? 1,
    };
  }

  Future<bool> hasRegisteredAuthUsers() async {
    final state = await _loadState();
    return _registeredAuthUsers(state).isNotEmpty;
  }

  Future<Map<String, dynamic>> registerLocalAuthUser({
    required String mobileNumber,
    required String password,
    String? fullName,
  }) async {
    final trimmedMobile = mobileNumber.trim();
    final trimmedPassword = password.trim();
    if (trimmedMobile.length < 10) {
      throw const OfflineStoreException('Enter a valid mobile number');
    }
    if (trimmedPassword.length < 4) {
      throw const OfflineStoreException(
        'Password must be at least 4 characters',
      );
    }

    final state = await _loadState();
    final users = List<Map<String, dynamic>>.from(state['auth_users'] as List);
    final now = DateTime.now().toIso8601String();
    final existingUserIndex = users.indexWhere(
      (user) =>
          user['is_active'] != false &&
          (user['mobile_number']?.toString() ?? '') == trimmedMobile,
    );
    if (existingUserIndex != -1) {
      throw const OfflineStoreException(
        'An account already exists with this mobile number',
      );
    }

    final savedUser = {
      'id': state['next_user_id'] as int,
      'mobile_number': trimmedMobile,
      'password': trimmedPassword,
      'full_name': (fullName ?? '').trim(),
      'is_active': true,
      'created_at': now,
      'updated_at': now,
      'last_login_at': null,
    };
    users.add(savedUser);
    state['next_user_id'] = (state['next_user_id'] as int) + 1;
    state['auth_users'] = users;
    await _saveState(state);
    return _copyJsonMap(savedUser);
  }

  Future<void> clearLocalAuthUsers() async {
    final state = await _loadState();
    state['auth_users'] = <Map<String, dynamic>>[];
    await _saveState(state);
  }

  Future<Map<String, dynamic>> loginWithLocalCredentials({
    required String mobileNumber,
    required String password,
  }) async {
    final trimmedMobile = mobileNumber.trim();
    final trimmedPassword = password.trim();
    final state = await _loadState();
    final users = List<Map<String, dynamic>>.from(state['auth_users'] as List);
    final registeredUsers = _registeredAuthUsers(state);
    if (registeredUsers.isEmpty) {
      throw const OfflineStoreException(
        'No user account found. Register a new user first',
      );
    }
    final userIndex = users.indexWhere(
      (user) =>
          user['is_active'] != false &&
          (user['mobile_number']?.toString() ?? '') == trimmedMobile,
    );
    if (userIndex == -1 ||
        (users[userIndex]['password']?.toString() ?? '') != trimmedPassword) {
      throw const OfflineStoreException('Invalid mobile number or password');
    }
    final now = DateTime.now().toIso8601String();
    final user = {...users[userIndex], 'updated_at': now, 'last_login_at': now};
    users[userIndex] = user;
    state['auth_users'] = users;
    await _saveState(state);
    return _buildAuthPayload(user);
  }

  Future<List<Map<String, dynamic>>> getMenu({
    bool availableOnly = false,
  }) async {
    final state = await _loadState();
    final items = List<Map<String, dynamic>>.from(state['menu_items'] as List);
    items.sort((a, b) {
      final categoryOrder = (a['category'] as String).compareTo(
        b['category'] as String,
      );
      if (categoryOrder != 0) {
        return categoryOrder;
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    final filtered =
        availableOnly
            ? items.where((item) => item['is_available'] == true).toList()
            : items;
    return _copyJsonList(filtered);
  }

  Future<Map<String, dynamic>> saveMenuItem({
    int? id,
    required String name,
    required String category,
    required double price,
    bool isAvailable = true,
  }) async {
    final state = await _loadState();
    final items = List<Map<String, dynamic>>.from(state['menu_items'] as List);
    final trimmedName = name.trim();
    final now = DateTime.now().toIso8601String();

    if (trimmedName.isEmpty) {
      throw const OfflineStoreException('Enter item name');
    }
    if (price <= 0) {
      throw const OfflineStoreException('Enter a valid price');
    }

    final duplicate = items.any(
      (item) =>
          item['id'] != id &&
          (item['name'] as String).toLowerCase() == trimmedName.toLowerCase() &&
          item['category'] == category,
    );
    if (duplicate) {
      throw OfflineStoreException(
        '"$trimmedName" already exists in $category.',
      );
    }

    late Map<String, dynamic> savedItem;
    if (id == null) {
      savedItem = {
        'id': state['next_menu_item_id'] as int,
        'name': trimmedName,
        'category': category,
        'price': price,
        'is_available': isAvailable,
        'created_at': now,
        'updated_at': now,
      };
      items.add(savedItem);
      state['next_menu_item_id'] = (state['next_menu_item_id'] as int) + 1;
    } else {
      final index = items.indexWhere((item) => item['id'] == id);
      if (index == -1) {
        throw const OfflineStoreException('Menu item not found');
      }
      savedItem = {
        ...items[index],
        'name': trimmedName,
        'category': category,
        'price': price,
        'is_available': isAvailable,
        'updated_at': now,
      };
      items[index] = savedItem;
    }

    state['menu_items'] = items;
    await _saveState(state);
    return _copyJsonMap(savedItem);
  }

  Future<void> toggleMenuAvailability(int id) async {
    final state = await _loadState();
    final items = List<Map<String, dynamic>>.from(state['menu_items'] as List);
    final index = items.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw const OfflineStoreException('Menu item not found');
    }
    items[index] = {
      ...items[index],
      'is_available': !(items[index]['is_available'] as bool? ?? true),
      'updated_at': DateTime.now().toIso8601String(),
    };
    state['menu_items'] = items;
    await _saveState(state);
  }

  Future<void> deleteMenuItem(int id) async {
    final state = await _loadState();
    final items = List<Map<String, dynamic>>.from(state['menu_items'] as List);
    state['menu_items'] = items.where((item) => item['id'] != id).toList();
    await _saveState(state);
  }

  Future<Map<String, dynamic>> createBill({
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) {
      throw const OfflineStoreException('Add items before creating a bill');
    }

    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final now = DateTime.now();
    final normalizedItems =
        items.map((item) {
          final quantity = item['quantity'] as int? ?? 1;
          final price = _asDouble(item['price']);
          final total = price * quantity;
          return {
            'menu_item_id': item['menu_item_id'],
            'name': item['name'],
            'item_name': item['name'],
            'category': item['category'],
            'price': price,
            'quantity': quantity,
            'total': total,
            'line_total': total,
          };
        }).toList();

    final subtotal = normalizedItems.fold<double>(
      0,
      (sum, item) => sum + _asDouble(item['total']),
    );
    final bill = <String, dynamic>{
      'id': state['next_bill_id'] as int,
      'bill_number': _buildBillNumber(state['next_bill_sequence'] as int, now),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'status': 'PENDING_PAYMENT',
      'payment_mode': null,
      'subtotal': subtotal,
      'subtotal_amount': subtotal,
      'discount_amount': 0.0,
      'total_amount': subtotal,
      'item_count': normalizedItems.fold<int>(
        0,
        (sum, item) => sum + (item['quantity'] as int? ?? 0),
      ),
      'cash_received': null,
      'cash_change': null,
      'upi_account_id': null,
      'upi_id_used': null,
      'upi_qr_string': null,
      'upi_ref_id': null,
      'items': normalizedItems,
    };

    bills.add(bill);
    state['bills'] = bills;
    state['next_bill_id'] = (state['next_bill_id'] as int) + 1;
    state['next_bill_sequence'] = (state['next_bill_sequence'] as int) + 1;
    await _saveState(state);
    return _copyJsonMap(bill);
  }

  Future<Map<String, dynamic>> getBill(int billId) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final bill = bills.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == billId,
      orElse: () => null,
    );
    if (bill == null) {
      throw const OfflineStoreException('Bill not found');
    }
    return _copyJsonMap(bill);
  }

  Future<List<Map<String, dynamic>>> listBills({String query = ''}) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final normalizedQuery = query.trim().toLowerCase();
    final filtered =
        normalizedQuery.isEmpty
            ? bills
            : bills.where((bill) {
              final billNumber =
                  (bill['bill_number'] as String? ?? '').toLowerCase();
              final total = _asDouble(bill['total_amount']).toStringAsFixed(2);
              return billNumber.contains(normalizedQuery) ||
                  total.contains(normalizedQuery);
            }).toList();
    filtered.sort(
      (a, b) =>
          _parseDate(b['created_at']).compareTo(_parseDate(a['created_at'])),
    );
    return _copyJsonList(filtered);
  }

  Future<List<Map<String, dynamic>>> listUpiAccounts() async {
    final state = await _loadState();
    final accounts =
        List<Map<String, dynamic>>.from(
          state['upi_accounts'] as List,
        ).where((account) => account['is_active'] == true).toList();
    accounts.sort((a, b) {
      final aDefault = a['is_default'] == true ? 0 : 1;
      final bDefault = b['is_default'] == true ? 0 : 1;
      if (aDefault != bDefault) {
        return aDefault.compareTo(bDefault);
      }
      return _parseDate(a['created_at']).compareTo(_parseDate(b['created_at']));
    });
    return _copyJsonList(accounts);
  }

  Future<Map<String, dynamic>> saveUpiAccount({
    int? id,
    required String label,
    required String upiId,
  }) async {
    final state = await _loadState();
    final accounts = List<Map<String, dynamic>>.from(
      state['upi_accounts'] as List,
    );
    final trimmedLabel = label.trim();
    final trimmedUpiId = upiId.trim();
    final now = DateTime.now().toIso8601String();

    if (trimmedLabel.isEmpty) {
      throw const OfflineStoreException('Enter a label');
    }
    if (!trimmedUpiId.contains('@')) {
      throw const OfflineStoreException('Enter a valid UPI ID');
    }

    final duplicate = accounts.any(
      (account) =>
          account['id'] != id &&
          account['is_active'] == true &&
          (account['upi_id'] as String).toLowerCase() ==
              trimmedUpiId.toLowerCase(),
    );
    if (duplicate) {
      throw OfflineStoreException(
        "UPI ID '$trimmedUpiId' is already registered.",
      );
    }

    final activeCount =
        accounts.where((account) => account['is_active'] == true).length;
    if (id == null && activeCount >= 3) {
      throw const OfflineStoreException(
        'Maximum 3 UPI accounts allowed. Please delete an existing account first.',
      );
    }

    late Map<String, dynamic> saved;
    if (id == null) {
      saved = {
        'id': state['next_upi_id'] as int,
        'label': trimmedLabel,
        'upi_id': trimmedUpiId,
        'is_default': activeCount == 0,
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      };
      accounts.add(saved);
      state['next_upi_id'] = (state['next_upi_id'] as int) + 1;
    } else {
      final index = accounts.indexWhere((account) => account['id'] == id);
      if (index == -1) {
        throw const OfflineStoreException('UPI account not found');
      }
      saved = {
        ...accounts[index],
        'label': trimmedLabel,
        'upi_id': trimmedUpiId,
        'updated_at': now,
      };
      accounts[index] = saved;
    }

    state['upi_accounts'] = accounts;
    await _saveState(state);
    return _copyJsonMap(saved);
  }

  Future<void> setDefaultUpiAccount(int id) async {
    final state = await _loadState();
    final accounts = List<Map<String, dynamic>>.from(
      state['upi_accounts'] as List,
    );
    final index = accounts.indexWhere(
      (account) => account['id'] == id && account['is_active'] == true,
    );
    if (index == -1) {
      throw const OfflineStoreException('UPI account not found');
    }

    for (var i = 0; i < accounts.length; i++) {
      accounts[i] = {
        ...accounts[i],
        'is_default':
            accounts[i]['id'] == id && accounts[i]['is_active'] == true,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
    state['upi_accounts'] = accounts;
    await _saveState(state);
  }

  Future<void> deleteUpiAccount(int id) async {
    final state = await _loadState();
    final accounts = List<Map<String, dynamic>>.from(
      state['upi_accounts'] as List,
    );
    final index = accounts.indexWhere(
      (account) => account['id'] == id && account['is_active'] == true,
    );
    if (index == -1) {
      throw const OfflineStoreException('UPI account not found');
    }

    final wasDefault = accounts[index]['is_default'] == true;
    accounts[index] = {
      ...accounts[index],
      'is_active': false,
      'is_default': false,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (wasDefault) {
      final replacementIndex = accounts.indexWhere(
        (account) => account['id'] != id && account['is_active'] == true,
      );
      if (replacementIndex != -1) {
        accounts[replacementIndex] = {
          ...accounts[replacementIndex],
          'is_default': true,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
    }

    state['upi_accounts'] = accounts;
    await _saveState(state);
  }

  Future<Map<String, dynamic>> confirmCashPayment(
    int billId, {
    required double cashReceived,
  }) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final index = bills.indexWhere((bill) => bill['id'] == billId);
    if (index == -1) {
      throw const OfflineStoreException('Bill not found');
    }
    final bill = bills[index];
    final total = _asDouble(bill['total_amount']);
    if (cashReceived < total) {
      throw const OfflineStoreException('Cash received is less than total');
    }

    final updated = {
      ...bill,
      'status': 'PAID',
      'payment_mode': 'CASH',
      'cash_received': cashReceived,
      'cash_change': cashReceived - total,
      'updated_at': DateTime.now().toIso8601String(),
    };
    bills[index] = updated;
    state['bills'] = bills;
    await _saveState(state);
    return _copyJsonMap(updated);
  }

  Future<Map<String, dynamic>> initiateUpiPayment(
    int billId, {
    required int upiAccountId,
  }) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final accounts = List<Map<String, dynamic>>.from(
      state['upi_accounts'] as List,
    );
    final billIndex = bills.indexWhere((bill) => bill['id'] == billId);
    if (billIndex == -1) {
      throw const OfflineStoreException('Bill not found');
    }
    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == upiAccountId && item?['is_active'] == true,
      orElse: () => null,
    );
    if (account == null) {
      throw const OfflineStoreException('No active UPI account available');
    }

    final bill = bills[billIndex];
    final total = _asDouble(bill['total_amount']);
    final qr = _buildUpiQrString(
      upiId: account['upi_id'] as String,
      payeeName: account['label'] as String,
      amount: total,
      billNumber: bill['bill_number'] as String,
    );

    final updated = {
      ...bill,
      'status': 'PENDING_PAYMENT',
      'payment_mode': 'UPI',
      'cash_received': 0.0,
      'cash_change': 0.0,
      'upi_amount': total,
      'upi_status': 'PENDING',
      'upi_account_id': upiAccountId,
      'upi_id_used': account['upi_id'],
      'upi_qr_string': qr,
      'updated_at': DateTime.now().toIso8601String(),
    };
    bills[billIndex] = updated;
    state['bills'] = bills;
    await _saveState(state);
    return {
      'status': 'PENDING_PAYMENT',
      'payment_mode': 'UPI',
      'upi_qr_string': qr,
      'upi_amount': total,
      'cash_received': 0.0,
      'upi_id_used': account['upi_id'],
    };
  }

  Future<Map<String, dynamic>> initiateSplitPayment(
    int billId, {
    required double cashAmount,
    required int upiAccountId,
  }) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final accounts = List<Map<String, dynamic>>.from(
      state['upi_accounts'] as List,
    );
    final billIndex = bills.indexWhere((bill) => bill['id'] == billId);
    if (billIndex == -1) {
      throw const OfflineStoreException('Bill not found');
    }

    final account = accounts.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == upiAccountId && item?['is_active'] == true,
      orElse: () => null,
    );
    if (account == null) {
      throw const OfflineStoreException('No active UPI account available');
    }

    final bill = bills[billIndex];
    final total = _asDouble(bill['total_amount']);
    if (cashAmount <= 0) {
      throw const OfflineStoreException('Enter the cash amount first');
    }
    if (cashAmount >= total) {
      throw const OfflineStoreException(
        'Cash amount must be less than the total bill',
      );
    }

    final upiAmount = total - cashAmount;
    final qr = _buildUpiQrString(
      upiId: account['upi_id'] as String,
      payeeName: account['label'] as String,
      amount: upiAmount,
      billNumber: bill['bill_number'] as String,
    );

    final updated = {
      ...bill,
      'status': 'PENDING_PAYMENT',
      'payment_mode': 'SPLIT',
      'cash_received': cashAmount,
      'cash_change': 0.0,
      'upi_amount': upiAmount,
      'upi_status': 'PENDING',
      'upi_account_id': upiAccountId,
      'upi_id_used': account['upi_id'],
      'upi_qr_string': qr,
      'updated_at': DateTime.now().toIso8601String(),
    };
    bills[billIndex] = updated;
    state['bills'] = bills;
    await _saveState(state);
    return {
      'status': 'PENDING_PAYMENT',
      'payment_mode': 'SPLIT',
      'upi_qr_string': qr,
      'cash_received': cashAmount,
      'upi_amount': upiAmount,
      'upi_id_used': account['upi_id'],
    };
  }

  Future<Map<String, dynamic>> paymentStatus(int billId) async {
    final bill = await getBill(billId);
    return {
      'status': bill['status'] == 'PAID' ? 'PAID' : 'PENDING_PAYMENT',
      'payment_mode': bill['payment_mode'],
      'total_amount': bill['total_amount'],
      'cash_received': bill['cash_received'],
      'cash_change': bill['cash_change'],
      'upi_amount': bill['upi_amount'],
      'upi_qr_string': bill['upi_qr_string'],
      'upi_ref_id': bill['upi_ref_id'],
      'upi_id_used': bill['upi_id_used'],
    };
  }

  Future<Map<String, dynamic>> simulateUpiWebhookSuccess(int billId) async {
    final state = await _loadState();
    final bills = List<Map<String, dynamic>>.from(state['bills'] as List);
    final index = bills.indexWhere((bill) => bill['id'] == billId);
    if (index == -1) {
      throw const OfflineStoreException('Bill not found');
    }

    final bill = bills[index];
    final paymentMode = bill['payment_mode'] as String? ?? 'UPI';
    final updated = {
      ...bill,
      'status': 'PAID',
      'payment_mode': paymentMode,
      'upi_ref_id': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      'upi_status': 'SUCCESS',
      'upi_qr_string': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    bills[index] = updated;
    state['bills'] = bills;
    await _saveState(state);
    return _copyJsonMap(updated);
  }

  String _buildUpiQrString({
    required String upiId,
    required String payeeName,
    required double amount,
    required String billNumber,
  }) {
    return 'upi://pay'
        '?pa=${Uri.encodeComponent(upiId)}'
        '&pn=${Uri.encodeComponent(payeeName)}'
        '&am=${amount.toStringAsFixed(2)}'
        '&cu=INR'
        '&tn=${Uri.encodeComponent(billNumber)}';
  }

  Future<Map<String, dynamic>> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final bills = await listBills();
    final today = DateTime.now();
    final effectiveFrom =
        fromDate ?? DateTime(today.year, today.month, today.day);
    final effectiveTo = toDate ?? DateTime(today.year, today.month, today.day);
    final startDay = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );
    final endDay = DateTime(
      effectiveTo.year,
      effectiveTo.month,
      effectiveTo.day,
    );
    final paidBills =
        bills.where((bill) => bill['status'] == 'PAID').where((bill) {
          final createdAt = _parseDate(bill['created_at']);
          final billDay = DateTime(
            createdAt.year,
            createdAt.month,
            createdAt.day,
          );
          return !billDay.isBefore(startDay) && !billDay.isAfter(endDay);
        }).toList();

    final totalSales = paidBills.fold<double>(
      0,
      (sum, bill) => sum + _asDouble(bill['total_amount']),
    );
    final cashTotal = paidBills.fold<double>((0), (sum, bill) {
      final mode = bill['payment_mode'];
      if (mode == 'CASH') {
        return sum + _asDouble(bill['total_amount']);
      }
      if (mode == 'SPLIT') {
        return sum + _asDouble(bill['cash_received']);
      }
      return sum;
    });
    final upiTotal = paidBills.fold<double>((0), (sum, bill) {
      final mode = bill['payment_mode'];
      if (mode == 'UPI') {
        return sum + _asDouble(bill['total_amount']);
      }
      if (mode == 'SPLIT') {
        return sum + _asDouble(bill['upi_amount']);
      }
      return sum;
    });
    final splitTotal = paidBills
        .where((bill) => bill['payment_mode'] == 'SPLIT')
        .fold<double>(0, (sum, bill) => sum + _asDouble(bill['total_amount']));

    final categoryBreakdown = <String, Map<String, dynamic>>{};
    for (final bill in paidBills) {
      for (final item in bill['items'] as List<dynamic>) {
        final line = Map<String, dynamic>.from(item as Map);
        final category = line['category'] as String? ?? 'OTHER';
        final existing =
            categoryBreakdown[category] ?? {'count': 0, 'total': 0.0};
        categoryBreakdown[category] = {
          'count': (existing['count'] as int) + (line['quantity'] as int? ?? 0),
          'total': _asDouble(existing['total']) + _asDouble(line['total']),
        };
      }
    }

    return {
      if (fromDate != null && toDate != null) ...{
        'date_from':
            DateTime(
              effectiveFrom.year,
              effectiveFrom.month,
              effectiveFrom.day,
            ).toIso8601String(),
        'date_to':
            DateTime(
              effectiveTo.year,
              effectiveTo.month,
              effectiveTo.day,
            ).toIso8601String(),
      } else
        'date': DateTime(today.year, today.month, today.day).toIso8601String(),
      'total_sales': totalSales,
      'total_bills': paidBills.length,
      'cash_total': cashTotal,
      'upi_total': upiTotal,
      'split_total': splitTotal,
      'category_breakdown': categoryBreakdown,
    };
  }

  Future<void> clearAll() async {
    final file = await _stateFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
