import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/kirain_database.dart';
import '../../../core/database/local_outbox_repository.dart';
import '../../../core/database/local_outbox_table.dart';
import '../../../core/utils/format.dart';
import '../../categories/data/category.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(Supabase.instance.client, ref.watch(localOutboxRepositoryProvider));
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
    this.pendingStatus,
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

  /// Null for a transaction fetched from Supabase (confirmed synced) — the
  /// steady state for the vast majority of history. Non-null for OFFLINE-003's
  /// local-first overlay: this transaction only exists on-device so far, and
  /// the value is its live `LocalOutboxItems.sync_status` at fetch time
  /// (pending/syncing/failed), used to drive the "belum tersinkron"/"Gagal
  /// disinkron" badge. See `TransactionRepository.fetchHistoryWithPending`.
  final OutboxSyncStatus? pendingStatus;

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

  /// Builds the optimistic-overlay item from a [LocalTransaction] row plus
  /// its live delivery status. No [categoryName]/[goalName] — a local row
  /// only ever stores the id (see LocalTransactions' own doc comment); the
  /// UI resolves the display name from the categories list it already
  /// watches, same as it does for every other row (see RekapScreen's
  /// `categoryById` lookup).
  factory TransactionHistoryItem.fromLocal(LocalTransaction row, {required OutboxSyncStatus status}) {
    return TransactionHistoryItem(
      id: row.id,
      amount: row.amount,
      categoryId: row.categoryId,
      goalId: row.goalId,
      transactionDate: DateTime.parse(row.transactionDate),
      note: row.note,
      expenseType: switch (row.expenseType) {
        'wajib' => ExpenseType.wajib,
        'keinginan' => ExpenseType.keinginan,
        _ => null,
      },
      pendingStatus: status,
    );
  }
}

class TransactionRepository {
  /// [currentUserId] is injectable (defaults to reading the live Supabase
  /// session) for the same reason `SyncWorker`/`LocalFirstTransactionService`
  /// do it: `SupabaseClient.auth.currentUser` can't be faked in a test
  /// without a real session, so [fetchHistoryWithPending]'s local-merge
  /// branch needs a seam here to exercise it without one.
  TransactionRepository(this._client, this._localOutbox, {String? Function()? currentUserId})
    : _currentUserId = currentUserId ?? (() => Supabase.instance.client.auth.currentUser?.id);

  final SupabaseClient _client;
  final LocalOutboxRepository _localOutbox;
  final String? Function() _currentUserId;

  /// [id] must be a UUID v4 generated once by the caller at transaction
  /// creation time (see core/utils/ids.dart's `newId()`) — not generated in
  /// here. Per ADR-001 (OFFLINE-001), the same id has to survive unchanged
  /// across every retry an offline-queue send might need, and a repository
  /// method that rolls its own id on every call can't guarantee that; only
  /// the caller that owns the transaction's identity from the moment it's
  /// created can.
  Future<void> addTransaction({
    required String id,
    required String categoryId,
    required num amount,
    String? note,
    ExpenseType? expenseType,
    DateTime? transactionDate,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('transactions').insert({
      'id': id,
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
  ///
  /// See [addTransaction]'s doc for why [id] is caller-supplied rather than
  /// generated in here.
  Future<void> addSavingsContribution({
    required String id,
    required String goalId,
    required num amount,
    String? note,
  }) {
    final userId = _client.auth.currentUser!.id;

    return _client.from('transactions').insert({
      'id': id,
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
  ///
  /// OFFLINE-INTEGRATION-001 Finding 3: checks both Supabase (confirmed
  /// history) and the local-first echo (not-yet-confirmed transactions) —
  /// see [hasLocalDuplicate] for exactly which local rows count and why.
  /// Supabase is checked first since it's the common case (both entries
  /// already synced) and short-circuits before touching local storage.
  Future<bool> hasPossibleDuplicate({
    required String categoryId,
    required num amount,
    required DateTime date,
  }) async {
    if (await hasSupabaseDuplicate(categoryId: categoryId, amount: amount, date: date)) {
      return true;
    }
    return hasLocalDuplicate(categoryId: categoryId, amount: amount, date: date);
  }

  /// The Supabase half of [hasPossibleDuplicate] — split into its own
  /// method (rather than inlined) so tests can stub the network side out,
  /// the same seam pattern [fetchHistory] already provides for
  /// [fetchHistoryWithPending]'s tests.
  Future<bool> hasSupabaseDuplicate({
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

  /// The local half of [hasPossibleDuplicate] — OFFLINE-003's local-first
  /// echo, [LocalTransactions]. No signed-in user just means no local rows
  /// to check (mirrors [fetchHistoryWithPending]'s same defensive
  /// fallback) rather than throwing.
  ///
  /// **Which local states count as a duplicate, and why:** a
  /// [LocalTransactions] row only exists between the moment a transaction
  /// is recorded locally and the moment [LocalOutboxRepository.deleteSynced]
  /// removes it — which happens exactly once Supabase has confirmed the
  /// write, atomically alongside its paired [LocalOutboxItems] row. That
  /// means a matching [LocalTransactions] row's mere *existence* is already
  /// sufficient proof "this hasn't been confirmed synced yet" — regardless
  /// of whether its outbox delivery status is currently pending, syncing,
  /// or failed:
  /// - **pending** / **syncing** — obviously not yet confirmed.
  /// - **failed** — also still counts: per OFFLINE-003's "Correction C"
  ///   (only [LocalOutboxRepository.deleteSynced] ever removes a
  ///   [LocalTransactions] row; [LocalOutboxRepository.markFailed] only
  ///   touches [LocalOutboxItems]), a FAILED item's local echo is still
  ///   sitting right here. Excluding it would mean a user whose first
  ///   entry failed to send gets zero warning on a genuine back-to-back
  ///   repeat — exactly the nudge this fix exists to restore.
  ///
  /// This is why the check queries [LocalTransactions] directly rather than
  /// also cross-referencing [LocalOutboxItems.syncStatus] the way
  /// [fetchHistoryWithPending] does: that extra lookup exists there only to
  /// pick *which* badge to render, and reading it separately opens a race
  /// window (a [LocalTransactions] row can outlive its already-deleted
  /// [LocalOutboxItems] pair by a query or two) that [fetchHistoryWithPending]
  /// has to defensively drop rows for. A plain existence check doesn't have
  /// that problem: whatever's true on-disk at the moment this query runs is
  /// exactly the fact this check needs.
  Future<bool> hasLocalDuplicate({
    required String categoryId,
    required num amount,
    required DateTime date,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return false;

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // [LocalOutboxRepository.localTransactionsInRange] already scopes to
    // [userId] at the SQL level — the same ownership-isolation discipline
    // every other local read path in this codebase uses (see
    // [fetchHistoryWithPending]) — so a match can never belong to a
    // different user.
    final localRows = await _localOutbox.localTransactionsInRange(userId: userId, start: dayStart, end: dayEnd);
    return localRows.any((row) => row.categoryId == categoryId && row.amount == amount);
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

  /// OFFLINE-003: [fetchHistory] plus an optimistic overlay of not-yet-synced
  /// local transactions, merged in. Per the approved design (PR #44 §4.1):
  ///
  /// - The overlay is only injected at `offset == 0` — pending items are
  ///   always freshly-created, so they conceptually belong at/near the top
  ///   of page one; injecting them on later pages would either duplicate
  ///   them or disturb the offset math for everything after. Any other
  ///   offset just delegates straight to [fetchHistory].
  /// - No signed-in user (shouldn't normally happen mid-session, but keeps
  ///   this safe to call defensively) also just delegates to [fetchHistory].
  /// - Merge is ID-keyed and deterministic: Supabase's page wins on overlap
  ///   (a local row whose sync already landed and shows up in the same
  ///   Supabase page is *not* double-shown), pending rows fill in the rest.
  ///   A local row whose [OutboxSyncStatus] can no longer be found (already
  ///   synced and cleaned up between the two reads, i.e. a race with
  ///   SyncWorker/deleteSynced) is silently dropped rather than shown as if
  ///   it were still pending.
  /// - Sort is deterministic — transaction date desc, pending rows before
  ///   synced ones on the same date, then id — rather than a full re-sort
  ///   by creation time. [TransactionHistoryItem] has no `createdAt` (the
  ///   Supabase-fetched side of the merge never selects it), and `List.sort`
  ///   isn't guaranteed stable, so this is an intentional, documented
  ///   simplification rather than a perfectly historical ordering.
  /// - Pending items are added on top of the page, not counted against
  ///   [limit]: they haven't earned a "slot" in Supabase's true ordering
  ///   yet, and there are only ever a handful in flight at once.
  Future<List<TransactionHistoryItem>> fetchHistoryWithPending({
    required int limit,
    required int offset,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchText,
  }) async {
    final synced = await fetchHistory(
      limit: limit,
      offset: offset,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      searchText: searchText,
    );

    if (offset != 0) return synced;

    final userId = _currentUserId();
    if (userId == null) return synced;

    final localRows = await _localOutbox.localTransactionsInRange(userId: userId, start: startDate, end: endDate);
    final filteredLocalRows = localRows.where((row) {
      if (categoryId != null && row.categoryId != categoryId) return false;
      if (searchText != null && searchText.isNotEmpty) {
        final note = row.note;
        if (note == null || !note.toLowerCase().contains(searchText.toLowerCase())) return false;
      }
      return true;
    });

    final statuses = await _localOutbox.syncStatusesForIds(filteredLocalRows.map((row) => row.id).toList());

    final merged = <String, TransactionHistoryItem>{for (final item in synced) item.id: item};
    for (final row in filteredLocalRows) {
      final status = statuses[row.id];
      if (status == null) continue;
      merged.putIfAbsent(row.id, () => TransactionHistoryItem.fromLocal(row, status: status));
    }

    final result = merged.values.toList()
      ..sort((a, b) {
        final dateCmp = b.transactionDate.compareTo(a.transactionDate);
        if (dateCmp != 0) return dateCmp;
        final aPending = a.pendingStatus != null;
        final bPending = b.pendingStatus != null;
        if (aPending != bPending) return aPending ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    return result;
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
