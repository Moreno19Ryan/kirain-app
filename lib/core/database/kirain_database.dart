import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_outbox_table.dart';
import 'local_transactions_table.dart';

part 'kirain_database.g.dart';

/// KIRAIN's local SQLite database (Drift/OFFLINE-001+002+003). Supabase
/// remains the authoritative server-side store per ADR-001/002 — this is a
/// durable local delivery buffer plus, since v3, a local display cache. Bump
/// [schemaVersion] and add a step to [migration] whenever a table changes
/// shape.
///
/// v2 (OFFLINE-002) added [LocalOutboxItems.lockedAt] for SyncWorker's
/// claim/lease mechanism.
/// v3 (OFFLINE-003) added [LocalTransactions], the local-first display table.
@DriftDatabase(tables: [LocalOutboxItems, LocalTransactions])
class KirainDatabase extends _$KirainDatabase {
  KirainDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'kirain'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(localOutboxItems, localOutboxItems.lockedAt);
      }
      if (from < 3) {
        await m.createTable(localTransactions);
      }
    },
  );
}

/// Long-lived across the app's session — a fresh [KirainDatabase] per screen
/// would open a new native SQLite connection every time. Overridden in tests
/// with an in-memory instance instead of the real on-disk file.
final kirainDatabaseProvider = Provider<KirainDatabase>((ref) {
  final db = KirainDatabase();
  ref.onDispose(db.close);
  return db;
});
