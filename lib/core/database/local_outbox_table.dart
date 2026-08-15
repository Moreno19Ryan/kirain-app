import 'package:drift/drift.dart';

/// Where a queued transaction stands in its delivery lifecycle. Mirrors the
/// state machine from OFFLINE-001's ADR: PENDING -> SYNCING -> (delete on
/// success) / back to PENDING on a retryable error / FAILED on a permanent
/// one. Only the persistence primitives (this table + the DAO's status
/// setters) are built here — the worker that actually drives these
/// transitions is a later task.
enum OutboxSyncStatus { pending, syncing, failed }

/// Local write-ahead outbox for offline transaction creation (OFFLINE-001).
///
/// One row per queued transaction, keyed by the transaction's own
/// client-generated UUID v4 (see core/utils/ids.dart) rather than a separate
/// local row id — that's what makes "the same UUID on every retry" (the
/// ADR-001 rule) structurally enforceable: there is no second identity for
/// the sync worker to accidentally regenerate.
///
/// Columns mirror `public.transactions` in Supabase (id, user_id,
/// category_id, amount, note, transaction_date, created_at, expense_type,
/// goal_id) plus the delivery bookkeeping fields (sync_status, retry_count,
/// last_attempt_at, error_message) needed to reconstruct and retry the
/// insert later. Kept as a typed relational schema rather than a single JSON
/// blob column so pending items can be queried/filtered/sorted directly in
/// SQL (e.g. "all PENDING items, oldest first") without deserializing every
/// row first — the fields are few and stable enough that a blob wouldn't
/// save meaningful complexity, and a typed schema also gets migration
/// tooling (see [KirainDatabase]'s `schemaVersion`) for free when a field is
/// added later.
class LocalOutboxItems extends Table {
  @override
  String get tableName => 'local_outbox_items';

  TextColumn get id => text()();

  TextColumn get userId => text()();

  /// Exactly one of [categoryId] / [goalId] is set, matching
  /// TransactionRepository's addTransaction (category) vs
  /// addSavingsContribution (goal) split.
  TextColumn get categoryId => text().nullable()();

  TextColumn get goalId => text().nullable()();

  /// Same units TransactionRepository already sends Supabase — full Rupiah,
  /// not cents. This table is a delivery buffer, not the ledger of record
  /// (Supabase's `numeric(14,2)` column stays authoritative once synced), so
  /// REAL is precise enough for the values involved here.
  RealColumn get amount => real()();

  TextColumn get note => text().nullable()();

  /// ISO date string ('yyyy-MM-dd'), matching core/utils/format.dart's
  /// isoDate() — transaction_date is a DATE server-side, not a timestamp, so
  /// storing it as plain text sidesteps DateTimeColumn's timezone-aware
  /// unix-timestamp semantics for a value that was never a timestamp.
  TextColumn get transactionDate => text()();

  /// Captured locally at enqueue time. Supabase's `created_at default now()`
  /// only applies once the row actually reaches the server — history
  /// ordering needs a real creation instant before that happens.
  DateTimeColumn get createdAt => dateTime()();

  /// 'wajib' / 'keinginan' / null — [ExpenseType.name], null for savings
  /// contributions and income rows. Same convention TransactionRepository's
  /// own inserts already use.
  TextColumn get expenseType => text().nullable()();

  TextColumn get syncStatus => textEnum<OutboxSyncStatus>()();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
