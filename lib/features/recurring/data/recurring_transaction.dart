import '../../categories/data/category.dart';

enum RecurrenceFrequency { weekly, monthly }

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.expenseType,
    required this.frequency,
    required this.nextDueDate,
    required this.isActive,
    this.note,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final num amount;
  final ExpenseType expenseType;
  final RecurrenceFrequency frequency;
  final DateTime nextDueDate;
  final bool isActive;
  final String? note;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;

    return RecurringTransaction(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: category?['name'] as String? ?? '-',
      amount: json['amount'] as num,
      expenseType: json['expense_type'] == 'wajib' ? ExpenseType.wajib : ExpenseType.keinginan,
      frequency: json['frequency'] == 'weekly'
          ? RecurrenceFrequency.weekly
          : RecurrenceFrequency.monthly,
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      isActive: json['is_active'] as bool,
      note: json['note'] as String?,
    );
  }
}
