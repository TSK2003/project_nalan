import 'dart:async';

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
  static const _sessionExpiryKey = 'session_expires_at';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _sessionExpiryTimer;

  AuthNotifier() : super(AuthStateData());

  DateTime _nextMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  Future<void> _scheduleSessionExpiry({DateTime? expiresAt}) async {
    _sessionExpiryTimer?.cancel();
    final target = expiresAt ?? _nextMidnight();
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      await logout();
      return;
    }
    _sessionExpiryTimer = Timer(remaining, () async {
      await logout();
    });
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: _accessTokenKey);
    final name = await _storage.read(key: _cashierNameKey);
    final userId = await _storage.read(key: _userIdKey);
    final expiryRaw = await _storage.read(key: _sessionExpiryKey);
    if (token == null) {
      _sessionExpiryTimer?.cancel();
      state = AuthStateData();
      return;
    }

    DateTime? expiresAt =
        expiryRaw == null ? null : DateTime.tryParse(expiryRaw);
    if (expiresAt != null && !DateTime.now().isBefore(expiresAt)) {
      await logout();
      return;
    }

    if (expiresAt == null) {
      expiresAt = _nextMidnight();
      await _storage.write(
        key: _sessionExpiryKey,
        value: expiresAt.toIso8601String(),
      );
    }
    state = AuthStateData(
      isAuthenticated: true,
      token: token,
      cashierName: name,
      userId: int.tryParse(userId ?? ''),
    );
    await _scheduleSessionExpiry(expiresAt: expiresAt);
  }

  Future<void> login(
    String token,
    String refreshToken,
    String cashierName,
    int userId,
  ) async {
    final expiresAt = _nextMidnight();
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _cashierNameKey, value: cashierName);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(
      key: _sessionExpiryKey,
      value: expiresAt.toIso8601String(),
    );
    state = AuthStateData(
      isAuthenticated: true,
      token: token,
      cashierName: cashierName,
      userId: userId,
    );
    await _scheduleSessionExpiry(expiresAt: expiresAt);
  }

  Future<void> logout() async {
    _sessionExpiryTimer?.cancel();
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _cashierNameKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _sessionExpiryKey);
    state = AuthStateData();
  }

  @override
  void dispose() {
    _sessionExpiryTimer?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateData>((ref) {
  return AuthNotifier();
});
