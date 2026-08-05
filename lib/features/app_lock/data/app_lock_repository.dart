import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  return AppLockRepository(const FlutterSecureStorage(), LocalAuthentication());
});

final appLockEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(appLockRepositoryProvider).isEnabled();
});

class AppLockRepository {
  AppLockRepository(this._storage, this._localAuth);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _enabledKey = 'app_lock_enabled';
  static const _pinHashKey = 'app_lock_pin_hash';

  Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  /// Hashes and stores the PIN, then turns the lock on.
  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinHashKey, value: _hash(pin));
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<void> disable() async {
    await _storage.write(key: _enabledKey, value: 'false');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    return stored != null && stored == _hash(pin);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verifikasi buat buka KIRAIN',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}
