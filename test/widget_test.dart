import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:kirain/features/app_lock/data/app_lock_repository.dart';
import 'package:kirain/features/app_lock/presentation/lock_screen.dart';
import 'package:kirain/features/auth/presentation/otp_verify_screen.dart';
import 'package:kirain/features/auth/presentation/sign_in_screen.dart';
import 'package:kirain/features/catat/catat_screen.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/categories/data/category_repository.dart';
import 'package:kirain/features/categories/presentation/manage_categories_screen.dart';
import 'package:kirain/features/goals/data/savings_goal.dart';
import 'package:kirain/features/goals/data/savings_goal_repository.dart';
import 'package:kirain/features/goals/presentation/manage_goals_screen.dart';
import 'package:kirain/features/home/data/dashboard_summary.dart';
import 'package:kirain/features/home/home_screen.dart';
import 'package:kirain/features/recurring/data/recurring_transaction.dart';
import 'package:kirain/features/recurring/data/recurring_transaction_repository.dart';
import 'package:kirain/features/recurring/presentation/manage_recurring_screen.dart';
import 'package:kirain/features/transactions/data/transaction_repository.dart';

void main() {
  testWidgets('sign-in screen shows an email field and submit button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Kirim Kode'), findsOneWidget);
  });

  testWidgets('otp verify screen shows the target email and a code field', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OtpVerifyScreen(email: 'reno@example.com')),
      ),
    );

    expect(find.textContaining('reno@example.com'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets(
    'catat form shows the wajib/keinginan toggle only for expense categories',
    (tester) async {
      const categories = [
        Category(
          id: 'c1',
          name: 'Makan & Minum',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.wajib,
        ),
        Category(id: 'c2', name: 'Gaji', kind: CategoryKind.income),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => categories),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jumlah (Rp)'), findsOneWidget);
      expect(find.text('Oke, Catat'), findsOneWidget);
      expect(find.text('Wajib'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<Category>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makan & Minum').last);
      await tester.pumpAndSettle();

      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Keinginan'), findsOneWidget);
    },
  );

  testWidgets('home dashboard flags Zona Kirain when spending is over the limit', (
    tester,
  ) async {
    const category = Category(
      id: 'c1',
      name: 'Makan & Minum',
      kind: CategoryKind.expense,
      expenseType: ExpenseType.wajib,
      budgetLimit: 100000,
    );

    final summary = DashboardSummary(
      wajib: const BudgetGroupSummary(
        items: [
          CategorySpend(category: category, spent: 150000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 150000,
        totalLimit: 100000,
        previousTotalSpent: 0,
      ),
      keinginan: const BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardSummaryProvider.overrideWith((ref) async => summary)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Progress Cukup'), findsOneWidget);
    expect(find.text('Zona Kirain'), findsOneWidget);
    expect(find.text('Keinginan'), findsOneWidget);
  });

  testWidgets('home dashboard shows the period-over-period comparison when there was prior spending', (
    tester,
  ) async {
    const category = Category(
      id: 'c1',
      name: 'Makan & Minum',
      kind: CategoryKind.expense,
      expenseType: ExpenseType.wajib,
      budgetLimit: 100000,
    );

    final summary = DashboardSummary(
      wajib: const BudgetGroupSummary(
        items: [
          CategorySpend(category: category, spent: 75000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 75000,
        totalLimit: 100000,
        previousTotalSpent: 50000,
      ),
      keinginan: const BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardSummaryProvider.overrideWith((ref) async => summary)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Naik 50% dari bulan lalu'), findsOneWidget);
  });

  testWidgets('home dashboard flags Zona Waspada when a category nears its alert threshold', (
    tester,
  ) async {
    const category = Category(
      id: 'c1',
      name: 'Jajan & Nongkrong',
      kind: CategoryKind.expense,
      expenseType: ExpenseType.keinginan,
      budgetLimit: 100000,
      alertThresholdPct: 80,
    );

    final summary = DashboardSummary(
      wajib: const BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
      keinginan: const BudgetGroupSummary(
        items: [
          CategorySpend(category: category, spent: 85000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 85000,
        totalLimit: 100000,
        previousTotalSpent: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dashboardSummaryProvider.overrideWith((ref) async => summary)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rincian per kategori'));
    await tester.pumpAndSettle();

    expect(find.text('Zona Waspada — udah mendekati limit nih'), findsOneWidget);
    expect(find.text('Zona Kirain'), findsNothing);
  });

  testWidgets('home dashboard shows the retroactive-entry nudge for a brand-new account', (
    tester,
  ) async {
    const summary = DashboardSummary(
      wajib: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
      keinginan: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryProvider.overrideWith((ref) async => summary),
          hasAnyTransactionsProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Baru mulai nih?'), findsOneWidget);
  });

  testWidgets('home dashboard hides the retroactive-entry nudge once there is any transaction', (
    tester,
  ) async {
    const summary = DashboardSummary(
      wajib: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
      keinginan: BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryProvider.overrideWith((ref) async => summary),
          hasAnyTransactionsProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Baru mulai nih?'), findsNothing);
  });

  testWidgets('manage categories screen groups by Wajib/Keinginan/Pemasukan and confirms delete', (
    tester,
  ) async {
    const categories = [
      Category(
        id: 'c1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      ),
      Category(
        id: 'c2',
        name: 'Jajan & Nongkrong',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.keinginan,
      ),
      Category(id: 'c3', name: 'Gaji', kind: CategoryKind.income),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [categoriesProvider.overrideWith((ref) async => categories)],
        child: const MaterialApp(home: ManageCategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wajib'), findsOneWidget);
    expect(find.text('Keinginan'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Makan & Minum'), findsOneWidget);
    expect(find.text('Gaji'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Yakin nih?'), findsOneWidget);
  });

  testWidgets('manage goals screen shows progress and an emergency fund badge', (tester) async {
    const goal = SavingsGoal(
      id: 'g1',
      name: 'Dana Darurat',
      targetAmount: 1000000,
      currentAmount: 250000,
      isEmergencyFund: true,
      priorityOrder: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [savingsGoalsProvider.overrideWith((ref) async => [goal])],
        child: const MaterialApp(home: ManageGoalsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dana Darurat'), findsWidgets);
    expect(find.text('Rp 250.000 dari Rp 1.000.000'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('manage recurring screen lists rules with frequency and due date', (tester) async {
    final rule = RecurringTransaction(
      id: 'r1',
      categoryId: 'c1',
      categoryName: 'Tagihan',
      amount: 300000,
      expenseType: ExpenseType.wajib,
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 1),
      isActive: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [recurringTransactionsProvider.overrideWith((ref) async => [rule])],
        child: const MaterialApp(home: ManageRecurringScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tagihan'), findsOneWidget);
    expect(find.textContaining('Tiap bulan'), findsOneWidget);
    expect(find.textContaining('1 Sep 2026'), findsOneWidget);
  });

  testWidgets('lock screen unlocks on correct PIN', (tester) async {
    var unlocked = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockRepositoryProvider.overrideWithValue(_FakeAppLockRepository(verifyResult: true)),
        ],
        child: MaterialApp(home: LockScreen(onUnlocked: () => unlocked = true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KIRAIN Terkunci'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });

  testWidgets('lock screen shows an error and stays locked on wrong PIN', (tester) async {
    var unlocked = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockRepositoryProvider.overrideWithValue(_FakeAppLockRepository(verifyResult: false)),
        ],
        child: MaterialApp(home: LockScreen(onUnlocked: () => unlocked = true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(unlocked, isFalse);
    expect(find.text('PIN salah, coba lagi ya'), findsOneWidget);
  });
}

class _FakeAppLockRepository extends AppLockRepository {
  _FakeAppLockRepository({required this.verifyResult})
    : super(const FlutterSecureStorage(), LocalAuthentication());

  final bool verifyResult;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<bool> verifyPin(String pin) async => verifyResult;
}
