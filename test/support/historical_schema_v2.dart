import 'package:drift/drift.dart';

part 'historical_schema_v2.g.dart';

/// Hand-reconstructed replica of `LocalOutboxItems` exactly as it existed at
/// schema v2 (commit `c3f0d91`, OFFLINE-002 — added `lockedAt` for
/// SyncWorker's claim/lease mechanism, the only change from v1). Same
/// standalone, test-only reasoning as `historical_schema_v1.dart`'s doc
/// comment — never imported by application code, no import from
/// `lib/core/database/`, exists purely to fixture a real v2-shaped on-disk
/// database for DRIFT-MIGRATION-001's migration tests to upgrade *from*.
class LocalOutboxItemsV2 extends Table {
  @override
  String get tableName => 'local_outbox_items';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get goalId => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get transactionDate => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get expenseType => text().nullable()();
  TextColumn get syncStatus => textEnum<V2OutboxSyncStatus>()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();

  /// The one column v2 added over v1 — SyncWorker's claim/lease lease
  /// timestamp, non-null only while a row is SYNCING.
  DateTimeColumn get lockedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((category_id IS NOT NULL AND goal_id IS NULL) OR '
        '(category_id IS NULL AND goal_id IS NOT NULL))',
  ];
}

/// See `historical_schema_v1.dart`'s `V1OutboxSyncStatus` doc comment for
/// why this is a standalone copy rather than a shared/imported enum.
enum V2OutboxSyncStatus { pending, syncing, failed }

@DriftDatabase(tables: [LocalOutboxItemsV2])
class HistoricalKirainDatabaseV2 extends _$HistoricalKirainDatabaseV2 {
  HistoricalKirainDatabaseV2(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());
}
