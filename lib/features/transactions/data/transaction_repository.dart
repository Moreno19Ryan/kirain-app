import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../categories/data/category.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(Supabase.instance.client);
});

/// Whether this account has ever recorded a single transaction — used to
/// gate the retroactive-entry nudge on Home. No persisted "seen" flag
/// needed: the moment the user adds any transaction, this naturally
/// flips to true and the nudge stops showing on its own.
final hasAnyTransactionsProvider = FutureProvider<bool>((ref) {
  return ref.watch(transactionRepositoryProvider).hasAnyTransactions();
});

class TransactionRow {
  const TransactionRow({this.categoryId, required this.amount, this.expenseType});

  /// Null for savings contributions (those link to a goal instead).
  final String? categoryId;
  final num amount;
  final ExpenseType? expenseType;

  factory TransactionRow.fromJson(Map<String, dynamic> json) {
    return TransactionRow(
      categoryId: json['category_id'] as String?,
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
    this.categoryId,
    this.categoryName,
    this.goalId,
    this.goalName,
    required this.transactionDate,
    this.note,
    this.expenseType,
  });

  final String id;
  final num amount;
  final String? categoryId;
  final String? categoryName;
  final String? goalId;
  final String? goalName;
  final DateTime transactionDate;
  final String? note;
  final ExpenseType? expenseType;

  bool get isSavingsContribution => goalId != null;

  /// Only expense categories ever get an [expenseType] written (see
  /// [TransactionRepository.addTransaction] / Catat's submit flow) — so a
  /// category-linked transaction with no expense type reliably means the
  /// category itself is an income one, without needing to cross-reference
  /// the categories list.
  bool get isIncome => categoryId != null && expenseType == null;

  String get displayName => categoryName ?? goalName ?? '-';

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] as Map<String, dynamic>?;
    final goal = json['savings_goals'] as Map<String, dynamic>?;

    return TransactionHistoryItem(
      id: json['id'] as String,
      amount: json['amount'] as num,
      categoryId: json['category_id'] as String?,
      categoryName: category?['name'] as String?,
      goalId: json['goal_id'] as String?,
      goalName: goal?['name'] as String?,
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
    DateTime? transactionDate,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('transactions').insert({
      // Client-generated, not left to the column's `gen_random_uuid()`
      // default — see core/utils/ids.dart for why (offline-retry
      // idempotency).
      'id': newId(),
      'user_id': userId,
      'category_id': categoryId,
      'goal_id': null,
      'amount': amount,
      'note': note,
      'expense_type': expenseType?.name,
      if (transactionDate != null) 'transaction_date': isoDate(transactionDate),
    });
  }

  /// A "Tabungan" transaction — money moving toward a savings goal. Doesn't
  /// count toward wajib/keinginan (no category, no expense_type), but shows
  /// up in Riwayat Transaksi so the overall financial picture stays honest.
  Future<void> addSavingsContribution({
    required String goalId,
    required num amount,
    String? note,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('transactions').insert({
      'id': newId(),
      'user_id': userId,
      'category_id': null,
      'goal_id': goalId,
      'amount': amount,
      'note': note,
      'expense_type': null,
    });
  }

  Future<bool> hasAnyTransactions() async {
    final rows = await _client.from('transactions').select('id').limit(1);
    return rows.isNotEmpty;
  }

  /// Soft duplicate check: same category, same amount, same day. Used to
  /// warn (not block) before saving a new transaction — per CLAUDE.md,
  /// duplicate detection should never stop the user from saving.
  Future<bool> hasPossibleDuplicate({
    required String categoryId,
    required num amount,
    required DateTime date,
  }) async {
    final rows = await _client
        .from('transactions')
        .select('id')
        .eq('category_id', categoryId)
        .eq('amount', amount)
        .eq('transaction_date', isoDate(date))
        .limit(1);
    return rows.isNotEmpty;
  }

  /// [end] is exclusive.
  Future<List<TransactionRow>> fetchInRange({required DateTime start, required DateTime end}) async {
    final rows = await _client
        .from('transactions')
        .select()
        .gte('transaction_date', isoDate(start))
        .lt('transaction_date', isoDate(end));
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
    final rows = await _filteredHistoryQuery(
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      searchText: searchText,
    ).order('transaction_date', ascending: false).order('created_at', ascending: false).range(offset, offset + limit - 1);

    return rows.map(TransactionHistoryItem.fromJson).toList();
  }

  /// Unpaginated, same filters as [fetchHistory] — for CSV export, not the
  /// scrolling list. Unlike the UI (which must lazy-load), a one-off export
  /// fetching everything that matches is fine; a personal finance app's
  /// history is small enough for a single round trip.
  Future<List<TransactionHistoryItem>> fetchForExport({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) async {
    final rows = await _filteredHistoryQuery(
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      searchText: searchText,
    ).order('transaction_date', ascending: false).order('created_at', ascending: false);

    return rows.map(TransactionHistoryItem.fromJson).toList();
  }

  PostgrestTransformBuilder<PostgrestList> _filteredHistoryQuery({
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) {
    var query = _client
        .from('transactions')
        .select(
          'id, amount, note, transaction_date, expense_type, category_id, goal_id, '
          'categories(name), savings_goals(name)',
        );

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (startDate != null) query = query.gte('transaction_date', isoDate(startDate));
    if (endDate != null) query = query.lt('transaction_date', isoDate(endDate));
    if (searchText != null && searchText.isNotEmpty) query = query.ilike('note', '%$searchText%');

    return query;
  }
}
