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
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _cashierNameKey = 'cashier_name';
  static const _userIdKey = 'user_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier() : super(AuthStateData());

  Future<void> checkAuth() async {
    final token = await _storage.read(key: _accessTokenKey);
    final name = await _storage.read(key: _cashierNameKey);
    final userId = await _storage.read(key: _userIdKey);
    if (token != null) {
      state = AuthStateData(
        isAuthenticated: true,
        token: token,
        cashierName: name,
        userId: int.tryParse(userId ?? ''),
      );
    }
  }

  Future<void> login(
    String token,
    String refreshToken,
    String cashierName,
    int userId,
  ) async {
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _cashierNameKey, value: cashierName);
    await _storage.write(key: _userIdKey, value: userId.toString());
    state = AuthStateData(
      isAuthenticated: true,
      token: token,
      cashierName: cashierName,
      userId: userId,
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _cashierNameKey);
    await _storage.delete(key: _userIdKey);
    state = AuthStateData();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateData>((ref) {
  return AuthNotifier();
});
