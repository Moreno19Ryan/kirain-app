import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kirain_database.dart';
import 'local_outbox_table.dart';

final localOutboxRepositoryProvider = Provider<LocalOutboxRepository>((ref) {
  return LocalOutboxRepository(ref.watch(kirainDatabaseProvider));
});

/// A transaction (or savings contribution) not yet confirmed as synced to
/// Supabase.
///
/// [id] is the transaction's own client-generated UUID v4 (see
/// core/utils/ids.dart) — per ADR-001, it must be generated exactly once by
/// the caller at creation time and carried through unchanged on every retry,
/// never regenerated here or by whatever eventually drives those retries.
/// [expenseType] is already the raw string TransactionRepository sends
/// Supabase (`ExpenseType.name`, e.g. 'wajib') rather than the enum itself —
/// this keeps core/database free of a dependency on the categories feature,
/// since the outbox only needs to carry the payload through, not interpret
/// it.
class OutboxDraft {
  OutboxDraft({
    required this.id,
    required this.userId,
    this.categoryId,
    this.goalId,
    required this.amount,
    this.note,
    required this.transactionDate,
    required this.createdAt,
    this.expenseType,
  }) {
    // A real runtime check, not `assert` — asserts compile out of release
    // builds, and a malformed outbox row (both/neither of category+goal
    // set) is exactly the kind of thing that must never silently reach
    // storage in a financial app just because it happened not to trip in a
    // debug build. The [LocalOutboxItems] CHECK constraint is the second
    // line of defense for anything that reaches the DAO some other way.
    if ((categoryId == null) == (goalId == null)) {
      throw ArgumentError(
        'OutboxDraft requires exactly one of categoryId/goalId to be set '
        '(got categoryId: $categoryId, goalId: $goalId)',
      );
    }
  }

  final String id;
  final String userId;

  /// Exactly one of [categoryId] / [goalId] is set, matching
  /// TransactionRepository's addTransaction (category) vs
  /// addSavingsContribution (goal) split. Enforced in the constructor body
  /// above and backstopped by a CHECK constraint on [LocalOutboxItems].
  final String? categoryId;
  final String? goalId;

  /// Exact whole Rupiah — see [LocalOutboxItems.amount] for why this is an
  /// int rather than num/double. Whoever eventually wires this into
  /// TransactionRepository (which still takes `num amount`, matching
  /// Supabase's `numeric(14,2)`) owns converting at that boundary; nothing
  /// upstream of this class should be introducing fractional Rupiah.
  final int amount;
  final String? note;

  /// ISO date string ('yyyy-MM-dd') — see core/utils/format.dart's isoDate().
  final String transactionDate;
  final DateTime createdAt;
  final String? expenseType;
}

/// DAO for [LocalOutboxItems]. Persistence primitives from OFFLINE-001, plus
/// OFFLINE-002's claim/lease methods that SyncWorker builds its state
/// machine on top of. Nothing in here decides *when* to sync or how to
/// classify a failure — that's SyncWorker's job; this just gives it a
/// durable, race-safe place to read from and write to.
class LocalOutboxRepository {
  LocalOutboxRepository(this._db);

  final KirainDatabase _db;

  Future<void> insertPending(OutboxDraft draft) {
    return _db
        .into(_db.localOutboxItems)
        .insert(
          LocalOutboxItemsCompanion.insert(
            id: draft.id,
            userId: draft.userId,
            categoryId: Value(draft.categoryId),
            goalId: Value(draft.goalId),
            amount: draft.amount,
            note: Value(draft.note),
            transactionDate: draft.transactionDate,
            createdAt: draft.createdAt,
            expenseType: Value(draft.expenseType),
            syncStatus: OutboxSyncStatus.pending,
          ),
        );
  }

  /// Deterministic, oldest-first — so a future sync worker sends queued
  /// transactions in the order the user actually created them.
  Future<List<LocalOutboxItem>> pendingItems() {
    return (_db.select(_db.localOutboxItems)
          ..where((t) => t.syncStatus.equalsValue(OutboxSyncStatus.pending))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Same as [pendingItems] but bounded — SyncWorker processes one small,
  /// deterministically-ordered batch per pass rather than an unbounded scan,
  /// so a queue with many items can't stall a single sync attempt.
  Future<List<LocalOutboxItem>> eligibleBatch({required int limit}) {
    return (_db.select(_db.localOutboxItems)
          ..where((t) => t.syncStatus.equalsValue(OutboxSyncStatus.pending))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<LocalOutboxItem?> findById(String id) {
    return (_db.select(_db.localOutboxItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Not safe for claiming — unconditional, so two concurrent callers could
  /// both "succeed". Kept for OFFLINE-001 tests that only need to *place* an
  /// item in SYNCING without exercising the claim race itself. SyncWorker
  /// always uses [claimForSync] instead, which is conditional at the SQL
  /// level.
  Future<void> markSyncing(String id) => _updateStatus(id, OutboxSyncStatus.syncing);

  /// The only safe way to move PENDING -> SYNCING. Conditional on the
  /// current row still being PENDING — `WHERE id = ? AND sync_status =
  /// 'pending'` — so this is a single atomic UPDATE, not a
  /// SELECT-then-UPDATE race. Returns whether *this* call actually won the
  /// claim: `true` means the row is now SYNCING and this caller owns it;
  /// `false` means it was already claimed (or deleted, or otherwise no
  /// longer PENDING) and nothing was changed.
  Future<bool> claimForSync(String id, {required DateTime lockedAt}) async {
    final rowsAffected =
        await (_db.update(_db.localOutboxItems)
              ..where((t) => t.id.equals(id) & t.syncStatus.equalsValue(OutboxSyncStatus.pending)))
            .write(
              LocalOutboxItemsCompanion(
                syncStatus: const Value(OutboxSyncStatus.syncing),
                lockedAt: Value(lockedAt),
              ),
            );
    return rowsAffected > 0;
  }

  /// Recovers SYNCING rows whose lease is older than [before] back to
  /// PENDING — the app died (or the isolate was killed) mid-sync, so the
  /// claim was never released. A bulk conditional UPDATE, same reasoning as
  /// [claimForSync]: it only touches rows that are still actually stale at
  /// the moment this runs, never a non-stale in-flight claim. Returns how
  /// many rows were recovered.
  Future<int> recoverStaleLeases({required DateTime before}) {
    return (_db.update(_db.localOutboxItems)..where(
          (t) => t.syncStatus.equalsValue(OutboxSyncStatus.syncing) & t.lockedAt.isSmallerThanValue(before),
        ))
        .write(const LocalOutboxItemsCompanion(syncStatus: Value(OutboxSyncStatus.pending), lockedAt: Value(null)));
  }

  /// A retryable send failure — back to PENDING so a later pass picks it up
  /// again, with the failure recorded for diagnostics/backoff. Clears the
  /// lease: this row is no longer SYNCING, so it shouldn't still look
  /// claimed.
  Future<void> markPendingForRetry(String id, {required String errorMessage, required int retryCount}) {
    return (_db.update(_db.localOutboxItems)..where((t) => t.id.equals(id))).write(
      LocalOutboxItemsCompanion(
        syncStatus: const Value(OutboxSyncStatus.pending),
        retryCount: Value(retryCount),
        lastAttemptAt: Value(DateTime.now()),
        errorMessage: Value(errorMessage),
        lockedAt: const Value(null),
      ),
    );
  }

  /// A non-retryable send failure — parked in FAILED rather than looping
  /// forever, until [retryFailed] moves it back to PENDING.
  Future<void> markFailed(String id, {required String errorMessage}) {
    return (_db.update(_db.localOutboxItems)..where((t) => t.id.equals(id))).write(
      LocalOutboxItemsCompanion(
        syncStatus: const Value(OutboxSyncStatus.failed),
        lastAttemptAt: Value(DateTime.now()),
        errorMessage: Value(errorMessage),
        lockedAt: const Value(null),
      ),
    );
  }

  /// User-initiated "coba lagi" on a FAILED item. Unconditional (not a
  /// claim race — there's no concurrent worker fighting over a FAILED row,
  /// only a human deciding to give it another shot), so this is a plain
  /// UPDATE rather than [claimForSync]'s conditional one.
  Future<void> retryFailed(String id) {
    return (_db.update(_db.localOutboxItems)..where((t) => t.id.equals(id))).write(
      const LocalOutboxItemsCompanion(syncStatus: Value(OutboxSyncStatus.pending)),
    );
  }

  Future<void> _updateStatus(String id, OutboxSyncStatus status) {
    return (_db.update(_db.localOutboxItems)..where((t) => t.id.equals(id))).write(
      LocalOutboxItemsCompanion(syncStatus: Value(status)),
    );
  }

  /// Called once an outbox item's insert has been confirmed on Supabase (or
  /// found to already exist there under the same UUID) — its job is done,
  /// nothing left to retry.
  Future<void> deleteSynced(String id) {
    return (_db.delete(_db.localOutboxItems)..where((t) => t.id.equals(id))).go();
  }
}
