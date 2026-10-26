import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

/// Small secrets and session state that should survive app restarts and
/// stay out of the (plain SQLite) database:
/// - the signed-in user's profile snapshot, so the app can open straight
///   into the home screen offline without waiting for Firebase
/// - the FCM push token for this device
/// - a per-install device id (used as a default client id for local rows)
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kSession = 'session_snapshot';
  static const _kFcmToken = 'fcm_token';
  static const _kDeviceId = 'device_id';
  static const _kOnboardingSeen = 'onboarding_seen_v1';
  static const _kThemeMode = 'theme_mode_v1';
  static const _kAdFreeStatus = 'adfree_status_v1';

  // -------------------------------------------------------------- onboarding

  /// Whether the one-time onboarding flow has been completed/skipped
  /// on this install. Per-device, not per-user: it is NOT cleared on
  /// sign-out, so it shows exactly once per install.
  Future<bool> isOnboardingSeen() async =>
      (await _storage.read(key: _kOnboardingSeen)) == 'true';

  Future<void> markOnboardingSeen() =>
      _storage.write(key: _kOnboardingSeen, value: 'true');

  // -------------------------------------------------------------- appearance

  /// The chosen app appearance, one of 'system' | 'light' | 'dark'.
  /// Per-device preference (not synced); defaults to 'system'.
  Future<String> loadThemeMode() async =>
      (await _storage.read(key: _kThemeMode)) ?? 'system';

  Future<void> saveThemeMode(String mode) =>
      _storage.write(key: _kThemeMode, value: mode);

  // -------------------------------------------------------------------- pro

  /// Last-known Ad-Free entitlement, cached per install so the app
  /// starts with the right tier offline. RevenueCat is the source
  /// of truth and refreshes this whenever it is reachable.
  Future<bool> loadAdFreeStatus() async =>
      (await _storage.read(key: _kAdFreeStatus)) == 'true';

  Future<void> saveAdFreeStatus(bool isAdFree) =>
      _storage.write(key: _kAdFreeStatus, value: isAdFree ? 'true' : 'false');

  // ---------------------------------------------------------------- session

  Future<void> saveSession(AppUser user) => _storage.write(
      key: _kSession,
      value: jsonEncode({
        'uid': user.uid,
        ...user.toProfileMap(),
      }));

  Future<AppUser?> loadSession() async {
    final raw = await _storage.read(key: _kSession);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final uid = map['uid'] as String?;
      if (uid == null) return null;
      return AppUser.fromMap(uid, map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() => _storage.delete(key: _kSession);

  // -------------------------------------------------------------------- fcm

  Future<void> saveFcmToken(String token) =>
      _storage.write(key: _kFcmToken, value: token);

  Future<String?> loadFcmToken() => _storage.read(key: _kFcmToken);

  Future<void> clearFcmToken() => _storage.delete(key: _kFcmToken);

  // ----------------------------------------------------------------- device

  /// Stable random id for this install, created lazily.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null) return existing;
    final id = 'dev-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await _storage.write(key: _kDeviceId, value: id);
    return id;
  }
}
