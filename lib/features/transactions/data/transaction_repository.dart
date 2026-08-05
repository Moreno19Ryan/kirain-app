import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../categories/data/category.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(Supabase.instance.client);
});

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
}
