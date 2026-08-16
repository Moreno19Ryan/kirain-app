import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/database/local_outbox_table.dart';
import 'package:kirain/core/sync/sync_worker.dart';
import 'package:kirain/core/sync/transaction_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic stand-in for [math.Random] — see sync_backoff_test.dart for
/// why a fixed `nextDouble()` makes backoff delays exactly predictable.
class _FixedRandom implements math.Random {
  const _FixedRandom(this._value);
  final double _value;
  @override
  double nextDouble() => _value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

/// Mocks Supabase at the service boundary, per ADR-002 — SyncWorker never
/// talks to a real (or fake) SupabaseClient in these tests, only this.
/// [behavior] is called once per attempt and returns the error to throw, or
/// null for success.
class _FakeSyncService implements TransactionSyncService {
  _FakeSyncService(this._behavior);

  final Object? Function(LocalOutboxItem item, int attemptNumber) _behavior;

  final List<String> receivedIds = [];
  final Map<String, int> _attempts = {};

  int get totalCalls => receivedIds.length;
  int callsFor(String id) => _attempts[id] ?? 0;

  @override
  Future<void> upsertTransaction(LocalOutboxItem item) async {
    final attemptNumber = (_attempts[item.id] ?? 0) + 1;
    _attempts[item.id] = attemptNumber;
    receivedIds.add(item.id);

    final error = _behavior(item, attemptNumber);
    if (error != null) throw error;
  }
}

void main() {
  late KirainDatabase db;
  late LocalOutboxRepository outbox;

  setUp(() {
    db = KirainDatabase(NativeDatabase.memory());
    outbox = LocalOutboxRepository(db);
  });

  tearDown(() => db.close());

  OutboxDraft draft({required String id, DateTime? createdAt, String userId = 'user-1'}) {
    return OutboxDraft(
      id: id,
      userId: userId,
      categoryId: 'cat-1',
      amount: 50000,
      transactionDate: '2026-08-15',
      createdAt: createdAt ?? DateTime.utc(2026, 8, 15, 10),
      expenseType: 'wajib',
    );
  }

  SyncWorker buildWorker(
    TransactionSyncService sync, {
    int maxAttemptsPerItem = 5,
    Duration staleLeaseThreshold = const Duration(minutes: 5),
    DateTime Function()? now,
    String? Function()? currentUserId,
    Future<void> Function(Duration)? delay,
    math.Random? random,
  }) {
    return SyncWorker(
      outbox,
      sync,
      maxAttemptsPerItem: maxAttemptsPerItem,
      staleLeaseThreshold: staleLeaseThreshold,
      delay: delay ?? (_) async {},
      random: random ?? const _FixedRandom(0),
      now: now ?? () => DateTime.utc(2026, 8, 15, 12),
      currentUserId: currentUserId ?? () => 'user-1',
    );
  }

  group('SyncWorker', () {
    test('a successful sync deletes the outbox item', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect(await outbox.findById('x'), isNull);
      expect(sync.totalCalls, 1);
    });

    test('a retryable error exhausts the attempt budget and returns to PENDING', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => const SocketException('down'));
      final worker = buildWorker(sync, maxAttemptsPerItem: 3);

      await worker.processQueue();

      final item = await outbox.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.pending);
      expect(sync.callsFor('x'), 3);
    });

    test('a permanent error moves straight to FAILED, no retries spent', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => PostgrestException(message: 'fk violation', code: '23503'));
      final worker = buildWorker(sync);

      await worker.processQueue();

      final item = await outbox.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.failed);
      expect(sync.callsFor('x'), 1);
    });

    test('retry_count accumulates across separate worker sessions', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => const SocketException('down'));
      final worker = buildWorker(sync, maxAttemptsPerItem: 2);

      await worker.processQueue();
      expect((await outbox.findById('x'))!.retryCount, 2);

      await worker.processQueue();
      expect((await outbox.findById('x'))!.retryCount, 4);
    });

    test('uses exponential backoff between retryable attempts', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => const SocketException('down'));
      final delays = <Duration>[];
      final worker = buildWorker(
        sync,
        maxAttemptsPerItem: 4,
        delay: (d) async => delays.add(d),
        random: const _FixedRandom(1.0), // top of range: delay == ceiling exactly
      );

      await worker.processQueue();

      // 4 attempts => 3 delays between them, none after the last attempt.
      expect(delays, [const Duration(seconds: 2), const Duration(seconds: 4), const Duration(seconds: 8)]);
    });

    test('jittered delays stay within the backoff ceiling for each attempt', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => const SocketException('down'));
      final delays = <Duration>[];
      final worker = buildWorker(
        sync,
        maxAttemptsPerItem: 5,
        delay: (d) async => delays.add(d),
        random: math.Random(99), // seeded, not fixed — exercises real jitter
      );

      await worker.processQueue();

      const ceilingsMs = [2000, 4000, 8000, 16000];
      expect(delays, hasLength(4));
      for (var i = 0; i < delays.length; i++) {
        expect(delays[i].inMilliseconds, inInclusiveRange(0, ceilingsMs[i]));
      }
    });

    test('retries reuse the exact same UUID, never a freshly generated one', () async {
      await outbox.insertPending(draft(id: 'stable-uuid'));
      final sync = _FakeSyncService((item, n) => n < 3 ? const SocketException('down') : null);
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect(sync.receivedIds, ['stable-uuid', 'stable-uuid', 'stable-uuid']);
    });

    test(
      'a duplicate-key response (server already has it) is treated as success, not failure',
      () async {
        // Simulates crash-recovery scenario D/E: an earlier attempt's
        // response never reached the client, but Supabase already
        // committed it — a retry with the same UUID now hits a unique
        // violation.
        await outbox.insertPending(draft(id: 'x'));
        final sync = _FakeSyncService(
          (item, n) => PostgrestException(
            message: 'duplicate key value violates unique constraint "transactions_pkey"',
            code: '23505',
            details: 'Key (id)=(${item.id}) already exists.',
          ),
        );
        final worker = buildWorker(sync);

        await worker.processQueue();

        expect(await outbox.findById('x'), isNull); // deleted, not FAILED
        expect(sync.callsFor('x'), 1); // no wasted retries either
      },
    );

    test('two concurrent processQueue() calls are coalesced into a single run', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync);

      final first = worker.processQueue();
      final second = worker.processQueue();

      expect(identical(first, second), isTrue);
      await first;
      expect(sync.totalCalls, 1);
    });

    test('one permanently-failed item does not block others in the same batch', () async {
      await outbox.insertPending(draft(id: 'bad', createdAt: DateTime.utc(2026, 8, 15, 9)));
      await outbox.insertPending(draft(id: 'good', createdAt: DateTime.utc(2026, 8, 15, 10)));
      final sync = _FakeSyncService((item, n) {
        if (item.id == 'bad') return PostgrestException(message: 'fk violation', code: '23503');
        return null;
      });
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect((await outbox.findById('bad'))!.syncStatus, OutboxSyncStatus.failed);
      expect(await outbox.findById('good'), isNull); // synced & deleted independently
    });

    test('manual retry moves a FAILED item back to PENDING and re-attempts it', () async {
      await outbox.insertPending(draft(id: 'x'));
      var shouldFail = true;
      final sync = _FakeSyncService(
        (item, n) => shouldFail ? PostgrestException(message: 'fk violation', code: '23503') : null,
      );
      final worker = buildWorker(sync);

      await worker.processQueue();
      expect((await outbox.findById('x'))!.syncStatus, OutboxSyncStatus.failed);

      shouldFail = false;
      await worker.retryFailedItem('x');

      expect(await outbox.findById('x'), isNull); // synced this time
    });

    test('a 409 confirmed as an id conflict deletes rather than fails', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService(
        (item, n) => PostgrestException(
          message: 'duplicate key value violates unique constraint "transactions_pkey"',
          code: '409',
          details: 'Key (id)=(${item.id}) already exists.',
        ),
      );
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect(await outbox.findById('x'), isNull);
    });

    test('a unique violation on a different column is FAILED, not silently treated as synced', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService(
        (item, n) => PostgrestException(
          message: 'duplicate key value violates unique constraint "transactions_some_other_key"',
          code: '23505',
          details: 'Key (idempotency_token)=(abc) already exists.',
        ),
      );
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect((await outbox.findById('x'))!.syncStatus, OutboxSyncStatus.failed);
    });

    test('a 401 defers to PENDING after exactly one attempt, spending no backoff budget', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => const AuthApiException('JWT expired', statusCode: '401'));
      final delays = <Duration>[];
      final worker = buildWorker(sync, maxAttemptsPerItem: 5, delay: (d) async => delays.add(d));

      await worker.processQueue();

      final item = await outbox.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.pending);
      expect(sync.callsFor('x'), 1);
      expect(delays, isEmpty);
    });

    test('a malformed-payload error fails immediately, no infinite retry', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService(
        (item, n) => PostgrestException(message: 'invalid input syntax for type uuid', code: '22P02'),
      );
      final worker = buildWorker(sync, maxAttemptsPerItem: 5);

      await worker.processQueue();

      final item = await outbox.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.failed);
      expect(sync.callsFor('x'), 1);
    });

    test('runStartupSync recovers a stale lease before processing the queue', () async {
      await outbox.insertPending(draft(id: 'stuck'));
      await outbox.claimForSync('stuck', lockedAt: DateTime.utc(2026, 8, 15, 11)); // 1h before "now"
      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync, now: () => DateTime.utc(2026, 8, 15, 12));

      await worker.runStartupSync();

      expect(await outbox.findById('stuck'), isNull); // recovered, then synced & deleted
      expect(sync.totalCalls, 1);
    });

    test('processQueue does nothing when there is no authenticated user', () async {
      await outbox.insertPending(draft(id: 'x'));
      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync, currentUserId: () => null);

      await worker.processQueue();

      expect((await outbox.findById('x'))!.syncStatus, OutboxSyncStatus.pending);
      expect(sync.totalCalls, 0);
    });

    test('processes an eligible batch in deterministic (oldest-first) order', () async {
      await outbox.insertPending(draft(id: 'c', createdAt: DateTime.utc(2026, 8, 15, 12)));
      await outbox.insertPending(draft(id: 'a', createdAt: DateTime.utc(2026, 8, 15, 9)));
      await outbox.insertPending(draft(id: 'b', createdAt: DateTime.utc(2026, 8, 15, 10)));
      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect(sync.receivedIds, ['a', 'b', 'c']);
    });

    test('a row already claimed elsewhere is skipped, not double-processed', () async {
      await outbox.insertPending(draft(id: 'x'));
      // Simulate another worker (or another pass) already owning this row
      // with a fresh, non-stale lease.
      await outbox.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 12));

      final sync = _FakeSyncService((item, n) => null);
      final worker = buildWorker(sync);

      await worker.processQueue();

      expect(sync.totalCalls, 0);
      expect((await outbox.findById('x'))!.syncStatus, OutboxSyncStatus.syncing);
    });

    group('user ownership (login/logout identity boundary)', () {
      test("processQueue never sends another user's item, even if it's the only one pending", () async {
        await outbox.insertPending(draft(id: 'a-item', userId: 'user-A'));
        final sync = _FakeSyncService((item, n) => null);
        // Session B is signed in — A's item must not enter B's batch.
        final worker = buildWorker(sync, currentUserId: () => 'user-B');

        await worker.processQueue();

        expect(sync.totalCalls, 0);
        expect((await outbox.findById('a-item'))!.syncStatus, OutboxSyncStatus.pending);
      });

      test('a batch only ever contains the current session\'s own items', () async {
        await outbox.insertPending(draft(id: 'a-item', userId: 'user-A', createdAt: DateTime.utc(2026, 8, 15, 9)));
        await outbox.insertPending(draft(id: 'b-item', userId: 'user-B', createdAt: DateTime.utc(2026, 8, 15, 10)));
        final sync = _FakeSyncService((item, n) => null);
        final worker = buildWorker(sync, currentUserId: () => 'user-B');

        await worker.processQueue();

        expect(sync.receivedIds, ['b-item']);
        expect((await outbox.findById('a-item'))!.syncStatus, OutboxSyncStatus.pending); // untouched
        expect(await outbox.findById('b-item'), isNull); // synced & deleted
      });

      test('logging back in as the original user lets their own item sync normally', () async {
        await outbox.insertPending(draft(id: 'a-item', userId: 'user-A'));
        final sync = _FakeSyncService((item, n) => null);

        // User B's session first: A's item is skipped entirely.
        await buildWorker(sync, currentUserId: () => 'user-B').processQueue();
        expect(sync.totalCalls, 0);

        // A signs back in: now it's eligible and gets synced.
        await buildWorker(sync, currentUserId: () => 'user-A').processQueue();
        expect(sync.receivedIds, ['a-item']);
        expect(await outbox.findById('a-item'), isNull);
      });

      test("manual retry refuses to act on another user's FAILED item", () async {
        await outbox.insertPending(draft(id: 'a-item', userId: 'user-A'));
        await outbox.markFailed('a-item', errorMessage: 'boom');
        final sync = _FakeSyncService((item, n) => null);
        final worker = buildWorker(sync, currentUserId: () => 'user-B');

        await worker.retryFailedItem('a-item');

        expect(sync.totalCalls, 0);
        expect((await outbox.findById('a-item'))!.syncStatus, OutboxSyncStatus.failed); // untouched
      });

      test('manual retry on a nonexistent item is a harmless no-op', () async {
        final sync = _FakeSyncService((item, n) => null);
        final worker = buildWorker(sync, currentUserId: () => 'user-B');

        await worker.retryFailedItem('does-not-exist');

        expect(sync.totalCalls, 0);
      });
    });
  });
}
