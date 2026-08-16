import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/database/local_outbox_table.dart';

void main() {
  // The "reopen the database" test below deliberately opens a second
  // KirainDatabase pointed at the same file after closing the first one —
  // exactly the sequence drift's multi-instance guard warns about, since it
  // can't see the `await ...close()` ordering that makes it safe here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  OutboxDraft draft({
    required String id,
    String? categoryId = 'cat-1',
    String? goalId,
    int amount = 50000,
    DateTime? createdAt,
  }) {
    return OutboxDraft(
      id: id,
      userId: 'user-1',
      categoryId: goalId == null ? categoryId : null,
      goalId: goalId,
      amount: amount,
      note: 'test note',
      transactionDate: '2026-08-15',
      createdAt: createdAt ?? DateTime.utc(2026, 8, 15, 10, 30),
      expenseType: 'wajib',
    );
  }

  group('LocalOutboxRepository (OFFLINE-001 persistence primitives)', () {
    late KirainDatabase db;
    late LocalOutboxRepository repo;

    setUp(() {
      db = KirainDatabase(NativeDatabase.memory());
      repo = LocalOutboxRepository(db);
    });

    tearDown(() => db.close());

    test('outbox item can be inserted', () async {
      await repo.insertPending(draft(id: 'txn-1'));

      final items = await repo.pendingItems();
      expect(items, hasLength(1));
    });

    test('UUID is preserved exactly through insert and read-back', () async {
      const id = '3fae0c8e-19c1-4f3d-9c2b-1a2b3c4d5e6f';
      await repo.insertPending(draft(id: id));

      final item = await repo.findById(id);
      expect(item, isNotNull);
      expect(item!.id, id);
    });

    test('same UUID can be retrieved after reopening the local database', () async {
      final dir = await Directory.systemTemp.createTemp('kirain_outbox_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/test.sqlite');
      const id = 'reopen-test-id';

      final firstOpen = KirainDatabase(NativeDatabase(file));
      await LocalOutboxRepository(firstOpen).insertPending(draft(id: id));
      await firstOpen.close();

      final secondOpen = KirainDatabase(NativeDatabase(file));
      final item = await LocalOutboxRepository(secondOpen).findById(id);
      await secondOpen.close();

      expect(item, isNotNull);
      expect(item!.id, id);
    });

    test('pending items can be queried deterministically, oldest first', () async {
      await repo.insertPending(draft(id: 'b', createdAt: DateTime.utc(2026, 8, 15, 12)));
      await repo.insertPending(draft(id: 'a', createdAt: DateTime.utc(2026, 8, 15, 9)));
      await repo.insertPending(draft(id: 'c', createdAt: DateTime.utc(2026, 8, 15, 15)));

      final items = await repo.pendingItems();
      expect(items.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('status can be updated', () async {
      await repo.insertPending(draft(id: 'x'));
      await repo.markSyncing('x');

      final item = await repo.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.syncing);
    });

    test('retry count persists', () async {
      await repo.insertPending(draft(id: 'x'));
      await repo.markSyncing('x');
      await repo.markPendingForRetry('x', errorMessage: 'network timeout', retryCount: 3);

      final item = await repo.findById('x');
      expect(item!.retryCount, 3);
      expect(item.syncStatus, OutboxSyncStatus.pending);
      expect(item.errorMessage, 'network timeout');
    });

    test('failed state persists', () async {
      await repo.insertPending(draft(id: 'x'));
      await repo.markFailed('x', errorMessage: 'unique constraint violated');

      final item = await repo.findById('x');
      expect(item!.syncStatus, OutboxSyncStatus.failed);
      expect(item.errorMessage, 'unique constraint violated');
    });

    test('outbox item can be deleted after successful sync', () async {
      await repo.insertPending(draft(id: 'x'));
      await repo.deleteSynced('x');

      expect(await repo.findById('x'), isNull);
    });

    test('multiple queued transactions remain independent', () async {
      await repo.insertPending(draft(id: 'a'));
      await repo.insertPending(draft(id: 'b', goalId: 'goal-1', categoryId: null));

      await repo.markSyncing('a');
      await repo.deleteSynced('a');

      expect(await repo.findById('a'), isNull);
      final b = await repo.findById('b');
      expect(b, isNotNull);
      expect(b!.syncStatus, OutboxSyncStatus.pending);
      expect(b.goalId, 'goal-1');
    });

    test('no UUID regeneration occurs during local persistence', () async {
      const id = 'stable-id';
      await repo.insertPending(draft(id: id));

      // Simulate two failed send attempts going through the same
      // syncing -> retry cycle a future sync worker would drive.
      await repo.markSyncing(id);
      await repo.markPendingForRetry(id, errorMessage: 'timeout', retryCount: 1);
      await repo.markSyncing(id);
      await repo.markPendingForRetry(id, errorMessage: 'timeout again', retryCount: 2);

      final items = await repo.pendingItems();
      expect(items, hasLength(1));
      expect(items.single.id, id);
      expect(items.single.retryCount, 2);
    });

    group('exact amount preservation', () {
      for (final amount in [1, 12345, 50000, 1000000, 123456789012]) {
        test('$amount Rupiah round-trips exactly, not as an approximation', () async {
          await repo.insertPending(draft(id: 'amount-$amount', amount: amount));

          final item = await repo.findById('amount-$amount');
          expect(item!.amount, amount);
          expect(item.amount, isA<int>());
        });
      }
    });

    group('category/goal invariant', () {
      test('category-only draft is valid', () {
        expect(
          () => draft(id: 'x', categoryId: 'cat-1', goalId: null),
          returnsNormally,
        );
      });

      test('goal-only draft is valid', () {
        expect(
          () => draft(id: 'x', categoryId: null, goalId: 'goal-1'),
          returnsNormally,
        );
      });

      test('both null is rejected at construction, never reaches storage', () {
        expect(
          () => OutboxDraft(
            id: 'x',
            userId: 'user-1',
            categoryId: null,
            goalId: null,
            amount: 1000,
            transactionDate: '2026-08-15',
            createdAt: DateTime.utc(2026, 8, 15),
          ),
          throwsArgumentError,
        );
      });

      test('both populated is rejected at construction, never reaches storage', () {
        expect(
          () => OutboxDraft(
            id: 'x',
            userId: 'user-1',
            categoryId: 'cat-1',
            goalId: 'goal-1',
            amount: 1000,
            transactionDate: '2026-08-15',
            createdAt: DateTime.utc(2026, 8, 15),
          ),
          throwsArgumentError,
        );
      });

      // These two bypass OutboxDraft entirely and write a raw Companion
      // straight through the database, proving the CHECK constraint on
      // LocalOutboxItems is a real backstop — not just documentation — for
      // any future code path that doesn't go through OutboxDraft.
      test('CHECK constraint rejects both-null at the SQL level', () async {
        expect(
          () => db
              .into(db.localOutboxItems)
              .insert(
                LocalOutboxItemsCompanion.insert(
                  id: 'raw-both-null',
                  userId: 'user-1',
                  amount: 1000,
                  transactionDate: '2026-08-15',
                  createdAt: DateTime.utc(2026, 8, 15),
                  syncStatus: OutboxSyncStatus.pending,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      });

      test('CHECK constraint rejects both-populated at the SQL level', () async {
        expect(
          () => db
              .into(db.localOutboxItems)
              .insert(
                LocalOutboxItemsCompanion.insert(
                  id: 'raw-both-populated',
                  userId: 'user-1',
                  categoryId: const Value('cat-1'),
                  goalId: const Value('goal-1'),
                  amount: 1000,
                  transactionDate: '2026-08-15',
                  createdAt: DateTime.utc(2026, 8, 15),
                  syncStatus: OutboxSyncStatus.pending,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      });
    });

    group('claim/lease (OFFLINE-002)', () {
      test('PENDING can be claimed for sync', () async {
        await repo.insertPending(draft(id: 'x'));

        final claimed = await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 11));

        expect(claimed, isTrue);
        final item = await repo.findById('x');
        expect(item!.syncStatus, OutboxSyncStatus.syncing);
        expect(item.lockedAt?.toUtc(), DateTime.utc(2026, 8, 15, 11));
      });

      test('claim is conditional on the row still being PENDING', () async {
        await repo.insertPending(draft(id: 'x'));
        await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 11));

        // Now SYNCING — a claim attempt must not succeed against it.
        final secondClaim = await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 12));

        expect(secondClaim, isFalse);
      });

      test('an already-claimed row cannot be claimed twice', () async {
        await repo.insertPending(draft(id: 'x'));

        final first = await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 11));
        final second = await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 11, 0, 1));

        expect(first, isTrue);
        expect(second, isFalse);
        // Only the first claim's lockedAt stuck.
        final item = await repo.findById('x');
        expect(item!.lockedAt?.toUtc(), DateTime.utc(2026, 8, 15, 11));
      });

      test('a stale SYNCING item is recovered to PENDING', () async {
        await repo.insertPending(draft(id: 'x'));
        await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 10));

        final recovered = await repo.recoverStaleLeases(before: DateTime.utc(2026, 8, 15, 10, 5));

        expect(recovered, 1);
        final item = await repo.findById('x');
        expect(item!.syncStatus, OutboxSyncStatus.pending);
        expect(item.lockedAt, isNull);
      });

      test('a non-stale SYNCING item is left untouched', () async {
        await repo.insertPending(draft(id: 'x'));
        await repo.claimForSync('x', lockedAt: DateTime.utc(2026, 8, 15, 10, 59));

        final recovered = await repo.recoverStaleLeases(before: DateTime.utc(2026, 8, 15, 10, 5));

        expect(recovered, 0);
        final item = await repo.findById('x');
        expect(item!.syncStatus, OutboxSyncStatus.syncing);
        expect(item.lockedAt?.toUtc(), DateTime.utc(2026, 8, 15, 10, 59));
      });

      test('recovering stale leases does not touch unrelated PENDING items', () async {
        await repo.insertPending(draft(id: 'stale-sync'));
        await repo.claimForSync('stale-sync', lockedAt: DateTime.utc(2026, 8, 15, 10));
        await repo.insertPending(draft(id: 'still-pending'));

        await repo.recoverStaleLeases(before: DateTime.utc(2026, 8, 15, 10, 5));

        final stillPending = await repo.findById('still-pending');
        expect(stillPending!.syncStatus, OutboxSyncStatus.pending);
        expect(stillPending.lockedAt, isNull);
      });

      test('retryFailed moves a FAILED item back to PENDING', () async {
        await repo.insertPending(draft(id: 'x'));
        await repo.markFailed('x', errorMessage: 'boom');

        await repo.retryFailed('x');

        final item = await repo.findById('x');
        expect(item!.syncStatus, OutboxSyncStatus.pending);
      });
    });
  });
}
