import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/database/local_outbox_table.dart';
import 'package:kirain/core/sync/local_first_transaction_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('LocalFirstTransactionService (OFFLINE-003)', () {
    late KirainDatabase db;
    late LocalOutboxRepository outbox;

    setUp(() {
      db = KirainDatabase(NativeDatabase.memory());
      outbox = LocalOutboxRepository(db);
    });

    tearDown(() => db.close());

    test('records a transaction locally without any network dependency', () async {
      // No Supabase client is constructed or reached anywhere in this
      // service or test — the write lands purely through the injected
      // LocalOutboxRepository, proving the local-first path works with
      // zero network involvement (i.e. offline).
      final service = LocalFirstTransactionService(outbox, currentUserId: () => 'user-1');

      await service.recordTransaction(
        id: 'txn-1',
        categoryId: 'cat-1',
        amount: 20000,
        note: 'kopi',
        expenseType: 'keinginan',
        transactionDate: DateTime.utc(2026, 8, 15),
      );

      final outboxItem = await outbox.findById('txn-1');
      expect(outboxItem, isNotNull);
      expect(outboxItem!.syncStatus, OutboxSyncStatus.pending);
      expect(outboxItem.amount, 20000);
      expect(outboxItem.expenseType, 'keinginan');

      final localRows = await outbox.localTransactionsInRange(userId: 'user-1');
      expect(localRows, hasLength(1));
      expect(localRows.single.id, 'txn-1');
      expect(localRows.single.note, 'kopi');
    });

    test('writes the LocalTransactions and LocalOutboxItems rows atomically, sharing the caller-supplied id', () async {
      final service = LocalFirstTransactionService(outbox, currentUserId: () => 'user-1');

      await service.recordTransaction(
        id: 'shared-id',
        categoryId: 'cat-1',
        amount: 15000,
        transactionDate: DateTime.utc(2026, 8, 15),
      );

      final outboxItem = await outbox.findById('shared-id');
      final localRows = await outbox.localTransactionsInRange(userId: 'user-1');

      expect(outboxItem, isNotNull);
      expect(localRows.map((r) => r.id), ['shared-id']);
    });

    test('requires a signed-in user — throws rather than recording ownerless data', () async {
      final service = LocalFirstTransactionService(outbox, currentUserId: () => null);

      await expectLater(
        () => service.recordTransaction(
          id: 'txn-2',
          categoryId: 'cat-1',
          amount: 10000,
          transactionDate: DateTime.utc(2026, 8, 15),
        ),
        throwsStateError,
      );

      expect(await outbox.findById('txn-2'), isNull);
    });

    test('defaults createdAt to now when not supplied', () async {
      final before = DateTime.now();
      final service = LocalFirstTransactionService(outbox, currentUserId: () => 'user-1');

      await service.recordTransaction(
        id: 'txn-3',
        categoryId: 'cat-1',
        amount: 10000,
        transactionDate: DateTime.utc(2026, 8, 15),
      );
      final after = DateTime.now();

      final localRows = await outbox.localTransactionsInRange(userId: 'user-1');
      final createdAt = localRows.single.createdAt;
      expect(createdAt.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
      expect(createdAt.isAfter(after.add(const Duration(seconds: 1))), isFalse);
    });
  });
}
