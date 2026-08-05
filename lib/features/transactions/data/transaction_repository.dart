import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../categories/data/category.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(Supabase.instance.client);
});

class TransactionRow {
  const TransactionRow({required this.categoryId, required this.amount, this.expenseType});

  final String categoryId;
  final num amount;
  final ExpenseType? expenseType;

  factory TransactionRow.fromJson(Map<String, dynamic> json) {
    return TransactionRow(
      categoryId: json['category_id'] as String,
      amount: json['amount'] as num,
      expenseType: switch (json['expense_type']) {
        'wajib' => ExpenseType.wajib,
        'keinginan' => ExpenseType.keinginan,
        _ => null,
      },
    );
  }
}

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  Future<void> addTransaction({
    required String categoryId,
    required num amount,
    String? note,
    ExpenseType? expenseType,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('transactions').insert({
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'expense_type': expenseType?.name,
    });
  }

  /// [end] is exclusive.
  Future<List<TransactionRow>> fetchInRange({required DateTime start, required DateTime end}) async {
    final rows = await _client
        .from('transactions')
        .select()
        .gte('transaction_date', _isoDate(start))
        .lt('transaction_date', _isoDate(end));
    return rows.map(TransactionRow.fromJson).toList();
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
