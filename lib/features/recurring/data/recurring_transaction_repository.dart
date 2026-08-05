import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/format.dart';
import '../../categories/data/category.dart';
import '../../transactions/data/transaction_repository.dart';
import 'recurring_transaction.dart';

const _selectColumns =
    'id, category_id, amount, note, expense_type, frequency, next_due_date, is_active, categories(name)';

final recurringTransactionRepositoryProvider = Provider<RecurringTransactionRepository>((ref) {
  return RecurringTransactionRepository(Supabase.instance.client, ref.watch(transactionRepositoryProvider));
});

final recurringTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) {
  return ref.watch(recurringTransactionRepositoryProvider).fetchAll();
});

/// Separate from [recurringTransactionsProvider] so the Home due-check can
/// be overridden independently in tests without touching a real client.
final dueRecurringTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) {
  return ref.watch(recurringTransactionRepositoryProvider).fetchDue(DateTime.now());
});

class RecurringTransactionRepository {
  RecurringTransactionRepository(this._client, this._transactionRepository);

  final SupabaseClient _client;
  final TransactionRepository _transactionRepository;

  /// RLS already scopes this to the signed-in user's own rules.
  Future<List<RecurringTransaction>> fetchAll() async {
    final rows = await _client
        .from('recurring_transactions')
        .select(_selectColumns)
        .order('next_due_date');
    return rows.map(RecurringTransaction.fromJson).toList();
  }

  Future<List<RecurringTransaction>> fetchDue(DateTime today) async {
    final rows = await _client
        .from('recurring_transactions')
        .select(_selectColumns)
        .eq('is_active', true)
        .lte('next_due_date', isoDate(today))
        .order('next_due_date');
    return rows.map(RecurringTransaction.fromJson).toList();
  }

  Future<void> create({
    required String categoryId,
    required num amount,
    required ExpenseType expenseType,
    required RecurrenceFrequency frequency,
    required DateTime nextDueDate,
    String? note,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('recurring_transactions').insert({
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'note': note,
      'expense_type': expenseType.name,
      'frequency': frequency.name,
      'next_due_date': isoDate(nextDueDate),
    });
  }

  Future<void> update({
    required String id,
    required num amount,
    required ExpenseType expenseType,
    required RecurrenceFrequency frequency,
    String? note,
  }) {
    return _client
        .from('recurring_transactions')
        .update({
          'amount': amount,
          'note': note,
          'expense_type': expenseType.name,
          'frequency': frequency.name,
        })
        .eq('id', id);
  }

  Future<void> setActive(String id, bool isActive) {
    return _client.from('recurring_transactions').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> delete(String id) {
    return _client.from('recurring_transactions').delete().eq('id', id);
  }

  /// Logs a real transaction dated to the due date, then advances
  /// next_due_date to the following occurrence.
  Future<void> confirmOccurrence(RecurringTransaction item) async {
    await _transactionRepository.addTransaction(
      categoryId: item.categoryId,
      amount: item.amount,
      note: item.note,
      expenseType: item.expenseType,
      transactionDate: item.nextDueDate,
    );

    final next = _advance(item.nextDueDate, item.frequency);
    await _client
        .from('recurring_transactions')
        .update({'next_due_date': isoDate(next)})
        .eq('id', item.id);
  }

  DateTime _advance(DateTime date, RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.weekly:
        return date.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        final lastDayNextMonth = DateTime(date.year, date.month + 2, 0).day;
        final day = date.day > lastDayNextMonth ? lastDayNextMonth : date.day;
        return DateTime(date.year, date.month + 1, day);
    }
  }
}
