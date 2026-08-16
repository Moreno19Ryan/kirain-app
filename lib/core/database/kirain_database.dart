import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_outbox_table.dart';

part 'kirain_database.g.dart';

/// KIRAIN's local SQLite database (Drift/OFFLINE-001). Supabase remains the
/// authoritative server-side store per ADR-001 — this is a durable local
/// delivery buffer, currently holding just [LocalOutboxItems]. Schema
/// versioning starts at 1; bump [schemaVersion] and add a step to
/// [migration] whenever a table changes shape.
@DriftDatabase(tables: [LocalOutboxItems])
class KirainDatabase extends _$KirainDatabase {
  KirainDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'kirain'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) => m.createAll());
}

/// Long-lived across the app's session — a fresh [KirainDatabase] per screen
/// would open a new native SQLite connection every time. Overridden in tests
/// with an in-memory instance instead of the real on-disk file.
final kirainDatabaseProvider = Provider<KirainDatabase>((ref) {
  final db = KirainDatabase();
  ref.onDispose(db.close);
  return db;
});
