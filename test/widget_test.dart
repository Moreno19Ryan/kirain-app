import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        items: [CategorySpend(category: category, spent: 150000)],
        totalSpent: 150000,
        totalLimit: 100000,
      ),
      keinginan: const BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0),
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
}
