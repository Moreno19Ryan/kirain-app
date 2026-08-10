import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/categories/data/category_repository.dart';
import 'package:kirain/features/home/data/dashboard_summary.dart';
import 'package:kirain/features/rekap/rekap_screen.dart';
import 'package:kirain/features/transactions/data/transaction_repository.dart';

void main() {
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
}

class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository(this.items)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

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
