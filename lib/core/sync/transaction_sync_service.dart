import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/kirain_database.dart';

final transactionSyncServiceProvider = Provider<TransactionSyncService>((ref) {
  return SupabaseTransactionSyncService(Supabase.instance.client);
});

/// The one place SyncWorker talks to Supabase — kept as a narrow interface
/// so tests can mock it directly rather than standing up a real (or fake)
/// Supabase client. "Mock at the service boundary", per ADR-002.
abstract class TransactionSyncService {
  /// Sends [item] to `public.transactions`. Must throw on any failure (the
  /// caller classifies the thrown error via [classifySyncError] from
  /// sync_error_classifier.dart) and must be safe to call again with the
  /// same [item] — that's what makes SyncWorker's retry loop and outbox
  /// crash-recovery correct.
  Future<void> upsertTransaction(LocalOutboxItem item);
}

class SupabaseTransactionSyncService implements TransactionSyncService {
  const SupabaseTransactionSyncService(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertTransaction(LocalOutboxItem item) async {
    // `onConflict: 'id'` + `ignoreDuplicates: true` is what makes retrying
    // the exact same UUID idempotent at the database level (Prefer:
    // resolution=ignore-duplicates) — a retry that lands after Supabase
    // already accepted an earlier attempt (crash-recovery scenarios D/E:
    // response lost, or app died before the local delete) becomes a no-op
    // success instead of a duplicate row or an error.
    await _client
        .from('transactions')
        .upsert(_toPayload(item), onConflict: 'id', ignoreDuplicates: true);
  }

  /// The actual KIRAIN transaction schema — id, user_id, category_id,
  /// amount, note, transaction_date, created_at, expense_type, goal_id —
  /// mirroring what TransactionRepository's own direct inserts already
  /// send (see features/transactions/data/transaction_repository.dart).
  /// `created_at` is sent explicitly (not left to the column's `default
  /// now()`) because it needs to reflect when the user actually created the
  /// transaction locally, which can be well before it finally syncs.
  Map<String, dynamic> _toPayload(LocalOutboxItem item) {
    return {
      'id': item.id,
      'user_id': item.userId,
      'category_id': item.categoryId,
      'goal_id': item.goalId,
      'amount': item.amount,
      'note': item.note,
      'transaction_date': item.transactionDate,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'expense_type': item.expenseType,
    };
  }
}
