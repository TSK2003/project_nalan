import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoreProfileState {
  final bool isLoaded;
  final bool isConfigured;
  final String hotelName;
  final String tagline;
  final String address;
  final String phone;
  final String loginMobileNumber;
  final String logoPath;
  final int primaryColorValue;

  const StoreProfileState({
    required this.isLoaded,
    required this.isConfigured,
    required this.hotelName,
    required this.tagline,
    required this.address,
    required this.phone,
    required this.loginMobileNumber,
    required this.logoPath,
    required this.primaryColorValue,
  });

  const StoreProfileState.defaults()
    : isLoaded = false,
      isConfigured = false,
      hotelName = 'My Store POS',
      tagline = 'Configure your store profile',
      address = '',
      phone = '',
      loginMobileNumber = '',
      logoPath = '',
      primaryColorValue = 0xFFE65100;

  Color get primaryColor => Color(primaryColorValue);

  StoreProfileState copyWith({
    bool? isLoaded,
    bool? isConfigured,
    String? hotelName,
    String? tagline,
    String? address,
    String? phone,
    String? loginMobileNumber,
    String? logoPath,
    int? primaryColorValue,
  }) {
    return StoreProfileState(
      isLoaded: isLoaded ?? this.isLoaded,
      isConfigured: isConfigured ?? this.isConfigured,
      hotelName: hotelName ?? this.hotelName,
      tagline: tagline ?? this.tagline,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      loginMobileNumber: loginMobileNumber ?? this.loginMobileNumber,
      logoPath: logoPath ?? this.logoPath,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hotelName': hotelName,
      'tagline': tagline,
      'address': address,
      'phone': phone,
      'loginMobileNumber': loginMobileNumber,
      'logoPath': logoPath,
      'primaryColorValue': primaryColorValue,
    };
  }

  factory StoreProfileState.fromJson(Map<String, dynamic> json) {
    return StoreProfileState(
      isLoaded: true,
      isConfigured: true,
      hotelName: json['hotelName'] as String? ?? 'My Store POS',
      tagline: json['tagline'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      loginMobileNumber: json['loginMobileNumber'] as String? ?? '',
      logoPath: json['logoPath'] as String? ?? '',
      primaryColorValue: json['primaryColorValue'] as int? ?? 0xFFE65100,
    );
  }
}

class StoreProfileNotifier extends StateNotifier<StoreProfileState> {
  StoreProfileNotifier() : super(const StoreProfileState.defaults());

  static const _storageKey = 'store_profile_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> loadProfile() async {
    if (state.isLoaded) {
      return;
    }

    final savedValue = await _storage.read(key: _storageKey);
    if (savedValue == null || savedValue.isEmpty) {
      state = const StoreProfileState.defaults().copyWith(isLoaded: true);
      return;
    }

    final decoded = jsonDecode(savedValue) as Map<String, dynamic>;
    state = StoreProfileState.fromJson(decoded);
  }

  Future<void> saveProfile(StoreProfileState profile) async {
    final nextState = profile.copyWith(isLoaded: true, isConfigured: true);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(nextState.toJson()),
    );
    state = nextState;
  }

  Future<void> clearProfile() async {
    await _storage.delete(key: _storageKey);
    state = const StoreProfileState.defaults().copyWith(isLoaded: true);
  }
}

final storeProfileProvider =
    StateNotifierProvider<StoreProfileNotifier, StoreProfileState>((ref) {
      return StoreProfileNotifier();
    });

const themeColorOptions = <Color>[
  Color(0xFFE65100),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFF37474F),
  Color(0xFFC62828),
];
