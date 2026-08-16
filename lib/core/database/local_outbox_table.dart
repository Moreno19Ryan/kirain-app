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

  /// Exact whole Rupiah — the smallest currency unit KIRAIN's domain model
  /// actually uses today (Catat's amount field is `decimal: false`; there's
  /// no sen/cents concept anywhere in the app). Stored as an integer, not
  /// REAL/double, so this durable local copy of a financial amount can't
  /// drift from what the user typed through binary floating-point rounding.
  /// Supabase's `numeric(14,2)` column stays authoritative once synced —
  /// this is a delivery buffer, not the ledger of record — but that's not a
  /// reason to be inexact here.
  IntColumn get amount => integer()();

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

  /// Backstop for the "exactly one of categoryId/goalId" invariant.
  /// [OutboxDraft]'s constructor already rejects a malformed draft before it
  /// can reach the DAO (see local_outbox_repository.dart), but a CHECK here
  /// means a malformed row can never be persisted even if some future code
  /// path builds a Companion directly instead of going through OutboxDraft.
  @override
  List<String> get customConstraints => [
    'CHECK ((category_id IS NOT NULL AND goal_id IS NULL) OR '
        '(category_id IS NULL AND goal_id IS NOT NULL))',
  ];
}
