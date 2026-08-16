import 'package:drift/drift.dart';

/// The local, optimistic echo of a transaction the user just recorded
/// (OFFLINE-003) — display data only, nothing about delivery/sync mechanics
/// (that's [LocalOutboxItems]'s job). Written atomically alongside the
/// matching [LocalOutboxItems] row (same `id`) by
/// `LocalOutboxRepository.insertLocalFirstTransaction`, and deleted
/// atomically alongside it once the sync actually reaches Supabase
/// (`LocalOutboxRepository.deleteSynced`).
///
/// Deliberately a separate table rather than reusing [LocalOutboxItems] for
/// display: that table's purpose is sync bookkeeping (retry_count,
/// lockedAt, error_message), and reading it directly for UI would mix those
/// concerns. This table only ever holds rows that mirror a currently-PENDING/
/// SYNCING/FAILED outbox item — by construction, both rows always exist or
/// neither does (see the atomic insert/delete above), so a row here always
/// has a matching [LocalOutboxItems] row to check for the live sync-status
/// badge (never a denormalized status column on this table itself — see
/// LocalOutboxRepository.syncStatusesForIds).
class LocalTransactions extends Table {
  @override
  String get tableName => 'local_transactions';

  TextColumn get id => text()();

  TextColumn get userId => text()();

  /// Exactly one of [categoryId] / [goalId] is set — same invariant as
  /// [LocalOutboxItems], enforced the same two ways (OutboxDraft's
  /// constructor, backstopped by the CHECK constraint below).
  TextColumn get categoryId => text().nullable()();

  TextColumn get goalId => text().nullable()();

  /// Exact whole Rupiah — see [LocalOutboxItems.amount] for why int, not
  /// num/double.
  IntColumn get amount => integer()();

  TextColumn get note => text().nullable()();

  /// ISO date string ('yyyy-MM-dd'), matching [LocalOutboxItems.transactionDate].
  TextColumn get transactionDate => text()();

  DateTimeColumn get createdAt => dateTime()();

  /// 'wajib' / 'keinginan' / null — matches [LocalOutboxItems.expenseType].
  TextColumn get expenseType => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((category_id IS NOT NULL AND goal_id IS NULL) OR '
        '(category_id IS NULL AND goal_id IS NOT NULL))',
  ];
}
