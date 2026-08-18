import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/database/local_outbox_table.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/transactions/data/transaction_repository.dart';

/// A [TransactionRepository] whose [fetchHistory] (the Supabase side) is
/// replaced by a canned page, so [fetchHistoryWithPending] — which is left
/// un-overridden and calls `fetchHistory` polymorphically — can be exercised
/// against real merge logic without any network access. [currentUserId] is
/// the same injectable seam `LocalFirstTransactionService`/`SyncWorker` use.
///
/// Also overrides [hasSupabaseDuplicate] (a canned bool, defaulting to
/// `false`) for the same reason — Finding 3's `hasPossibleDuplicate` tests
/// need to control the Supabase side of the check without real network
/// access, while exercising the real local-side query
/// ([hasLocalDuplicate], left un-overridden) against a real in-memory
/// Drift database.
class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository(
    this._syncedPages,
    LocalOutboxRepository localOutbox, {
    super.currentUserId,
    this.supabaseHasDuplicate = false,
  }) : super(
         SupabaseClient(
           'https://example.supabase.co',
           'test-anon-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
         localOutbox,
       );

  /// Keyed by offset — each call to [fetchHistory] returns whatever page is
  /// registered for the offset it's asked for (defaulting to empty), the
  /// same way Supabase's real `.range(offset, ...)` would page through a
  /// larger result set.
  final Map<int, List<TransactionHistoryItem>> _syncedPages;

  final bool supabaseHasDuplicate;

  @override
  Future<List<TransactionHistoryItem>> fetchHistory({
    required int limit,
    required int offset,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) async {
    return _syncedPages[offset] ?? const [];
  }

  @override
  Future<bool> hasSupabaseDuplicate({required String categoryId, required num amount, required DateTime date}) {
    return Future.value(supabaseHasDuplicate);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TransactionRepository.fetchHistoryWithPending (OFFLINE-003)', () {
    late KirainDatabase db;
    late LocalOutboxRepository outbox;

    setUp(() {
      db = KirainDatabase(NativeDatabase.memory());
      outbox = LocalOutboxRepository(db);
    });

    tearDown(() => db.close());

    Future<void> insertLocal({
      required String id,
      required String userId,
      String categoryId = 'cat-1',
      int amount = 20000,
      String? note,
      String transactionDate = '2026-08-15',
      OutboxSyncStatus status = OutboxSyncStatus.pending,
    }) async {
      final draft = OutboxDraft(
        id: id,
        userId: userId,
        categoryId: categoryId,
        amount: amount,
        note: note,
        transactionDate: transactionDate,
        createdAt: DateTime.utc(2026, 8, 15),
        expenseType: 'keinginan',
      );
      await outbox.insertLocalFirstTransaction(draft);
      if (status == OutboxSyncStatus.failed) {
        await outbox.markFailed(id, errorMessage: 'boom');
      } else if (status == OutboxSyncStatus.syncing) {
        await outbox.markSyncing(id);
      }
    }

    test('no signed-in user: returns the Supabase page unchanged', () async {
      await insertLocal(id: 'local-1', userId: 'user-1');
      final repo = _FakeTransactionRepository(
        {
          0: [_synced('synced-1')],
        },
        outbox,
        currentUserId: () => null,
      );

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.map((i) => i.id), ['synced-1']);
    });

    test('offset != 0 delegates straight to fetchHistory — no local overlay on later pages', () async {
      await insertLocal(id: 'local-1', userId: 'user-1');
      final repo = _FakeTransactionRepository(
        {
          20: [_synced('synced-page-2')],
        },
        outbox,
        currentUserId: () => 'user-1',
      );

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 20);

      expect(result.map((i) => i.id), ['synced-page-2']);
    });

    test('a pending local row not present in the Supabase page is merged in', () async {
      await insertLocal(id: 'local-1', userId: 'user-1', note: 'kopi pagi');
      final repo = _FakeTransactionRepository(
        {
          0: [_synced('synced-1')],
        },
        outbox,
        currentUserId: () => 'user-1',
      );

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.map((i) => i.id).toSet(), {'synced-1', 'local-1'});
      final pendingItem = result.firstWhere((i) => i.id == 'local-1');
      expect(pendingItem.pendingStatus, OutboxSyncStatus.pending);
      expect(pendingItem.note, 'kopi pagi');
    });

    test('a local row whose id also appears in the Supabase page is not duplicated — Supabase wins', () async {
      await insertLocal(id: 'dup-1', userId: 'user-1', amount: 99999, note: 'stale local copy');
      final repo = _FakeTransactionRepository(
        {
          0: [_synced('dup-1', amount: 20000, note: 'confirmed by supabase')],
        },
        outbox,
        currentUserId: () => 'user-1',
      );

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.where((i) => i.id == 'dup-1'), hasLength(1));
      final merged = result.firstWhere((i) => i.id == 'dup-1');
      expect(merged.amount, 20000);
      expect(merged.note, 'confirmed by supabase');
      // Supabase's row has no pendingStatus by construction — winning means
      // the synced copy (and its null pendingStatus) is what's kept.
      expect(merged.pendingStatus, isNull);
    });

    test('a local row whose sync status can no longer be found is silently dropped, not shown as pending', () async {
      // Simulates a race with SyncWorker: by the time fetchHistoryWithPending
      // reads sync statuses, deleteSynced has already removed the outbox
      // row (though this LocalTransactions row happens to still be read in
      // the same pass) — LocalOutboxRepository's own atomicity means this is
      // a narrow window, but the merge must handle it defensively rather
      // than show a phantom "belum tersinkron" badge for an already-synced
      // transaction.
      await db
          .into(db.localTransactions)
          .insert(
            LocalTransactionsCompanion.insert(
              id: 'orphaned',
              userId: 'user-1',
              categoryId: const Value('cat-1'),
              amount: 5000,
              transactionDate: '2026-08-15',
              createdAt: DateTime.utc(2026, 8, 15),
            ),
          );
      final repo = _FakeTransactionRepository({0: []}, outbox, currentUserId: () => 'user-1');

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result, isEmpty);
    });

    test('user ownership: a local row belonging to another user never appears', () async {
      await insertLocal(id: 'mine', userId: 'user-A');
      await insertLocal(id: 'not-mine', userId: 'user-B');
      final repo = _FakeTransactionRepository({0: []}, outbox, currentUserId: () => 'user-A');

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.map((i) => i.id), ['mine']);
    });

    test('deterministic sort: date desc, pending rows before synced rows on the same date, then id', () async {
      await insertLocal(id: 'z-pending', userId: 'user-1', transactionDate: '2026-08-15');
      await insertLocal(id: 'a-pending', userId: 'user-1', transactionDate: '2026-08-15');
      final repo = _FakeTransactionRepository(
        {
          0: [
            _synced('b-synced-older', date: DateTime(2026, 8, 14)),
            _synced('m-synced-same-day', date: DateTime(2026, 8, 15)),
          ],
        },
        outbox,
        currentUserId: () => 'user-1',
      );

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.map((i) => i.id).toList(), [
        'a-pending',
        'z-pending',
        'm-synced-same-day',
        'b-synced-older',
      ]);
    });

    test('category and search filters apply to the local overlay the same as the synced query', () async {
      await insertLocal(id: 'match-cat', userId: 'user-1', categoryId: 'cat-1', note: 'makan siang');
      await insertLocal(id: 'other-cat', userId: 'user-1', categoryId: 'cat-2', note: 'makan siang');
      await insertLocal(id: 'no-note-match', userId: 'user-1', categoryId: 'cat-1', note: 'bensin motor');
      final repo = _FakeTransactionRepository({0: []}, outbox, currentUserId: () => 'user-1');

      final result = await repo.fetchHistoryWithPending(
        limit: 20,
        offset: 0,
        categoryId: 'cat-1',
        searchText: 'makan',
      );

      expect(result.map((i) => i.id), ['match-cat']);
    });

    test('FAILED local rows still surface in the overlay with their status', () async {
      await insertLocal(id: 'failed-1', userId: 'user-1', status: OutboxSyncStatus.failed);
      final repo = _FakeTransactionRepository({0: []}, outbox, currentUserId: () => 'user-1');

      final result = await repo.fetchHistoryWithPending(limit: 20, offset: 0);

      expect(result.single.pendingStatus, OutboxSyncStatus.failed);
    });
  });

  group('TransactionRepository.hasPossibleDuplicate (OFFLINE-INTEGRATION-001 Finding 3)', () {
    late KirainDatabase db;
    late LocalOutboxRepository outbox;

    setUp(() {
      db = KirainDatabase(NativeDatabase.memory());
      outbox = LocalOutboxRepository(db);
    });

    tearDown(() => db.close());

    Future<void> insertLocal({
      required String id,
      required String userId,
      String categoryId = 'cat-1',
      int amount = 20000,
      String transactionDate = '2026-08-15',
      OutboxSyncStatus status = OutboxSyncStatus.pending,
    }) async {
      final draft = OutboxDraft(
        id: id,
        userId: userId,
        categoryId: categoryId,
        amount: amount,
        transactionDate: transactionDate,
        createdAt: DateTime.utc(2026, 8, 15),
        expenseType: 'keinginan',
      );
      await outbox.insertLocalFirstTransaction(draft);
      if (status == OutboxSyncStatus.failed) {
        await outbox.markFailed(id, errorMessage: 'boom');
      } else if (status == OutboxSyncStatus.syncing) {
        await outbox.markSyncing(id);
      }
    }

    test('a duplicate that exists only in Supabase (nothing local) is detected', () async {
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1', supabaseHasDuplicate: true);

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isTrue);
    });

    test('a duplicate that only exists as a PENDING local row (not yet synced) is detected', () async {
      await insertLocal(id: 'local-1', userId: 'user-1');
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isTrue);
    });

    test('a duplicate that only exists as a SYNCING local row is detected', () async {
      await insertLocal(id: 'local-1', userId: 'user-1', status: OutboxSyncStatus.syncing);
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isTrue);
    });

    test('a duplicate that only exists as a FAILED local row is still detected', () async {
      // Per OFFLINE-003's "Correction C": markFailed never deletes the
      // LocalTransactions echo, so this row is still there to match against
      // — exactly the case this fix exists to catch (a user whose first
      // entry failed to send gets no warning on a genuine repeat).
      await insertLocal(id: 'local-1', userId: 'user-1', status: OutboxSyncStatus.failed);
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isTrue);
    });

    test('a transaction that has already synced (local echo cleaned up) is still detected via Supabase', () async {
      await insertLocal(id: 'local-1', userId: 'user-1');
      await outbox.deleteSynced('local-1'); // simulates SyncWorker's post-success cleanup
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1', supabaseHasDuplicate: true);

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isTrue);
      // And the local side alone (Supabase stubbed false) correctly no
      // longer matches — the cleaned-up row isn't a phantom local duplicate.
      final localOnlyRepo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');
      expect(
        await localOnlyRepo.hasPossibleDuplicate(categoryId: 'cat-1', amount: 20000, date: DateTime(2026, 8, 15)),
        isFalse,
      );
    });

    test('a different category does not false-positive', () async {
      await insertLocal(id: 'local-1', userId: 'user-1', categoryId: 'cat-1');
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-2',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isFalse);
    });

    test('a different amount does not false-positive', () async {
      await insertLocal(id: 'local-1', userId: 'user-1', amount: 20000);
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 25000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isFalse);
    });

    test('a different date does not false-positive', () async {
      await insertLocal(id: 'local-1', userId: 'user-1', transactionDate: '2026-08-15');
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-1');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 16),
      );

      expect(result, isFalse);
    });

    test('another user\'s matching local transaction is never treated as a duplicate', () async {
      await insertLocal(id: 'not-mine', userId: 'user-B');
      final repo = _FakeTransactionRepository({}, outbox, currentUserId: () => 'user-A');

      final result = await repo.hasPossibleDuplicate(
        categoryId: 'cat-1',
        amount: 20000,
        date: DateTime(2026, 8, 15),
      );

      expect(result, isFalse);
    });
  });
}

TransactionHistoryItem _synced(String id, {int amount = 20000, String? note, DateTime? date}) {
  return TransactionHistoryItem(
    id: id,
    amount: amount,
    categoryId: 'cat-1',
    categoryName: 'Jajan & Nongkrong',
    transactionDate: date ?? DateTime(2026, 8, 15),
    note: note,
    expenseType: ExpenseType.keinginan,
  );
}
