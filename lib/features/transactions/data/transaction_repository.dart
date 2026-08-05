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

class TransactionHistoryItem {
  const TransactionHistoryItem({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
    this.note,
    this.expenseType,
  });

  final String id;
  final num amount;
  final String categoryId;
  final String categoryName;
  final DateTime transactionDate;
  final String? note;
  final ExpenseType? expenseType;

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;

    return TransactionHistoryItem(
      id: json['id'] as String,
      amount: json['amount'] as num,
      categoryId: json['category_id'] as String,
      categoryName: category?['name'] as String? ?? '-',
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      note: json['note'] as String?,
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

  /// Paginated, most-recent-first — lazy loading per CLAUDE.md's performance
  /// requirement (never load the whole transaction history at once).
  Future<List<TransactionHistoryItem>> fetchHistory({
    required int limit,
    required int offset,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) async {
    var query = _client
        .from('transactions')
        .select('id, amount, note, transaction_date, expense_type, category_id, categories(name)');

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (startDate != null) query = query.gte('transaction_date', _isoDate(startDate));
    if (endDate != null) query = query.lt('transaction_date', _isoDate(endDate));
    if (searchText != null && searchText.isNotEmpty) query = query.ilike('note', '%$searchText%');

    final rows = await query
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows.map(TransactionHistoryItem.fromJson).toList();
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
