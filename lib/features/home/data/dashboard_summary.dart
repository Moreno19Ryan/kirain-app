import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../budget/data/budget_cycle.dart';
import '../../budget/data/budget_settings_repository.dart';
import '../../categories/data/category.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transaction_repository.dart';

class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.spent,
    required this.effectiveLimit,
    required this.rollover,
  });

  final Category category;
  final num spent;

  /// This cycle's budget_limit plus [rollover] — what's actually available
  /// to spend this cycle. Can be negative if last cycle's deficit was
  /// bigger than this cycle's limit.
  final num effectiveLimit;

  /// Carried over from the previous cycle: positive if it was underspent,
  /// negative if it was overspent. Zero when rollover is off or the
  /// category had no limit last cycle.
  final num rollover;
}

class BudgetGroupSummary {
  const BudgetGroupSummary({
    required this.items,
    required this.totalSpent,
    required this.totalLimit,
  });

  final List<CategorySpend> items;
  final num totalSpent;

  /// Sum of each item's effective (post-rollover) limit.
  final num totalLimit;

  num get totalRollover => items.fold<num>(0, (sum, i) => sum + i.rollover);

  bool get hasLimit => items.any((i) => (i.category.budgetLimit ?? 0) > 0);

  double get ratio {
    if (totalLimit <= 0) return hasLimit ? 1 : 0;
    return totalSpent / totalLimit;
  }
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

/// Only the immediately preceding cycle rolls over — not an indefinite
/// cascade back to account creation. Keeps this a single bounded query
/// instead of an ever-growing historical scan as the account ages.
final previousCycleTransactionsProvider = FutureProvider((ref) async {
  final cycle = await ref.watch(currentCycleProvider.future);
  final settings = await ref.watch(budgetSettingsProvider.future);
  final previous = cycle.previous(settings.cycleStartDay);
  return ref
      .watch(transactionRepositoryProvider)
      .fetchInRange(start: previous.start, end: previous.end);
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final transactions = await ref.watch(currentCycleTransactionsProvider.future);
  final settings = await ref.watch(budgetSettingsProvider.future);
  final previousTransactions = settings.rolloverEnabled
      ? await ref.watch(previousCycleTransactionsProvider.future)
      : const <TransactionRow>[];

  final expenseCategories = categories.where((c) => c.kind == CategoryKind.expense);

  num rolloverFor(Category category, ExpenseType type) {
    final limit = category.budgetLimit ?? 0;
    if (!settings.rolloverEnabled || limit <= 0) return 0;

    final previousSpent = previousTransactions
        .where((t) => t.categoryId == category.id && t.expenseType == type)
        .fold<num>(0, (sum, t) => sum + t.amount);
    return limit - previousSpent;
  }

  BudgetGroupSummary summarize(ExpenseType type) {
    final items = expenseCategories
        .map((category) {
          final spent = transactions
              .where((t) => t.categoryId == category.id && t.expenseType == type)
              .fold<num>(0, (sum, t) => sum + t.amount);
          final baseLimit = category.budgetLimit ?? 0;
          final rollover = rolloverFor(category, type);
          final effectiveLimit = baseLimit > 0 ? baseLimit + rollover : 0;
          return CategorySpend(
            category: category,
            spent: spent,
            effectiveLimit: effectiveLimit,
            rollover: rollover,
          );
        })
        // Auto-collapse: hide categories with nothing spent and no limit set.
        .where((cs) => cs.spent > 0 || (cs.category.budgetLimit ?? 0) > 0)
        .toList();

    final totalSpent = items.fold<num>(0, (sum, i) => sum + i.spent);
    final totalLimit = items.fold<num>(0, (sum, i) => sum + i.effectiveLimit);

    return BudgetGroupSummary(items: items, totalSpent: totalSpent, totalLimit: totalLimit);
  }

  return DashboardSummary(
    wajib: summarize(ExpenseType.wajib),
    keinginan: summarize(ExpenseType.keinginan),
  );
});
