import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/categories/data/category.dart';
import 'package:kirain/features/home/data/dashboard_summary.dart';

const _category = Category(
  id: 'c1',
  name: 'Makan & Minum',
  kind: CategoryKind.expense,
  expenseType: ExpenseType.wajib,
  budgetLimit: 100000,
);

void main() {
  group('BudgetGroupSummary', () {
    test('ratio is 0 with no items and no limit', () {
      const summary = BudgetGroupSummary(items: [], totalSpent: 0, totalLimit: 0);
      expect(summary.hasLimit, isFalse);
      expect(summary.ratio, 0);
    });

    test('ratio is spent/limit under normal (no-rollover) conditions', () {
      const summary = BudgetGroupSummary(
        items: [
          CategorySpend(category: _category, spent: 50000, effectiveLimit: 100000, rollover: 0),
        ],
        totalSpent: 50000,
        totalLimit: 100000,
      );
      expect(summary.ratio, 0.5);
      expect(summary.totalRollover, 0);
    });

    test('a rollover deficit bigger than the limit still counts as over, not "no limit"', () {
      // Base limit 100k, but last cycle overspent by 150k -> effective limit
      // is -50k. hasLimit must stay true (the user did set a limit) and the
      // ratio must read as fully over, not as "no limit configured".
      const summary = BudgetGroupSummary(
        items: [
          CategorySpend(category: _category, spent: 20000, effectiveLimit: -50000, rollover: -150000),
        ],
        totalSpent: 20000,
        totalLimit: -50000,
      );
      expect(summary.hasLimit, isTrue);
      expect(summary.ratio, 1);
      expect(summary.totalRollover, -150000);
    });

    test('a positive rollover raises the effective limit', () {
      const summary = BudgetGroupSummary(
        items: [
          CategorySpend(category: _category, spent: 80000, effectiveLimit: 130000, rollover: 30000),
        ],
        totalSpent: 80000,
        totalLimit: 130000,
      );
      expect(summary.ratio, closeTo(0.615, 0.001));
      expect(summary.totalRollover, 30000);
    });
  });
}
