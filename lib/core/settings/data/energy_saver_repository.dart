import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final energySaverRepositoryProvider = Provider<EnergySaverRepository>((ref) {
  return EnergySaverRepository(const FlutterSecureStorage());
});

/// Whether Mode Hemat Energi is on — a device-local display preference, not
/// financial data, so no Supabase table for this (same reasoning as
/// [OnboardingRepository]/[AppLockRepository] reusing flutter_secure_storage
/// over pulling in shared_preferences for one flag).
final energySaverEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(energySaverRepositoryProvider).isEnabled();
});

/// Manual fallback for liquid glass's `BackdropFilter` blur, which CLAUDE.md
/// flags as heavy on entry-level GPUs (confirmed sluggish on the OPPO A3s
/// test device). When on, [LiquidGlassSurface] swaps the blur for a
/// near-opaque solid fill instead — same shape/edges, no blur compositing.
class EnergySaverRepository {
  EnergySaverRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const _enabledKey = 'energy_saver_enabled';

  Future<bool> isEnabled() async {
    return await _storage.read(key: _enabledKey) == 'true';
  }

  Future<void> setEnabled(bool value) {
    return _storage.write(key: _enabledKey, value: value.toString());
  }
}
