import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/sync/sync_worker.dart';
import 'package:kirain/core/sync/transaction_sync_service.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/categories/data/category_repository.dart';
import 'package:kirain/features/home/data/dashboard_summary.dart';
import 'package:kirain/features/rekap/rekap_screen.dart';
import 'package:kirain/features/transactions/data/transaction_repository.dart';

void main() {
  // Each test spins up its own throwaway in-memory KirainDatabase (see
  // _FakeTransactionRepository) purely to satisfy the constructor — never
  // shared, so Drift's "created multiple times" warning here is a false
  // positive, not a real race.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final today = DateTime.now();

  final items = [
    TransactionHistoryItem(
      id: 't1',
      amount: 32000,
      categoryId: 'k1',
      categoryName: 'Jajan & Nongkrong',
      transactionDate: today,
      expenseType: ExpenseType.keinginan,
    ),
    TransactionHistoryItem(
      id: 't2',
      amount: 200000,
      goalId: 'g1',
      goalName: 'Dana Darurat',
      transactionDate: today,
    ),
    TransactionHistoryItem(
      id: 't3',
      amount: 4500000,
      categoryId: 'i1',
      categoryName: 'Gaji',
      transactionDate: today,
    ),
  ];

  const noComparison = DashboardSummary(
    wajib: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
    keinginan: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
  );

  testWidgets(
    'rekap screen groups transactions by date, shows a NABUNG badge, and signs income vs expense',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(_FakeTransactionRepository(items)),
            categoriesProvider.overrideWith((ref) async => const []),
            dashboardSummaryProvider.overrideWith((ref) async => noComparison),
          ],
          child: const MaterialApp(home: RekapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HARI INI'), findsOneWidget);
      expect(find.text('NABUNG'), findsOneWidget);
      // Gaji is income (+, mint) — the other two are outflows (-), including
      // the savings contribution, which is still cash leaving what's spendable.
      expect(find.textContaining('+ Rp'), findsOneWidget);
      expect(find.textContaining('- Rp'), findsNWidgets(2));
    },
  );

  testWidgets('rekap screen shows the period-over-period comparison for both groups', (tester) async {
    const summary = DashboardSummary(
      wajib: BudgetGroupSummary(items: [], totalSpent: 800000, totalLimit: 1000000, previousTotalSpent: 500000),
      keinginan: BudgetGroupSummary(items: [], totalSpent: 300000, totalLimit: 1000000, previousTotalSpent: 500000),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(_FakeTransactionRepository(const [])),
          categoriesProvider.overrideWith((ref) async => const []),
          dashboardSummaryProvider.overrideWith((ref) async => summary),
        ],
        child: const MaterialApp(home: RekapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pengeluaran Wajib kamu'), findsOneWidget);
    expect(find.textContaining('naik 60%'), findsOneWidget);
    expect(find.textContaining('Pengeluaran Keinginan kamu'), findsOneWidget);
    expect(find.textContaining('turun 40%'), findsOneWidget);
  });

  testWidgets('rekap screen shows an empty state when there are no transactions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(_FakeTransactionRepository(const [])),
          categoriesProvider.overrideWith((ref) async => const []),
          dashboardSummaryProvider.overrideWith((ref) async => noComparison),
        ],
        child: const MaterialApp(home: RekapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada catatan nih'), findsOneWidget);
  });

  testWidgets('rekap screen lets a category filter be picked from the filter sheet and removed via its chip', (
    tester,
  ) async {
    const category = Category(id: 'k1', name: 'Jajan & Nongkrong', kind: CategoryKind.expense);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(_FakeTransactionRepository(items)),
          categoriesProvider.overrideWith((ref) async => const [category]),
          dashboardSummaryProvider.overrideWith((ref) async => noComparison),
        ],
        child: const MaterialApp(home: RekapScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Kategori: Jajan & Nongkrong'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Category?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jajan & Nongkrong').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kategori: Jajan & Nongkrong'), findsOneWidget);

    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
    await tester.pumpAndSettle();

    expect(find.textContaining('Kategori: Jajan & Nongkrong'), findsNothing);
  });

  testWidgets(
    'rekap screen shows optimistic sync-status badges for not-yet-synced transactions (OFFLINE-003)',
    (tester) async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = KirainDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final outbox = LocalOutboxRepository(db);

      await outbox.insertLocalFirstTransaction(
        OutboxDraft(
          id: 'pending-1',
          userId: 'user-1',
          categoryId: 'k1',
          amount: 15000,
          note: 'jajan sore',
          transactionDate: today.toIso8601String().substring(0, 10),
          createdAt: today,
          expenseType: 'keinginan',
        ),
      );
      await outbox.insertLocalFirstTransaction(
        OutboxDraft(
          id: 'failed-1',
          userId: 'user-1',
          categoryId: 'k1',
          amount: 8000,
          transactionDate: today.toIso8601String().substring(0, 10),
          createdAt: today,
          expenseType: 'keinginan',
        ),
      );
      await outbox.markFailed('failed-1', errorMessage: 'boom');

      // A spy rather than a real SyncWorker: retryFailedItem's actual
      // retry+resync round-trip is already covered by sync_worker_test.dart
      // and local_outbox_repository_test.dart at the unit level. What this
      // widget test needs to prove is narrower — that tapping the "Gagal
      // disinkron" badge calls it with the right id — and asserting on a
      // real worker's eventual DB state here would just be racing its own
      // unawaited processQueue() call.
      final syncWorker = _SpySyncWorker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(
              _FakeTransactionRepository(const [], localOutbox: outbox, currentUserId: () => 'user-1'),
            ),
            categoriesProvider.overrideWith((ref) async => const []),
            dashboardSummaryProvider.overrideWith((ref) async => noComparison),
            syncWorkerProvider.overrideWithValue(syncWorker),
          ],
          child: const MaterialApp(home: RekapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum tersinkron'), findsOneWidget);
      expect(find.text('Gagal disinkron'), findsOneWidget);

      await tester.tap(find.text('Gagal disinkron'));
      await tester.pump();

      expect(syncWorker.retriedId, 'failed-1');
    },
  );
}

class _FakeTransactionRepository extends TransactionRepository {
  // No signed-in user by default: fetchHistoryWithPending's local-overlay
  // branch then short-circuits to fetchHistory (overridden below) without
  // ever touching the LocalOutboxRepository, so an in-memory one is fine
  // here — it exists only to satisfy the constructor. The pending-badge
  // test below passes a real userId + outbox to exercise the real overlay.
  _FakeTransactionRepository(
    this.items, {
    LocalOutboxRepository? localOutbox,
    super.currentUserId = _noSignedInUser,
  }) : super(
         SupabaseClient(
           'https://example.supabase.co',
           'test-anon-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
         localOutbox ?? LocalOutboxRepository(KirainDatabase(NativeDatabase.memory())),
       );

  static String? _noSignedInUser() => null;

  final List<TransactionHistoryItem> items;

  @override
  Future<List<TransactionHistoryItem>> fetchHistory({
    required int limit,
    required int offset,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) async {
    if (offset > 0) return [];
    if (categoryId != null) {
      return items.where((i) => i.categoryId == categoryId).toList();
    }
    return items;
  }
}

class _SpySyncWorker extends SyncWorker {
  _SpySyncWorker()
    : super(LocalOutboxRepository(KirainDatabase(NativeDatabase.memory())), _InertTransactionSyncService());

  String? retriedId;

  @override
  Future<void> retryFailedItem(String id) async {
    retriedId = id;
  }
}

class _InertTransactionSyncService implements TransactionSyncService {
  @override
  Future<void> upsertTransaction(LocalOutboxItem item) async {}
}
