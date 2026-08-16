import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_repository.dart';
import 'package:kirain/core/sync/local_first_transaction_service.dart';
import 'package:kirain/core/sync/sync_worker.dart';
import 'package:kirain/core/sync/transaction_sync_service.dart';
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

/// The Catat form got noticeably taller in Fase 3 (mode selector + grouped
/// category chip rows), tall enough that its trailing "Oke, Catat" button
/// falls outside the default test surface and never gets built by the
/// ListView's sliver. Growing the surface avoids scrolling gymnastics.
void _growTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // The double-tap guard test below spins up several throwaway in-memory
  // KirainDatabases (see its _NoOpDuplicateCheckRepository/syncWorkerProvider
  // overrides) purely to satisfy constructors — never shared, so Drift's
  // "created multiple times" warning here is a false positive, not a race.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

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

      _growTestSurface(tester);
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

      await tester.tap(find.text('Makan & Minum'));
      await tester.pumpAndSettle();

      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Keinginan'), findsOneWidget);
    },
  );

  testWidgets(
    'catat form groups categories into Wajib/Keinginan/Pemasukan sections with icons',
    (tester) async {
      const categories = [
        Category(
          id: 'w1',
          name: 'Makan & Minum',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.wajib,
        ),
        Category(
          id: 'k1',
          name: 'Jajan & Nongkrong',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.keinginan,
        ),
        Category(id: 'i1', name: 'Gaji', kind: CategoryKind.income),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [categoriesProvider.overrideWith((ref) async => categories)],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAJIB'), findsOneWidget);
      expect(find.text('KEINGINAN'), findsOneWidget);
      expect(find.text('PEMASUKAN'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
      expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'catat screen switches to Nabung mode and shows a goal picker instead of categories',
    (tester) async {
      const categories = [
        Category(
          id: 'c1',
          name: 'Makan & Minum',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.wajib,
        ),
      ];
      const goals = [
        SavingsGoal(
          id: 'g1',
          name: 'Dana Darurat',
          targetAmount: 5000000,
          currentAmount: 1000000,
          isEmergencyFund: true,
          priorityOrder: 0,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => categories),
            savingsGoalsProvider.overrideWith((ref) async => goals),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Makan & Minum'), findsOneWidget);

      await tester.tap(find.text('Nabung'));
      await tester.pumpAndSettle();

      expect(find.text('Kategori'), findsNothing);
      expect(find.text('Target Nabung'), findsOneWidget);
    },
  );

  testWidgets(
    'catat form shows an inline riba warning as the note field is typed, and hides it again once removed',
    (tester) async {
      const categories = [
        Category(
          id: 'c1',
          name: 'Makan & Minum',
          kind: CategoryKind.expense,
          expenseType: ExpenseType.wajib,
        ),
      ];

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [categoriesProvider.overrideWith((ref) async => categories)],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('berbunga (riba)'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Catatan (opsional)'), 'bayar cicilan motor');
      await tester.pump();

      expect(find.textContaining('berbunga (riba)'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Catatan (opsional)'), 'makan siang');
      await tester.pump();

      expect(find.textContaining('berbunga (riba)'), findsNothing);
    },
  );

  testWidgets(
    'catat form lets the wajib/keinginan toggle be overridden manually, driving the checkout warning',
    (tester) async {
      const wajibCategory = Category(
        id: 'w1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
        budgetLimit: 1000000,
      );

      final summary = DashboardSummary(
        wajib: const BudgetGroupSummary(
          items: [CategorySpend(category: wajibCategory, spent: 500000, effectiveLimit: 1000000, rollover: 0)],
          totalSpent: 500000,
          totalLimit: 1000000,
          previousTotalSpent: 0,
        ),
        keinginan: const BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0, previousTotalSpent: 0),
      );

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => const [wajibCategory]),
            dashboardSummaryProvider.overrideWith((ref) async => summary),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah (Rp)'), '20000');
      await tester.tap(find.text('Makan & Minum'));
      await tester.pumpAndSettle();

      // Category defaults to Wajib; override it to Keinginan manually.
      await tester.tap(find.text('Keinginan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oke, Catat'));
      await tester.pumpAndSettle();

      // The soft checkout warning only fires for Keinginan while Wajib isn't
      // fully covered — its appearance here proves the override took effect
      // (this category's own default is Wajib, which wouldn't trigger it).
      expect(find.text('Eh tunggu dulu'), findsOneWidget);
      expect(find.textContaining('masih 50%'), findsOneWidget);

      await tester.tap(find.text('Cek lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Eh tunggu dulu'), findsNothing);
    },
  );

  testWidgets(
    'catat form creates a new category via the + Tambah kategori shortcut and selects it',
    (tester) async {
      const wajibCategory = Category(
        id: 'w1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      );
      final fakeRepo = _FakeCategoryRepository([wajibCategory]);

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [categoryRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      expect(find.text('Kategori Baru'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Nama kategori'), 'Hadiah');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // The new category now shows up in the picker (fetchCategories was
      // invalidated and re-run against the fake repo's updated list) and is
      // auto-selected — shown by the Wajib/Keinginan toggle appearing,
      // since only an expense category picks that up.
      expect(find.text('Hadiah'), findsWidgets);
      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Keinginan'), findsOneWidget);
    },
  );

  testWidgets(
    'catat form lets a new category pick a curated icon and color, saved on the row',
    (tester) async {
      final fakeRepo = _FakeCategoryRepository([]);

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [categoryRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nama kategori'), 'Peliharaan');
      await tester.tap(find.byTooltip('Hewan Peliharaan'));
      await tester.tap(find.byTooltip('Netral'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(fakeRepo.categories.last.icon, 'pets');
      expect(fakeRepo.categories.last.color, '#A9B7C4');
    },
  );

  testWidgets(
    'catat form ignores a rapid second tap on Oke, Catat — only one transaction is recorded (OFFLINE-003)',
    (tester) async {
      const wajibCategory = Category(
        id: 'w1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      );

      final db = KirainDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final outbox = LocalOutboxRepository(db);

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => const [wajibCategory]),
            transactionRepositoryProvider.overrideWithValue(_NoOpDuplicateCheckRepository()),
            localFirstTransactionServiceProvider.overrideWithValue(
              LocalFirstTransactionService(outbox, currentUserId: () => 'user-1'),
            ),
            // Submitting also fires `triggerSyncAfterOutboxInsertion`, which
            // reads this provider — its default construction hits
            // `Supabase.instance.client` synchronously (see
            // transaction_sync_service.dart), which throws in a widget test
            // where Supabase was never initialized. Pointed at a separate,
            // permanently-empty outbox (not [outbox]) rather than a working
            // one: a real SyncWorker racing an in-process claim/sync/retry
            // cycle against the row this test is about to assert on would
            // make the assertion's timing depend on that unrelated worker,
            // not on the double-tap guard this test actually verifies.
            syncWorkerProvider.overrideWithValue(
              SyncWorker(
                LocalOutboxRepository(KirainDatabase(NativeDatabase.memory())),
                _NoOpTransactionSyncService(),
                currentUserId: () => 'user-1',
              ),
            ),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah (Rp)'), '20000');
      await tester.tap(find.text('Makan & Minum'));
      await tester.pumpAndSettle();

      // Two taps back-to-back with no pump in between — reproduces the race
      // the synchronous `_isSubmitting` guard exists for (see CatatScreen's
      // doc comment on that field). Without the guard this would land two
      // separate transactions (two distinct client-generated UUIDs).
      await tester.tap(find.text('Oke, Catat'));
      await tester.tap(find.text('Oke, Catat'));
      await tester.pumpAndSettle();

      final recorded = await outbox.pendingItems();
      expect(recorded, hasLength(1));
      expect(find.textContaining('Tercatat!'), findsOneWidget);
    },
  );

  testWidgets(
    'catat form still shows success (not "gagal kesimpen") when the sync trigger fails after a successful '
    'local-first save, and records the transaction exactly once (OFFLINE-INTEGRATION-001 Finding 1)',
    (tester) async {
      const wajibCategory = Category(
        id: 'w1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      );

      final db = KirainDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final outbox = LocalOutboxRepository(db);

      _growTestSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => const [wajibCategory]),
            transactionRepositoryProvider.overrideWithValue(_NoOpDuplicateCheckRepository()),
            localFirstTransactionServiceProvider.overrideWithValue(
              LocalFirstTransactionService(outbox, currentUserId: () => 'user-1'),
            ),
            // Simulates the exact failure mode Finding 1 describes: reading
            // `syncWorkerProvider` (what `triggerSyncAfterOutboxInsertion`
            // does right after the local-first write succeeds) throws
            // synchronously, as it would in production if the provider's
            // construction chain failed for any reason.
            syncWorkerProvider.overrideWith((ref) => throw StateError('simulated trigger failure')),
          ],
          child: const MaterialApp(home: CatatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah (Rp)'), '20000');
      await tester.tap(find.text('Makan & Minum'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oke, Catat'));
      await tester.pumpAndSettle();

      // The save must read as a success — the sync-trigger failure must not
      // be misreported as a save failure.
      expect(find.textContaining('Tercatat!'), findsOneWidget);
      expect(find.textContaining('gagal kesimpen'), findsNothing);

      // And the local-first write itself must have happened exactly once —
      // a trigger failure must not cause (or mask) a duplicate write.
      final recorded = await outbox.pendingItems();
      expect(recorded, hasLength(1));
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

  testWidgets('home dashboard flags Zona Aman when Wajib is under its limit', (tester) async {
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
          CategorySpend(category: category, spent: 29000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 29000,
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

    expect(find.text('Zona Aman'), findsOneWidget);
    expect(find.text('29%'), findsOneWidget);
    expect(find.text('Zona Kirain'), findsNothing);
  });

  testWidgets('home dashboard shows "Belum Ada Limit" when Wajib has no limit set at all', (
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

    expect(find.text('Belum Ada Limit'), findsOneWidget);
    expect(find.text('Zona Aman'), findsNothing);
    expect(find.text('Zona Kirain'), findsNothing);
  });

  testWidgets('home dashboard shows a specific icon per category in its detail section', (
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
          CategorySpend(category: category, spent: 50000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 50000,
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

    await tester.tap(find.text('Rincian Wajib'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
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

    await tester.tap(find.text('Rincian Keinginan'));
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

  testWidgets('manage categories screen shows a retry button on error and recovers on tap', (
    tester,
  ) async {
    // Riverpod 3 retries a failed provider automatically several times
    // before settling into a persistent error, so this doesn't count
    // invocations — it just checks that tapping "Coba Lagi" after that
    // point can still recover once the underlying fetch starts succeeding.
    var shouldSucceed = false;
    const categories = [
      Category(
        id: 'c1',
        name: 'Makan & Minum',
        kind: CategoryKind.expense,
        expenseType: ExpenseType.wajib,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) async {
            if (!shouldSucceed) throw Exception('boom');
            return categories;
          }),
        ],
        child: const MaterialApp(home: ManageCategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal muat kategori. Coba lagi ya.'), findsOneWidget);

    shouldSucceed = true;
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal muat kategori. Coba lagi ya.'), findsNothing);
    expect(find.text('Makan & Minum'), findsOneWidget);
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

    // Each row shows its own specific icon, not a shared generic one.
    expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(find.byIcon(Icons.category_outlined), findsNothing);

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

class _FakeCategoryRepository extends CategoryRepository {
  _FakeCategoryRepository(this.categories)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<Category> categories;

  @override
  Future<List<Category>> fetchCategories() async => List.of(categories);

  @override
  Future<Category> createCategory({
    required String name,
    required CategoryKind kind,
    ExpenseType? expenseType,
    num? budgetLimit,
    int alertThresholdPct = 80,
    String? icon,
    String? color,
  }) async {
    final created = Category(
      id: 'new-${categories.length}',
      name: name,
      kind: kind,
      expenseType: expenseType,
      budgetLimit: budgetLimit,
      alertThresholdPct: alertThresholdPct,
      icon: icon,
      color: color,
    );
    categories.add(created);
    return created;
  }
}

/// Used only by the double-tap guard test — its one job is to keep
/// `_doSubmit`'s soft duplicate check off the network entirely, so that test
/// stays about the guard, not about Supabase reachability.
class _NoOpDuplicateCheckRepository extends TransactionRepository {
  _NoOpDuplicateCheckRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        LocalOutboxRepository(KirainDatabase(NativeDatabase.memory())),
        currentUserId: () => null,
      );

  @override
  Future<bool> hasPossibleDuplicate({
    required String categoryId,
    required num amount,
    required DateTime date,
  }) async => false;
}

/// Also used only by the double-tap guard test, pairing with
/// [_NoOpDuplicateCheckRepository]'s reasoning: `triggerSyncAfterOutboxInsertion`
/// fires a real `processQueue()` call after every local-first submit, and
/// this keeps that off Supabase entirely. Always fails (simulating offline)
/// rather than succeeding, so the recorded row stays PENDING instead of
/// being synced-and-deleted out from under the test's own assertion.
class _NoOpTransactionSyncService implements TransactionSyncService {
  @override
  Future<void> upsertTransaction(LocalOutboxItem item) async {
    throw Exception('offline (test double)');
  }
}
