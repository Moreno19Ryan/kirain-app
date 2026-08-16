# Sprint 1 — Production Hardening: Verification Report

> Prepared per Tech Lead's Sprint 0 Exit decision (PR #46 merged, OFFLINE-001/
> 002/003 + OFFLINE-INTEGRATION-001 technically complete). **No application
> code, schema, sync logic, or UI has been touched to produce this report.**
> OFFLINE-004 has not been started.

## 1. Manual QA checklist — real device / release APK verification

The full 19-item checklist already exists in
`docs/offline-integration-001-qa-report.md` §3 (written during the
OFFLINE-INTEGRATION-001 audit) and hasn't changed — reproduced here mapped to
the eight areas Tech Lead named, so this report is self-contained. None of
these have been executed yet; this is the checklist as it stands, not
results.

| # | Area | Checklist items | What "pass" means |
|---|---|---|---|
| A | Offline → online transition | 1–4 | Transactions record instantly offline with a "Belum tersinkron" badge, sync automatically on reconnect, no duplicates appear while Rekap is open and scrolled across the reconnect |
| B | Force-kill / restart recovery | 5–7 | A transaction survives a force-kill at any point (before sync, mid-sync) and lands exactly once server-side, never zero or two |
| C | Sync recovery / retry | 8–9 | Offline time never burns retry budget; flaky-connection retries eventually land without a false "Gagal disinkron" |
| D | Duplicate prevention | 10–11 | Online: soft duplicate dialog fires on a same-day/category/amount repeat. Offline: it does **not** (documented limitation — Finding 3 below, not a bug) and both entries still land as legitimate separate rows |
| E | FAILED → manual retry | 12 | Tapping "Gagal disinkron" moves the item back to "Belum tersinkron" and a fresh sync attempt fires |
| F | Logout → login ownership isolation | 13–15 | User B never sees any of User A's transactions, not even a momentary flash; a force-kill between sign-out and the next sign-in (no background/foreground cycle) still leaks nothing, even though lease recovery may lag (Finding 4) |
| G | Release APK networking | 16 | A **release** build (not debug) reproduces the same offline/sync/retry behavior as debug — specifically confirms no release-only permission or plugin gap exists (this is exactly the class of issue ANDROID-001 fixed for `INTERNET`) |
| H | OPPO A3s Mode Hemat Energi | 17–19 | Liquid glass surfaces visibly smoother with Mode Hemat Energi on vs off on this specific low-end device, and the full sync pipeline (section A) behaves identically to higher-end hardware |

**Status: none of these 19 items have been executed against a real device or
a release build yet.** Everything verified so far in this engagement has
been `flutter analyze` / `flutter test` against the Dart/widget-test layer
only — real hardware, a real release APK, and real Supabase network
conditions are still unverified. This is the single largest gap between
"tests pass" and "production ready" (see §4).

## 2. Drift schema migration chain audit

Verified directly against git history (not just current-state doc comments),
covering exactly what shipped to `main` at each version — not intermediate
commits that only existed transiently on a feature branch before merge.

### v1 (OFFLINE-001, commit `3122229` + `e0a619e`, merged together)

- `onCreate: (m) => m.createAll()` only — no `onUpgrade` (nothing to migrate
  from yet).
- Single table, `LocalOutboxItems`: `id`, `userId`, `categoryId`, `goalId`,
  `amount` (**integer**, whole Rupiah), `note`, `transactionDate`,
  `createdAt`, `expenseType`, `syncStatus`, `retryCount`, `lastAttemptAt`,
  `errorMessage`. Primary key `id`. CHECK constraint: exactly one of
  `categoryId`/`goalId`.

  Note on `amount`'s type: the very first commit on the OFFLINE-001 branch
  (`3122229`) briefly had `amount` as a `RealColumn` (double); the very next
  commit on the *same* branch, addressing Tech Lead's round-1 review
  (`e0a619e`), corrected it to `IntColumn` before that branch was ever
  merged. Both commits landed in `main` together in the same merge — `main`
  has never, at any point, had a live `schemaVersion 1` with a REAL-typed
  `amount` column. **Verified, not a migration gap** — flagging only because
  a naive `git log -p` diff makes it look like a type change happened
  in-place without a version bump, which would be a real problem if it had
  reached `main` on its own.

### v1 → v2 (OFFLINE-002, commit `c3f0d91`)

- `onUpgrade`: `if (from < 2) await m.addColumn(localOutboxItems, localOutboxItems.lockedAt);`
- Adds exactly one nullable `DateTimeColumn` (`lockedAt`) to the existing
  table — SyncWorker's claim/lease lease timestamp. A single `ALTER TABLE
  ... ADD COLUMN`, nullable, no default-value backfill needed, no data
  transformation. Existing rows get `lockedAt = NULL`, which is exactly the
  correct "not currently claimed" state for anything that was mid-flight
  when the app updated.
- Existing table constraints (the CHECK) are untouched by an `ADD COLUMN` —
  SQLite doesn't rewrite the table for this operation.

### v2 → v3 (OFFLINE-003, commit `5aae6bf`)

- `onUpgrade`: `if (from < 3) await m.createTable(localTransactions);`
- Adds a brand new table (`LocalTransactions`) — no existing table is
  altered at all. The new table's own CHECK constraint (`categoryId`/`goalId`
  exclusivity) is created fresh, straight from the current Dart table
  definition (`createTable` always uses the live schema, not a hand-written
  step), so it's correct by construction.
- No pre-existing data touches this step — `LocalOutboxItems` rows from
  before OFFLINE-003 simply have no matching `LocalTransactions` row, which
  is the documented, harmless "outbox-only" case `deleteSynced`'s doc
  comment already accounts for.

### v1 → v3 (the only path a real pre-OFFLINE-003 install could actually take)

Both `onUpgrade` conditions run in the same pass (`if (from < 2)` then
`if (from < 3)`, both true when `from == 1`), in order: add `lockedAt`,
then create `LocalTransactions`. Order matters here only in that `addColumn`
must run before anything depends on `lockedAt` existing, which it does
(nothing in the `createTable` step touches `LocalOutboxItems` at all, so
there's no actual ordering hazard — noted for completeness, not because a
real risk was found).

**Conclusion: the migration logic itself, read line by line against its
actual history, is correct and minimal for both hops.** The gap identified
in OFFLINE-INTEGRATION-001 (Finding 5) stands: none of this has ever been
exercised by an automated test against a *real* upgrade — every existing
Drift test opens a fresh database at `schemaVersion 3` via `onCreate`, never
a v1 or v2 on-disk database going through `onUpgrade`. Current risk is low
only because the app has no real installed base yet (every future install
starts at v3) — see the risk assessment in §3.

## 3. Migration test strategy proposal

Two options, different effort/rigor tradeoffs. No implementation yet —
this is the proposal only.

### Option A — hand-rolled fixture test (low effort, closes the gap today)

Write a test that:
1. Opens a `NativeDatabase` (in-memory or temp file) and runs raw SQL
   matching the **exact historical v1 schema** recovered in §2 above (a
   literal `CREATE TABLE local_outbox_items (...)` with `amount INTEGER`,
   no `locked_at` column, and the same CHECK constraint) plus Drift's own
   internal schema-version bookkeeping table (`PRAGMA user_version` — Drift
   tracks the applied schema version this way, settable directly via
   `customStatement('PRAGMA user_version = 1')`).
2. Seeds it with representative rows (a PENDING item, a FAILED item with
   `retry_count`/`error_message` set).
3. Opens that same file/connection through the real `KirainDatabase` class
   (not a test double) — this forces Drift to detect `schemaVersion 3 != 1`
   and run the actual `onUpgrade` callback from production code, unmodified.
4. Asserts: migration completes without throwing; the seeded rows are still
   present and readable with their original data intact; `lockedAt` reads
   as `null` for pre-existing rows; a `LocalTransactions` row can now be
   inserted and read back; `PRAGMA user_version` is now `3`.
5. Repeat starting from a v2-shaped fixture (has `locked_at`, no
   `local_transactions`) to cover the v2→v3 hop in isolation too.

Costs: a small amount of hand-maintained raw SQL per historical version
(already fully specified in §2, so no re-derivation needed), no new
dependencies, runs in the existing `flutter test` suite immediately.
Downside: every future version bump needs a new hand-written fixture,
which is easy to get subtly wrong or let drift from the real historical
schema over time without tooling enforcing it.

### Option B — Drift's official schema-verification tooling (moderate effort, more durable)

Adopt `drift_dev`'s schema export/verification workflow: `dart run
drift_dev schema dump` exports each version's schema as JSON into a
`drift_schemas/` folder (checked into the repo, one snapshot per
version going forward); a generated `SchemaVerifier` then builds a
database at an old exported version and runs the real `onUpgrade`
against it, asserting the resulting schema matches the current live
one column-for-column.

Costs: initial tooling setup (a `build.yaml` entry, a one-time export
step, a small amount of generated test-support code), and a habit change
— every future schema bump needs its own `schema dump` run before that
PR merges. Benefit: the source of truth for "what did version N actually
look like" becomes a real exported snapshot rather than hand-transcribed
SQL, and it scales cleanly past v4, v5, etc. without repeating the
transcription work Option A requires each time.

### Recommendation

**Option A now, Option B adopted starting at the v3→v4 transition.**
Option A closes today's specific gap (v1→v2→v3, fully specified in §2
already) cheaply and immediately. Standing up Option B's tooling has more
value once there's an actual *next* migration to protect — retrofitting it
for versions that are already fully characterized (as v1–v3 now are, via
this report) doesn't buy much beyond what Option A already gives us, but
starting v4 without schema-snapshot tooling would repeat the same gap this
report exists to close.

Not implementing either without Tech Lead sign-off, per instruction.

## 4. Production-readiness gaps

Ordered by how much they block an actual release, not by when they were
found.

1. **No CI pipeline runs `flutter analyze`/`flutter test`.** The only
   GitHub Actions workflow in the repo (`.github/workflows/supabase-migrate-prod.yml`)
   applies Supabase migrations to production on push to `main` — appropriate
   and intentional per the GENSITI guardrail, but there is **no workflow at
   all** that runs the Flutter analyzer or test suite on PRs or pushes.
   Every green result this entire engagement (195/195 tests, 0 analyze
   issues, every PR) has been verified by me locally, not enforced by
   GitHub. A future change — from me, from Reno directly, or from anyone
   else — could silently break tests or introduce analyzer warnings with
   nothing blocking merge. This is the highest-leverage, lowest-cost fix
   available for Sprint 1: a single `flutter analyze && flutter test`
   workflow gated on PRs to `main`.
2. **Zero real-device/release-APK verification performed.** §1's 19-item
   checklist is fully specified but entirely unexecuted. This is the actual
   gate CLAUDE.md's own testing plan (§9) already calls for before
   considering OFFLINE-00x "done" in a shipping sense, not just
   "done" in a test-suite sense.
3. **Migration `onUpgrade` path untested by automation** — §2/§3 above.
   Low urgency today (no real installed base yet on an old schema), but
   should close before v4 ships to a populated device.
4. **OFFLINE-INTEGRATION-001 Findings 3, 4, 6 remain open** (tracked, not
   urgent, not re-litigated here — see that report for full detail):
   Finding 3 (soft duplicate check blind to local pending rows while
   offline), Finding 4 (stale-lease recovery doesn't run on a bare
   logout→login without an app background/foreground cycle), Finding 6
   (sequential batch processing can head-of-line-block a sync pass by
   ~30s worst case on one flaky item).
5. **Firebase Crashlytics not wired up yet.** CLAUDE.md §3 requires it
   ("Crash monitoring: Firebase Crashlytics") and no reference to it exists
   anywhere in `lib/`, `pubspec.yaml`, or the Android project. Flagging
   because it's squarely a "production hardening" item, but it's a
   separate workstream from the sync pipeline this report otherwise covers
   — not scoped/sized here.
6. **No automated migration-safety CI gate**, separate from item 1 above —
   even once Option A/B from §3 exists, nothing currently would stop a
   future schema change from merging without its migration test passing,
   absent the CI pipeline in item 1 that would run it.

## 5. Migration-risk assessment

- **Current risk: low.** No real users have installed the app yet (per
  CLAUDE.md, this is pre-launch); every future first install starts fresh
  at `schemaVersion 3` via `onCreate`, never touching `onUpgrade` at all.
  The v1→v2→v3 `onUpgrade` path, while untested by automation, has been
  manually verified line-by-line in §2 against its actual git history and
  is minimal and correct (one additive nullable column, one additive
  table, no data transformation, no destructive operation anywhere in the
  chain).
- **Risk escalates specifically at the moment of first public/beta
  release.** From that point on, every future schema change becomes a real
  migration against real installed devices with real local queues
  (potentially mid-sync), and CLAUDE.md's own guardrail — "jangan ulangi
  insiden migration GENSITI" — exists precisely for this transition. The
  migration test strategy in §3 should land *before* that first release,
  not after.
- **No risk identified in the migration logic itself** — this audit did
  not find an incorrect, destructive, or data-losing step anywhere in the
  current v1→v2→v3 chain. The risk here is entirely about *lacking a
  safety net* for the next change, not about anything currently broken.

## 6. Recommended Sprint 1 task order

1. **CI pipeline** (`flutter analyze` + `flutter test` on every PR to
   `main`) — smallest effort, highest leverage, protects every subsequent
   Sprint 1 task from silently regressing.
2. **Migration test strategy, Option A** (§3) — closes the one identified
   automated-coverage gap in the pipeline just shipped, cheap given §2
   already fully specifies the historical fixtures needed.
3. **Real-device / release-APK manual QA pass** (§1's 19 items) — the
   actual gate before calling OFFLINE-00x production-ready in a shipping
   sense, not just a test-suite sense. Needs the OPPO A3s and at least one
   higher-end device per CLAUDE.md §9.
4. **Findings 3/4/6 from OFFLINE-INTEGRATION-001** — revisit priority after
   the manual QA pass in case real-device testing surfaces something the
   original reasoning didn't anticipate (checklist items 10–11 for Finding
   3, 13–15 for Finding 4).
5. **Crashlytics wiring** — separate workstream, sequence after the above
   since it doesn't block or depend on any of it, but is a real pre-launch
   requirement per CLAUDE.md §3.
6. **Option B migration tooling** — adopt starting at the v3→v4 boundary,
   i.e. whenever OFFLINE-004 (or any other schema-touching work) is
   actually greenlit, not before.

Awaiting Tech Lead approval before implementing any of the above.
