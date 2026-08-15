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
    num amount = 50000,
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
  });
}
