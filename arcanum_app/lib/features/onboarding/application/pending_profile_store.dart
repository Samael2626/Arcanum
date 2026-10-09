import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PendingProfileStore {
  Future<void> save(String userId, Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> readFor(String userId);
  Future<void> clear();
}

Future<void> purgeLegacyOnboardingData() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in const [
    'onboarding_pending_profile',
    'onboarding_display_name',
    'onboarding_birth_date',
    'onboarding_birth_time',
    'onboarding_birth_country',
    'onboarding_birth_city',
  ]) {
    await prefs.remove(key);
  }
}

class SecurePendingProfileStore implements PendingProfileStore {
  SecurePendingProfileStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'arcanum_onboarding_pending_profile_v2';
  final FlutterSecureStorage _storage;

  @override
  Future<void> save(String userId, Map<String, dynamic> profile) async {
    await purgeLegacyOnboardingData();
    await _storage.write(
      key: _key,
      value: jsonEncode({'user_id': userId, 'profile': profile}),
    );
  }

  @override
  Future<Map<String, dynamic>?> readFor(String userId) async {
    await purgeLegacyOnboardingData();
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['user_id'] != userId) return null;
    return Map<String, dynamic>.from(data['profile'] as Map);
  }

  @override
  Future<void> clear() async {
    await purgeLegacyOnboardingData();
    await _storage.delete(key: _key);
  }
}

final pendingProfileStoreProvider = Provider<PendingProfileStore>(
  (ref) => SecurePendingProfileStore(),
);
