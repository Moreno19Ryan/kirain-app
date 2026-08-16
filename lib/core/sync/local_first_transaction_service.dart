import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_outbox_repository.dart';
import '../utils/format.dart';

final localFirstTransactionServiceProvider = Provider<LocalFirstTransactionService>((ref) {
  return LocalFirstTransactionService(ref.watch(localOutboxRepositoryProvider));
});

/// OFFLINE-003's local-first write path for Catat: records a transaction
/// purely locally (no network wait) and returns as soon as that atomic local
/// write lands. `TransactionRepository.addTransaction` (the direct-to-
/// Supabase path) is untouched and still used by Savings Goal/Recurring —
/// this is additive, not a replacement.
///
/// [currentUserId] is injectable (defaults to reading the live Supabase
/// session) for the same reason `SyncWorker` does it: `SupabaseClient.auth.
/// currentUser` can't be faked in a test without a real session, so tests
/// need a seam here to exercise this without one.
class LocalFirstTransactionService {
  LocalFirstTransactionService(this._outbox, {String? Function()? currentUserId})
    : _currentUserId = currentUserId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final LocalOutboxRepository _outbox;
  final String? Function() _currentUserId;

  /// [id] must be generated exactly once by the caller (Catat's submit
  /// handler, via `newId()`) before this is called — never regenerated here,
  /// same ADR-001 rule `TransactionRepository.addTransaction` already
  /// follows. [amount] is exact whole Rupiah (see `LocalOutboxItems.amount`
  /// for why int, not num).
  Future<void> recordTransaction({
    required String id,
    required String categoryId,
    required int amount,
    String? note,
    String? expenseType,
    required DateTime transactionDate,
    DateTime? createdAt,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('LocalFirstTransactionService.recordTransaction requires a signed-in user.');
    }

    final draft = OutboxDraft(
      id: id,
      userId: userId,
      categoryId: categoryId,
      amount: amount,
      note: note,
      transactionDate: isoDate(transactionDate),
      createdAt: createdAt ?? DateTime.now(),
      expenseType: expenseType,
    );
    await _outbox.insertLocalFirstTransaction(draft);
  }
}
