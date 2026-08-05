enum CategoryKind { expense, income }

enum ExpenseType { wajib, keinginan }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.expenseType,
  });

  final String id;
  final String name;
  final CategoryKind kind;
  final ExpenseType? expenseType;

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
    );
  }
}
