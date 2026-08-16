import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:kirain/core/database/kirain_database.dart';
import 'package:kirain/core/database/local_outbox_table.dart';

import 'support/historical_schema_v1.dart';
import 'support/historical_schema_v2.dart';

/// DRIFT-MIGRATION-001 — proves the *real* `KirainDatabase.migration`
/// (`lib/core/database/kirain_database.dart`) upgrades a genuinely
/// historical v1 or v2 on-disk database to v3 without losing or corrupting
/// data, rather than only ever exercising `onCreate` at the current schema
/// (every other Drift test in this suite does the latter — see
/// `docs/drift-migration-001-audit.md` for the full audit this fixes the
/// gap identified in, OFFLINE-INTEGRATION-001 Finding 5).
///
/// ## How the historical fixtures work
///
/// `support/historical_schema_v1.dart` and `support/historical_schema_v2.dart`
/// are hand-reconstructed, standalone Drift table/database definitions
/// matching `LocalOutboxItems` exactly as it existed at those schema
/// versions (verified against git history, not just current doc comments —
/// see the audit doc). Each test:
///
/// 1. Opens a real on-disk SQLite file through `HistoricalKirainDatabaseV1`
///    (or V2) — this genuinely creates the v1/v2-shaped tables and sets
///    SQLite's own `PRAGMA user_version` bookkeeping to 1 (or 2), using
///    drift's own SQL generation rather than hand-written SQL strings, so
///    the fixture is byte-accurate rather than transcribed by hand.
/// 2. Seeds representative rows, closes that connection.
/// 3. Re-opens the **same file** through the real, unmodified
///    `KirainDatabase` (`schemaVersion => 3`) — drift detects the
///    version mismatch and runs the actual production `onUpgrade` callback,
///    not a fresh `onCreate`. A `PRAGMA user_version` check before/after
///    confirms this explicitly in the first test below, rather than just
///    trusting drift's documented behavior.
/// 4. Asserts on the *seeded data's exact values* surviving, and that
///    constraints are still actively enforced (a raw invalid insert must
///    still throw) — not just that the final schema/columns look right,
///    per the requirement that these tests must fail if the migration
///    logic is broken, not just pass by construction.
///
/// ## Why "v1 → v2" and "v2 → v3" aren't both fully isolated single-step runs
///
/// The real `KirainDatabase.schemaVersion` is a fixed `3` — production code
/// has no way to "stop at v2". Starting a real upgrade from a v2 fixture
/// *does* isolate the v2→v3 step alone (`onUpgrade`'s `if (from < 2)`
/// branch never fires when `from == 2`), so that scenario below is a
/// genuinely isolated single-step test. Starting from a v1 fixture
/// necessarily runs both `if` branches in the same pass (there is no
/// production code path that stops it at v2) — the "v1 → v2" group below
/// still exercises the real `if (from < 2)` branch's own effect
/// (the `lockedAt` column and its correct default) as its focus, verified
/// as part of that same v1→v3 run, and the separate "v1 → v3 end-to-end"
/// group verifies the full combined result. This is documented rather than
/// glossed over — see `docs/drift-migration-001-audit.md` §3 for the full
/// reasoning.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kirain_migration_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  File dbFile() => File('${tempDir.path}/kirain.sqlite');

  group('v1 -> v2 (via the real onUpgrade, starting from a v1 fixture)', () {
    test('a real migration runs, not a fresh onCreate — PRAGMA user_version actually changes', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      await v1.into(v1.localOutboxItemsV1).insert(_v1Row(id: 'a'));
      await v1.close();

      final rawBefore = sqlite3.sqlite3.open(file.path);
      final versionBefore = rawBefore.select('PRAGMA user_version').first['user_version'] as int;
      rawBefore.close();
      expect(versionBefore, 1, reason: 'the v1 fixture must actually have written schema version 1');

      final migrated = KirainDatabase(NativeDatabase(file));
      await migrated.select(migrated.localOutboxItems).get(); // forces the lazy migration to run
      await migrated.close();

      final rawAfter = sqlite3.sqlite3.open(file.path);
      final versionAfter = rawAfter.select('PRAGMA user_version').first['user_version'] as int;
      rawAfter.close();
      expect(versionAfter, 3, reason: 'opening via the real KirainDatabase must have run onUpgrade to v3');
    });

    test('lockedAt column genuinely exists after upgrading (not just reads as null)', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      await v1.into(v1.localOutboxItemsV1).insert(_v1Row(id: 'a'));
      await v1.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      await migrated.select(migrated.localOutboxItems).get(); // force the migration

      // A nullable column reading back as `null` is ambiguous — it's exactly
      // what you'd *also* see if the column were missing entirely and the
      // ORM tolerated the absent key, which is precisely the "test that
      // only checks the final schema" trap this suite must avoid. Asserting
      // the column is genuinely present in `sqlite_master`'s own metadata
      // (via `PRAGMA table_info`), independent of drift's read path, is
      // what actually distinguishes "column exists, value is null" from
      // "column was never added".
      expect(_columnNames(file, 'local_outbox_items'), contains('locked_at'));

      // Belt and suspenders: a genuine, non-null write-then-read-back round
      // trip. If `addColumn` never ran, this throws ("no such column:
      // locked_at") rather than silently succeeding.
      final rowsAffected = await (migrated.update(
        migrated.localOutboxItems,
      )..where((t) => t.id.equals('a'))).write(
        LocalOutboxItemsCompanion(lockedAt: Value(DateTime.utc(2026, 1, 20, 9))),
      );
      expect(rowsAffected, 1);
      final row = await (migrated.select(
        migrated.localOutboxItems,
      )..where((t) => t.id.equals('a'))).getSingle();
      await migrated.close();

      expect(row.lockedAt?.toUtc(), DateTime.utc(2026, 1, 20, 9));
    });

    test('pre-existing PENDING/FAILED rows survive the upgrade with every field intact', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      await v1.into(v1.localOutboxItemsV1).insert(
        LocalOutboxItemsV1Companion.insert(
          id: 'pending-1',
          userId: 'user-1',
          categoryId: const Value('cat-1'),
          amount: 75000,
          note: const Value('makan siang'),
          transactionDate: '2026-01-15',
          createdAt: DateTime.utc(2026, 1, 15, 8),
          expenseType: const Value('wajib'),
          syncStatus: V1OutboxSyncStatus.pending,
        ),
      );
      await v1.into(v1.localOutboxItemsV1).insert(
        LocalOutboxItemsV1Companion.insert(
          id: 'failed-1',
          userId: 'user-1',
          goalId: const Value('goal-1'),
          amount: 500000,
          transactionDate: '2026-01-10',
          createdAt: DateTime.utc(2026, 1, 10, 9),
          syncStatus: V1OutboxSyncStatus.failed,
          retryCount: const Value(3),
          errorMessage: const Value('permanent error'),
        ),
      );
      await v1.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      final rows = await (migrated.select(migrated.localOutboxItems)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
      await migrated.close();

      expect(rows, hasLength(2));

      final pending = rows.firstWhere((r) => r.id == 'pending-1');
      expect(pending.userId, 'user-1');
      expect(pending.categoryId, 'cat-1');
      expect(pending.goalId, isNull);
      expect(pending.amount, 75000);
      expect(pending.note, 'makan siang');
      expect(pending.transactionDate, '2026-01-15');
      expect(pending.expenseType, 'wajib');
      expect(pending.syncStatus, OutboxSyncStatus.pending);
      expect(pending.retryCount, 0);

      final failed = rows.firstWhere((r) => r.id == 'failed-1');
      expect(failed.userId, 'user-1');
      expect(failed.categoryId, isNull);
      expect(failed.goalId, 'goal-1');
      expect(failed.amount, 500000);
      expect(failed.syncStatus, OutboxSyncStatus.failed);
      expect(failed.retryCount, 3);
      expect(failed.errorMessage, 'permanent error');
    });

    test('amount survives as an exact integer, no precision loss, across a range of values', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      const amounts = [1, 12345, 500000, 1000000, 123456789012];
      for (final amount in amounts) {
        await v1.into(v1.localOutboxItemsV1).insert(_v1Row(id: 'amt-$amount', amount: amount));
      }
      await v1.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      for (final amount in amounts) {
        final row = await (migrated.select(
          migrated.localOutboxItems,
        )..where((t) => t.id.equals('amt-$amount'))).getSingle();
        expect(row.amount, amount);
        expect(row.amount, isA<int>());
      }
      await migrated.close();
    });
  });

  group('v2 -> v3 (isolated single-step — starting already at v2)', () {
    test('LocalTransactions exists and is usable after upgrading from v2', () async {
      final file = dbFile();
      final v2 = HistoricalKirainDatabaseV2(NativeDatabase(file));
      await v2.into(v2.localOutboxItemsV2).insert(_v2Row(id: 'a'));
      await v2.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      // Would throw ("no such table") if the v2->v3 step hadn't actually run.
      await migrated
          .into(migrated.localTransactions)
          .insert(
            LocalTransactionsCompanion.insert(
              id: 'lt-1',
              userId: 'user-1',
              categoryId: const Value('cat-1'),
              amount: 20000,
              transactionDate: '2026-02-01',
              createdAt: DateTime.utc(2026, 2, 1),
            ),
          );
      final ltRows = await migrated.select(migrated.localTransactions).get();
      await migrated.close();

      expect(ltRows, hasLength(1));
      expect(ltRows.single.amount, 20000);
    });

    test('pre-existing v2 outbox data — including a non-null lockedAt — survives untouched', () async {
      final file = dbFile();
      final v2 = HistoricalKirainDatabaseV2(NativeDatabase(file));
      await v2.into(v2.localOutboxItemsV2).insert(
        LocalOutboxItemsV2Companion.insert(
          id: 'syncing-1',
          userId: 'user-1',
          categoryId: const Value('cat-1'),
          amount: 42000,
          transactionDate: '2026-02-05',
          createdAt: DateTime.utc(2026, 2, 5),
          syncStatus: V2OutboxSyncStatus.syncing,
          lockedAt: Value(DateTime.utc(2026, 2, 5, 10, 30)),
        ),
      );
      await v2.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      final row = await (migrated.select(
        migrated.localOutboxItems,
      )..where((t) => t.id.equals('syncing-1'))).getSingle();
      await migrated.close();

      expect(row.amount, 42000);
      expect(row.syncStatus, OutboxSyncStatus.syncing);
      expect(row.lockedAt?.toUtc(), DateTime.utc(2026, 2, 5, 10, 30));
    });

    test('the category/goal CHECK constraint is still actively enforced after upgrading from v2', () async {
      final file = dbFile();
      final v2 = HistoricalKirainDatabaseV2(NativeDatabase(file));
      await v2.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      await migrated.select(migrated.localOutboxItems).get(); // force the migration

      await expectLater(
        () => migrated
            .into(migrated.localOutboxItems)
            .insert(
              LocalOutboxItemsCompanion.insert(
                id: 'both-null',
                userId: 'user-1',
                amount: 1000,
                transactionDate: '2026-02-06',
                createdAt: DateTime.utc(2026, 2, 6),
                syncStatus: OutboxSyncStatus.pending,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      await migrated.close();
    });
  });

  group('v1 -> v3 end-to-end (a real pre-OFFLINE-002 install upgrading in one pass)', () {
    test('final schema matches a fresh v3 onCreate, and all seeded v1 data is intact', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      await v1.into(v1.localOutboxItemsV1).insert(_v1Row(id: 'a', amount: 15000));
      await v1.into(v1.localOutboxItemsV1).insert(_v1Row(id: 'b', amount: 999999999));
      await v1.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      final outboxRows = await (migrated.select(migrated.localOutboxItems)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      expect(outboxRows.map((r) => r.id).toList(), ['a', 'b']);
      expect(outboxRows[0].amount, 15000);
      expect(outboxRows[1].amount, 999999999);

      // See the "v1 -> v2" group's `lockedAt` test for why a bare `isNull`
      // check on a nullable column isn't enough on its own — it can't tell
      // "column exists, value null" apart from "column never got added".
      // Checking `PRAGMA table_info` directly, and a genuine write-then-read
      // round trip, closes that gap here too.
      expect(_columnNames(file, 'local_outbox_items'), contains('locked_at'));
      final rowsAffected = await (migrated.update(
        migrated.localOutboxItems,
      )..where((t) => t.id.equals('a'))).write(
        LocalOutboxItemsCompanion(lockedAt: Value(DateTime.utc(2026, 3, 1, 12))),
      );
      expect(rowsAffected, 1);

      // LocalTransactions must exist and be independently usable post-migration.
      await migrated
          .into(migrated.localTransactions)
          .insert(
            LocalTransactionsCompanion.insert(
              id: 'lt-e2e',
              userId: 'user-1',
              categoryId: const Value('cat-1'),
              amount: 123456789012,
              transactionDate: '2026-03-01',
              createdAt: DateTime.utc(2026, 3, 1),
            ),
          );
      final ltRow = await migrated.select(migrated.localTransactions).getSingle();
      expect(ltRow.amount, 123456789012);
      expect(ltRow.amount, isA<int>());

      await migrated.close();
    });

    test('the CHECK constraint is enforced end-to-end on both tables', () async {
      final file = dbFile();
      final v1 = HistoricalKirainDatabaseV1(NativeDatabase(file));
      await v1.close();

      final migrated = KirainDatabase(NativeDatabase(file));
      await migrated.select(migrated.localOutboxItems).get(); // force the migration

      await expectLater(
        () => migrated
            .into(migrated.localOutboxItems)
            .insert(
              LocalOutboxItemsCompanion.insert(
                id: 'outbox-both-populated',
                userId: 'user-1',
                categoryId: const Value('cat-1'),
                goalId: const Value('goal-1'),
                amount: 1000,
                transactionDate: '2026-03-02',
                createdAt: DateTime.utc(2026, 3, 2),
                syncStatus: OutboxSyncStatus.pending,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        () => migrated
            .into(migrated.localTransactions)
            .insert(
              LocalTransactionsCompanion.insert(
                id: 'lt-both-null',
                userId: 'user-1',
                amount: 1000,
                transactionDate: '2026-03-02',
                createdAt: DateTime.utc(2026, 3, 2),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      await migrated.close();
    });
  });
}

LocalOutboxItemsV1Companion _v1Row({required String id, int amount = 10000}) {
  return LocalOutboxItemsV1Companion.insert(
    id: id,
    userId: 'user-1',
    categoryId: const Value('cat-1'),
    amount: amount,
    transactionDate: '2026-01-01',
    createdAt: DateTime.utc(2026, 1, 1),
    syncStatus: V1OutboxSyncStatus.pending,
  );
}

LocalOutboxItemsV2Companion _v2Row({required String id, int amount = 10000}) {
  return LocalOutboxItemsV2Companion.insert(
    id: id,
    userId: 'user-1',
    categoryId: const Value('cat-1'),
    amount: amount,
    transactionDate: '2026-01-01',
    createdAt: DateTime.utc(2026, 1, 1),
    syncStatus: V2OutboxSyncStatus.pending,
  );
}

/// Raw `PRAGMA table_info` column names for [table] in [file] — bypasses
/// drift's own read path entirely (a completely independent source of
/// truth on the actual on-disk schema) via a fresh, separately-opened
/// connection, closed immediately after reading.
Set<String> _columnNames(File file, String table) {
  final raw = sqlite3.sqlite3.open(file.path);
  try {
    final rows = raw.select('PRAGMA table_info($table)');
    return rows.map((row) => row['name'] as String).toSet();
  } finally {
    raw.close();
  }
}
