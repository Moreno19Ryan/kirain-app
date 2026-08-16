import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/kirain_database.dart';
import '../database/local_outbox_repository.dart';
import 'sync_backoff.dart';
import 'sync_error_classifier.dart';
import 'transaction_sync_service.dart';

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final worker = SyncWorker(ref.watch(localOutboxRepositoryProvider), ref.watch(transactionSyncServiceProvider));
  ref.onDispose(worker.dispose);
  return worker;
});

/// Drains KIRAIN's local outbox (OFFLINE-001) into Supabase. Foreground-only
/// per ADR-002 — no background isolate, no WorkManager. Every method here is
/// meant to be called from a live app process reacting to one of the five
/// triggers: startup, resume, connectivity change, manual retry, or a fresh
/// local outbox insertion (see sync_triggers.dart for where those actually
/// get wired up).
class SyncWorker {
  SyncWorker(
    this._outbox,
    this._syncService, {
    this.batchSize = 10,
    this.maxAttemptsPerItem = 5,
    this.staleLeaseThreshold = const Duration(minutes: 5),
    SyncBackoff? backoff,
    Future<void> Function(Duration duration)? delay,
    math.Random? random,
    DateTime Function()? now,
    String? Function()? currentUserId,
  }) : _backoff = backoff ?? const SyncBackoff(),
       _delay = delay ?? Future.delayed,
       _random = random ?? math.Random(),
       _now = now ?? DateTime.now,
       _currentUserId = currentUserId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final LocalOutboxRepository _outbox;
  final TransactionSyncService _syncService;

  /// How many PENDING items one [processQueue] pass will attempt.
  /// Deliberately small and bounded — a large queue shouldn't turn one sync
  /// pass into an unbounded scan; whatever's left over gets picked up by
  /// the next trigger.
  final int batchSize;

  /// Bound on inline retry attempts for a single item within one claim —
  /// this is the "worker session" ADR-002 refers to, not a lifetime cap.
  /// Exhausting it returns the item to PENDING (never deletes/discards it)
  /// so the *next* trigger gets a fresh attempt budget.
  final int maxAttemptsPerItem;

  /// How long a SYNCING lease is trusted before [recoverStaleLeases] treats
  /// it as abandoned (the app died mid-sync) and reclaims the row to
  /// PENDING. A configurable recovery parameter, not a hardcoded assumption
  /// — 5 minutes is just the default a caller can override.
  final Duration staleLeaseThreshold;

  final SyncBackoff _backoff;
  final Future<void> Function(Duration duration) _delay;
  final math.Random _random;
  final DateTime Function() _now;
  final String? Function() _currentUserId;

  Future<void>? _inFlight;

  /// Reclaims SYNCING rows whose lease is older than [staleLeaseThreshold]
  /// back to PENDING. Not folded into [processQueue] itself — per ADR-002's
  /// trigger table, only the startup and resume triggers recover stale
  /// leases; connectivity/manual-retry/local-insertion just process the
  /// queue as-is. A single bulk conditional UPDATE, so it's safe to call
  /// concurrently with an in-flight [processQueue] without corrupting
  /// anything (it can never touch a lease that's still fresh).
  Future<int> recoverStaleLeases() {
    final cutoff = _now().subtract(staleLeaseThreshold);
    return _outbox.recoverStaleLeases(before: cutoff);
  }

  /// The startup/resume trigger: recover stale leases, then process
  /// whatever's eligible. Routed through the same single-flight guard as
  /// [processQueue] so it can't run concurrently with another sync pass.
  Future<void> runStartupSync() => _guarded(() async {
    await recoverStaleLeases();
    await _processBatch();
  });

  /// The connectivity/manual-retry/local-insertion trigger. Coalesced: if a
  /// pass is already running, this returns *that* pass's future instead of
  /// starting a second one — the in-process concurrency guard ADR-002
  /// requires. This is necessary but deliberately not sufficient on its own:
  /// the actual claim ([LocalOutboxRepository.claimForSync]) is a
  /// conditional SQL UPDATE, so even a claim attempt that somehow raced past
  /// this guard (or came from a different process) can't double-claim a row.
  Future<void> processQueue() => _guarded(_processBatch);

  /// FAILED -> PENDING for one item, then a normal processQueue() pass —
  /// the "manual retry" trigger. User-initiated, so no lease/claim
  /// reasoning needed for the transition itself (see
  /// [LocalOutboxRepository.retryFailed]) — but ownership still is: refuses
  /// to touch an item that isn't the current session's own, same as
  /// [_processBatch]. A no-op (not an error) if the item is missing or
  /// belongs to someone else, since neither is something the caller should
  /// be able to distinguish from "already handled".
  Future<void> retryFailedItem(String id) async {
    final item = await _outbox.findById(id);
    if (item == null || item.userId != _currentUserId()) return;

    await _outbox.retryFailed(id);
    await processQueue();
  }

  Future<void> dispose() {
    // Let an in-flight pass finish rather than abandoning it mid-claim.
    return _inFlight ?? Future.value();
  }

  // `??=` matters here, not just as a shorthand: it makes the future stored
  // in `_inFlight` and the future returned to *every* caller — the one that
  // starts the run and any that coalesce onto it — the exact same object.
  // Assigning the started future separately and returning a derived one
  // (e.g. a second `.whenComplete()` wrapper) would give concurrent callers
  // non-identical futures that merely complete around the same time, which
  // isn't the same guarantee.
  Future<void> _guarded(Future<void> Function() body) {
    return _inFlight ??= body().whenComplete(() => _inFlight = null);
  }

  Future<void> _processBatch() async {
    final userId = _currentUserId();
    // Nothing to sync on behalf of nobody: RLS would just reject every
    // request as an anonymous/expired-session write. Skip the batch
    // entirely rather than burning retry budget on requests that can't
    // possibly succeed yet.
    if (userId == null) return;

    // Scoped to the *current* session's own rows — never another user's.
    // On a shared device where user A queued something offline and user B
    // is now signed in, A's still-pending item simply isn't in this batch;
    // it stays untouched until A is signed in again. See
    // [LocalOutboxRepository.eligibleBatch] for why this is a query filter,
    // not a post-fetch check.
    final items = await _outbox.eligibleBatch(limit: batchSize, userId: userId);
    for (final item in items) {
      await _processItem(item);
    }
  }

  Future<void> _processItem(LocalOutboxItem item) async {
    final claimed = await _outbox.claimForSync(item.id, lockedAt: _now());
    // Already claimed by a concurrent pass, or no longer PENDING (deleted,
    // moved to FAILED) since the batch was read. Either way, not this
    // call's item to process.
    if (!claimed) return;

    for (var attempt = 0; attempt < maxAttemptsPerItem; attempt++) {
      try {
        await _syncService.upsertTransaction(item);
        await _outbox.deleteSynced(item.id);
        return;
      } catch (error) {
        final outcome = classifySyncError(error);

        switch (outcome) {
          case SyncOutcome.alreadySynced:
            await _outbox.deleteSynced(item.id);
            return;

          case SyncOutcome.permanent:
            await _outbox.markFailed(item.id, errorMessage: error.toString());
            return;

          case SyncOutcome.authRequired:
            // A sleep-and-retry loop can't fix an invalid session — only
            // re-authentication can. Spending the backoff budget here
            // would just delay the next externally-triggered attempt for
            // no benefit, so this takes exactly one attempt this session.
            await _outbox.markPendingForRetry(
              item.id,
              errorMessage: error.toString(),
              retryCount: item.retryCount + attempt + 1,
            );
            return;

          case SyncOutcome.retryable:
            final isLastAttempt = attempt == maxAttemptsPerItem - 1;
            if (isLastAttempt) {
              await _outbox.markPendingForRetry(
                item.id,
                errorMessage: error.toString(),
                retryCount: item.retryCount + attempt + 1,
              );
              return;
            }
            await _delay(_backoff.delayForAttempt(attempt, _random));
        }
      }
    }
  }
}
