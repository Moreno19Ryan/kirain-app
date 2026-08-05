import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../budget/data/budget_cycle.dart';
import '../../budget/data/budget_settings_repository.dart';
import '../../categories/data/category.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transaction_repository.dart';

class CategorySpend {
  const CategorySpend({required this.category, required this.spent});

  final Category category;
  final num spent;
}

class BudgetGroupSummary {
  const BudgetGroupSummary({
    required this.items,
    required this.totalSpent,
    required this.totalLimit,
  });

  final List<CategorySpend> items;
  final num totalSpent;
  final num totalLimit;

  double get ratio => totalLimit > 0 ? totalSpent / totalLimit : 0;
}

class DashboardSummary {
  const DashboardSummary({required this.wajib, required this.keinginan});

  final BudgetGroupSummary wajib;
  final BudgetGroupSummary keinginan;
}

final currentCycleProvider = FutureProvider<BudgetCycle>((ref) async {
  final settings = await ref.watch(budgetSettingsProvider.future);
  return BudgetCycle.current(DateTime.now(), settings.cycleStartDay);
});

final currentCycleTransactionsProvider = FutureProvider((ref) async {
  final cycle = await ref.watch(currentCycleProvider.future);
  return ref
      .watch(transactionRepositoryProvider)
      .fetchInRange(start: cycle.start, end: cycle.end);
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final transactions = await ref.watch(currentCycleTransactionsProvider.future);

  final expenseCategories = categories.where((c) => c.kind == CategoryKind.expense);

  BudgetGroupSummary summarize(ExpenseType type) {
    final items = expenseCategories
        .map((category) {
          final spent = transactions
              .where((t) => t.categoryId == category.id && t.expenseType == type)
              .fold<num>(0, (sum, t) => sum + t.amount);
          return CategorySpend(category: category, spent: spent);
        })
        // Auto-collapse: hide categories with nothing spent and no limit set.
        .where((cs) => cs.spent > 0 || (cs.category.budgetLimit ?? 0) > 0)
        .toList();

    final totalSpent = items.fold<num>(0, (sum, i) => sum + i.spent);
    final totalLimit = items.fold<num>(0, (sum, i) => sum + (i.category.budgetLimit ?? 0));

    return BudgetGroupSummary(items: items, totalSpent: totalSpent, totalLimit: totalLimit);
  }

  return DashboardSummary(
    wajib: summarize(ExpenseType.wajib),
    keinginan: summarize(ExpenseType.keinginan),
  );
});
