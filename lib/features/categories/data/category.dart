enum CategoryKind { expense, income }

enum ExpenseType { wajib, keinginan }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.expenseType,
    this.budgetLimit,
    this.alertThresholdPct = 80,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final ExpenseType? expenseType;

  /// Null means the user hasn't set a limit for this category yet.
  final num? budgetLimit;

  /// Percentage of [budgetLimit] at which the category flags "Zona Waspada"
  /// on Home — defaults to 80 per CLAUDE.md, customizable per category.
  final int alertThresholdPct;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] == 'income' ? CategoryKind.income : CategoryKind.expense,
      expenseType: switch (json['expense_type']) {
        'wajib' => ExpenseType.wajib,
        'keinginan' => ExpenseType.keinginan,
        _ => null,
      },
      budgetLimit: json['budget_limit'] as num?,
      alertThresholdPct: json['alert_threshold_pct'] as int? ?? 80,
    );
  }
}
