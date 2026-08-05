import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(const FlutterSecureStorage());
});

/// Whether the user has been through the intro slides — a device-local
/// flag, not financial data, so no Supabase table for this. Reuses
/// flutter_secure_storage (already a dependency for App Lock) rather than
/// pulling in shared_preferences for a single boolean.
class OnboardingRepository {
  OnboardingRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    return await _storage.read(key: _seenKey) == 'true';
  }

  Future<void> markSeen() {
    return _storage.write(key: _seenKey, value: 'true');
  }
}
