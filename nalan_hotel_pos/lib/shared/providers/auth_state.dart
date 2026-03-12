import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStateData {
  final bool isAuthenticated;
  final String? token;
  final String? cashierName;
  final int? userId;

  AuthStateData({
    this.isAuthenticated = false,
    this.token,
    this.cashierName,
    this.userId,
  });

  AuthStateData copyWith({
    bool? isAuthenticated,
    String? token,
    String? cashierName,
    int? userId,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      cashierName: cashierName ?? this.cashierName,
      userId: userId ?? this.userId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthStateData> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier() : super(AuthStateData());

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'access_token');
    final name = await _storage.read(key: 'cashier_name');
    if (token != null) {
      state = AuthStateData(
        isAuthenticated: true,
        token: token,
        cashierName: name,
      );
    }
  }

  Future<void> login(String token, String refreshToken, String cashierName, int userId) async {
    await _storage.write(key: 'access_token', value: token);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'cashier_name', value: cashierName);
    state = AuthStateData(
      isAuthenticated: true,
      token: token,
      cashierName: cashierName,
      userId: userId,
    );
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthStateData();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateData>((ref) {
  return AuthNotifier();
});
