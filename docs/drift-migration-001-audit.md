# DRIFT-MIGRATION-001 — Migration Code Audit & Assumptions

> Written before implementing the migration tests, per Tech Lead instruction
> ("audit dulu, identifikasi schema historis, dokumentasikan asumsi, baru
> implementasi"). This is the same audit already performed once during the
> Sprint 1 Production Hardening report (`docs/sprint1-production-hardening-report.md`
> §2) — reproduced and extended here as the authoritative reference for the
> tests in `test/kirain_database_migration_test.dart`, so the test file can
> cite this doc instead of re-deriving the history inline.

## 1. Current migration code (audited fresh, `lib/core/database/kirain_database.dart`)

```dart
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
```

Two independent, additive steps, each gated on `from`, both potentially
firing in the same pass (a real v1 install hits both `if`s at once — there
is no code path that stops partway). Neither step alters or drops anything
that already exists.

## 2. Exact historical schema, verified against git history (not just doc comments)

### v1 — `LocalOutboxItems`, commits `3122229` + `e0a619e` (OFFLINE-001)

Both commits landed in `main` together, in the same PR — `main` has never
had a live `schemaVersion 1` other than this exact shape. (`3122229` alone,
in isolation, briefly had `amount` as a `RealColumn`; `e0a619e`, the very
next commit on the same branch, corrected it to `IntColumn` and added the
CHECK constraint before that branch was ever merged. Confirmed via `git show
3122229:...` / `git show e0a619e:...` directly, not inferred.)

Columns (`git show e0a619e:lib/core/database/local_outbox_table.dart`):
`id`, `userId`, `categoryId` (nullable), `goalId` (nullable), `amount`
(**int**), `note` (nullable), `transactionDate`, `createdAt`, `expenseType`
(nullable), `syncStatus` (text enum), `retryCount` (default 0),
`lastAttemptAt` (nullable), `errorMessage` (nullable). Primary key `id`.
CHECK: exactly one of `categoryId`/`goalId`. **No `lockedAt`.**

SQL column names confirmed from the current generated code
(`lib/core/database/kirain_database.g.dart`, since v1's columns are an
unchanged subset of v3's): `id`, `user_id`, `category_id`, `goal_id`,
`amount`, `note`, `transaction_date`, `created_at`, `expense_type`,
`sync_status`, `retry_count`, `last_attempt_at`, `error_message`.
`sync_status` is stored via `EnumNameConverter` — the literal enum case
name (`'pending'`/`'syncing'`/`'failed'`), confirmed from the generated
`$convertersyncStatus` field.

### v2 — commit `c3f0d91` (OFFLINE-002)

Identical to v1 plus one nullable `DateTimeColumn get lockedAt`
(`locked_at`). Nothing else changed.

### v3 — commit `5aae6bf` (OFFLINE-003)

`LocalOutboxItems` unchanged from v2. New table `LocalTransactions`
(`local_transactions`): `id`, `userId`, `categoryId` (nullable), `goalId`
(nullable), `amount` (int), `note` (nullable), `transactionDate`,
`createdAt`, `expenseType` (nullable). Same CHECK constraint shape as
`LocalOutboxItems`. No `syncStatus`/`retryCount`/etc — display-only table,
per its own doc comment.

## 3. Assumptions this test suite makes, stated explicitly

1. **`main`'s git history is the source of truth for "what did version N
   actually look like"**, not just the current file's doc comments (which
   could theoretically drift from reality without anyone noticing). Every
   column list above was read directly via `git show <commit>:<path>`, not
   copied from `kirain_database.dart`'s prose.
2. **A hand-reconstructed Drift `Table` definition, code-generated normally,
   produces byte-identical SQL to what the original historical code would
   have generated** — the fixtures in `test/support/historical_schema_v1.dart`
   and `historical_schema_v2.dart` are *not* copies of the original
   `local_outbox_table.dart` file at those commits (which would import from
   `lib/`, coupling the fixture to future changes there); they're
   independent re-declarations of the same column list, deliberately
   standing alone with their own copy of the sync-status enum. This is
   safe specifically because drift's SQL generation from a `Table`
   definition is deterministic and doesn't depend on anything outside that
   class — two structurally identical `Table` subclasses in different files
   produce the same `CREATE TABLE` statement.
3. **`PRAGMA user_version` is what drift uses to decide `onCreate` vs.
   `onUpgrade`**, and it's a property of the SQLite *file*, not of which
   Dart class wrote it — so a file first opened through
   `HistoricalKirainDatabaseV1` (which sets `user_version` to 1 after its
   own `onCreate` runs) and then reopened through the real `KirainDatabase`
   (`schemaVersion` 3) genuinely forces drift to run `onUpgrade(m, 1, 3)` —
   the actual production callback, unmodified. This is verified directly in
   this suite's first test (an explicit `PRAGMA user_version` check
   before/after), not just assumed from drift's documented behavior.
4. **A nullable column reading back as `null` after a migration is not, on
   its own, proof the column exists** — it's also exactly what many result
   readers do when a queried column is simply absent from the row (i.e.
   the `ADD COLUMN` never ran). This was caught empirically while writing
   these tests (see §4) and fixed by asserting on `PRAGMA table_info`
   directly, independent of drift's own read path, plus a genuine
   non-null write-then-read-back round trip.
5. **`schemaVersion` can only ever be fixed at 3 in the real
   `KirainDatabase`** — there is no production code path that "stops at
   v2". The "v1 → v2" test group therefore verifies the `if (from < 2)`
   step's effect as part of a full v1→v3 run (the only way that branch can
   ever actually execute), while the "v2 → v3" group *is* a genuinely
   isolated single-step run (starting from `from == 2`, the `if (from < 2)`
   branch structurally cannot fire). This is a property of the production
   code's shape, not a limitation accepted for convenience — see the test
   file's own top-of-file doc comment for the full reasoning.

## 4. What this audit + a real dry run caught before the tests were considered done

Per the explicit requirement that these tests must fail if the migration
logic is broken (not just pass by construction), each test was run once
against a **deliberately mutated** copy of the real `onUpgrade` (with the
`if (from < 2)` step removed, then separately with the `if (from < 3)` step
removed), confirmed to fail in both cases, then the file was restored via
`git checkout` and the suite re-confirmed green.

The first attempt at the `lockedAt`-existence test used only
`expect(row.lockedAt, isNull)` — this **did not fail** when the
`addColumn` step was removed, because a result row missing the
`locked_at` key entirely reads back the same as one where it's genuinely
`NULL`. Caught during this same verification pass (not shipped), and fixed
by adding a `PRAGMA table_info` check plus a real write-then-read-back
round trip (§3.4). Both mutation scenarios and the fix are recorded here as
the artifact of that verification, since the mutation itself was never
committed.
