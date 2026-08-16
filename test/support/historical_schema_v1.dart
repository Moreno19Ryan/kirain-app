import 'package:drift/drift.dart';

part 'historical_schema_v1.g.dart';

/// Hand-reconstructed replica of `LocalOutboxItems` exactly as it existed at
/// schema v1 (commits `3122229` + `e0a619e`, OFFLINE-001 — both landed in
/// `main` together in the same PR, so this is the only shape `schemaVersion
/// 1` has ever actually had in `main`'s history; see
/// `docs/drift-migration-001-audit.md` for the full git-history audit this
/// is transcribed from). Test-only: never imported by application code
/// (`lib/`), and deliberately does not import anything from
/// `lib/core/database/` — it exists purely to fixture a real v1-shaped
/// on-disk database for DRIFT-MIGRATION-001's migration tests to upgrade
/// *from*, using drift's own SQL generation (not hand-written SQL strings)
/// so the fixture schema is guaranteed byte-accurate rather than
/// hand-transcribed into raw SQL and possibly wrong in some detail (storage
/// affinity, NOT NULL placement, etc.) that wouldn't matter for a fresh
/// `onCreate` but would silently invalidate what an `onUpgrade` migration
/// test is actually supposed to prove.
class LocalOutboxItemsV1 extends Table {
  @override
  String get tableName => 'local_outbox_items';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get goalId => text().nullable()();

  /// Integer whole Rupiah, matching v1 as it actually reached `main` — see
  /// this file's top doc comment on why `3122229`'s transient `RealColumn`
  /// never counts as a real historical shape.
  IntColumn get amount => integer()();

  TextColumn get note => text().nullable()();
  TextColumn get transactionDate => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get expenseType => text().nullable()();
  TextColumn get syncStatus => textEnum<V1OutboxSyncStatus>()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// Present in `main` from `LocalOutboxItems`'s very first shipped shape
  /// (added in `e0a619e`, the same commit as the `amount` type fix, before
  /// either ever merged) — not a later addition.
  @override
  List<String> get customConstraints => [
    'CHECK ((category_id IS NOT NULL AND goal_id IS NULL) OR '
        '(category_id IS NULL AND goal_id IS NOT NULL))',
  ];
}

/// Deliberately a standalone copy of the real `OutboxSyncStatus`, not an
/// import of it — this file must stand entirely on its own as a historical
/// snapshot, unaffected by any future change to the real enum. Drift's
/// `textEnum()` stores the SQL value as the Dart enum's `.name`, so as long
/// as the case names match (`pending`/`syncing`/`failed`, unchanged since
/// v1), the on-disk representation is identical either way.
enum V1OutboxSyncStatus { pending, syncing, failed }

@DriftDatabase(tables: [LocalOutboxItemsV1])
class HistoricalKirainDatabaseV1 extends _$HistoricalKirainDatabaseV1 {
  HistoricalKirainDatabaseV1(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());
}
