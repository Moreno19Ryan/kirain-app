import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/format.dart';

final gajianReminderRepositoryProvider = Provider<GajianReminderRepository>((ref) {
  return GajianReminderRepository(const FlutterSecureStorage());
});

/// Tracks whether the gajian reminder has already been shown for a given
/// budget cycle — a device-local UI flag (not financial data), keyed by
/// the cycle's start date so it fires at most once per cycle regardless of
/// how many times the app is opened during it.
class GajianReminderRepository {
  GajianReminderRepository(this._storage);

  final FlutterSecureStorage _storage;

  static const _lastShownKey = 'gajian_reminder_last_cycle_start';

  Future<bool> shouldShow(DateTime cycleStart) async {
    final last = await _storage.read(key: _lastShownKey);
    return last != isoDate(cycleStart);
  }

  Future<void> markShown(DateTime cycleStart) {
    return _storage.write(key: _lastShownKey, value: isoDate(cycleStart));
  }
}
