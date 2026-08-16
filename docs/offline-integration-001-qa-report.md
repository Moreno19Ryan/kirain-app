# OFFLINE-INTEGRATION-001 — Pipeline QA Report

> Audit of the complete transaction pipeline on `main` as of merge commit `e62ea5c`
> (Catat → LocalTransactions + Outbox atomic write → Rekap optimistic overlay →
> Sync Worker → Supabase → cleanup), covering OFFLINE-001/002/003 combined.

## Status update — Tech Lead review round 1

Findings 1 and 2 are **fixed**, per explicit Tech Lead direction (approved as
an audit, changes requested before merge, scoped to exactly these two).
Findings 3–6 remain documented below as follow-ups/accepted limitations —
**not implemented in this PR**, per instruction. OFFLINE-004 has not been
started.

- **Finding 1 (sync-trigger vs save-status coupling) — FIXED.**
  `catat_screen.dart`'s `_doSubmit` now isolates `triggerSyncAfterOutboxInsertion`
  in its own `try/catch`, after the local-first write has already succeeded —
  a trigger failure can no longer fall through to the outer `catch` and get
  misreported as "gagal kesimpen". Regression test added to `widget_test.dart`
  (simulates the trigger's provider construction throwing synchronously,
  asserts the success state still renders, no error text appears, and the
  outbox contains exactly one row — proving no duplicate write). Verified
  failing without the fix, passing with it.
- **Finding 2 (Rekap pagination id-dedup) — FIXED.** `rekap_screen.dart`
  now tracks a `Set<String> _renderedIds` alongside `_items`; `_loadMore`
  only appends a fetched row if its id hasn't already been rendered,
  preserving fetch order and leaving `_syncedCount`/`_hasMore`'s pagination
  math untouched. Regression test added to `rekap_screen_test.dart`
  (scripts a page-0/page-1 fetch pair that deliberately re-returns an
  already-rendered id, simulating a pending item syncing mid-scroll and
  shifting Supabase's true offset ordering; asserts the shared id renders
  exactly once). Verified failing without the fix, passing with it.

## 0. Baseline

- `flutter analyze` — **0 issues** (unchanged after the fixes).
- `flutter test` — **195/195 passing** (193 + the 2 new regression tests
  above; all pre-existing tests still green, no regressions from the fixes).
- Reviewed files: `catat_screen.dart`, `local_first_transaction_service.dart`,
  `local_outbox_repository.dart`, `local_outbox_table.dart`,
  `local_transactions_table.dart`, `kirain_database.dart`, `sync_worker.dart`,
  `sync_error_classifier.dart`, `sync_backoff.dart`,
  `transaction_sync_service.dart`, `sync_lifecycle_gate.dart`,
  `transaction_repository.dart`, `rekap_screen.dart`, `dashboard_summary.dart`,
  `app_router.dart`, `app.dart`, `AndroidManifest.xml`, `pubspec.yaml`.

## 1. Findings

Ordered by severity. "Concrete blocker" per the Tech Lead's framing means:
reproducible, user-facing, and not already covered by an accepted scope
boundary. Only **Finding 1** meets that bar in my judgment; the rest are
lower-priority or informational. No fixes have been applied — proposals are
included only to make a go/no-go decision fast.

### Finding 1 — MEDIUM: a sync-trigger failure can be misreported as "save failed" — ✅ FIXED

**Where:** `lib/features/catat/catat_screen.dart`, `_doSubmit()`, lines ~160–182.

```dart
await ref.read(localFirstTransactionServiceProvider).recordTransaction(...); // (a)
triggerSyncAfterOutboxInsertion(ref);                                        // (b)
setState(() { _lastSaved = _SavedSummary(...); });                           // (c)
...
} catch (_) {
  setState(() { _errorMessage = 'Yah, gagal kesimpen. ...'; });
}
```

By the time `(b)` runs, the local-first write `(a)` has **already succeeded**
— the transaction is durably committed to `LocalTransactions` +
`LocalOutboxItems`. But `(b)` sits inside the same `try` block as `(a)` and
`(c)`. `triggerSyncAfterOutboxInsertion` itself is documented as
"fire-and-forget by design" (its own doc comment says exactly that), but the
call site here doesn't honor that: `ref.read(syncWorkerProvider)` inside it
runs *synchronously*, and if that provider's construction throws for any
reason (its default builder touches `Supabase.instance.client` — see
`transaction_sync_service.dart`), the exception propagates straight into this
`catch (_)` block. The user sees "gagal kesimpen" (save failed) for a
transaction that is, in fact, sitting safely in the local queue and will sync
normally. Worse, they may re-enter it, and since the soft duplicate check is
Supabase-only (Finding 3), a duplicate isn't guaranteed to be caught.

This is a narrow-probability trigger in production (Supabase is always
initialized by the time a signed-in user reaches Catat), but it's a real
structural coupling bug regardless of how rare the trigger itself fails: a
concern about *delivery* is currently able to overwrite the UI's signal about
*whether the save happened*, which are two different facts.

**Fix applied:** `triggerSyncAfterOutboxInsertion(ref)` is now wrapped in its
own `try { ... } catch (_) {}` right at the call site, after the local-first
write's `await` has already completed. A failure there can no longer reach
the outer `catch` that sets `_errorMessage`. **Regression test:**
`widget_test.dart` — *"catat form still shows success (not 'gagal kesimpen')
when the sync trigger fails after a successful local-first save..."* —
overrides `syncWorkerProvider` to throw synchronously (reproducing the exact
failure mode) and asserts (a) the success state still renders, (b) no
"gagal kesimpen" text appears, and (c) the outbox contains exactly one row
(no duplicate write). Confirmed this test fails on the pre-fix code and
passes on the fix.

### Finding 2 — MEDIUM: no id-dedup guard when appending Rekap pages, risking a duplicate row across pages — ✅ FIXED

**Where:** `lib/features/rekap/rekap_screen.dart`, `_loadMore()`,
`_items.addAll(page)`.

Mechanism: `_syncedCount` (the Supabase offset for the *next* page) only
counts rows already fetched from Supabase's true ordering; the pending
overlay injected at `offset == 0` sits on top of it, uncounted (correct, per
the approved design). But if a pending item **finishes syncing while the
user is still scrolling** — very plausible now, since Catat immediately
triggers a sync attempt after every local-first write — that item becomes a
genuinely new row in Supabase's true `ORDER BY transaction_date desc,
created_at desc` ordering, most likely landing at the very front (it's the
newest). That shifts every row after it one position later than what
`_syncedCount` still assumes. The next `_loadMore()` call (offset =
`_syncedCount`) then re-fetches a row that was already rendered on the
previous page, and `_items.addAll(page)` has no id-based guard — appending it
verbatim renders a duplicate list entry until the next full reset (pull to
top / filter change).

This class of bug (offset pagination shifting under concurrent writes) isn't
new to OFFLINE-003 in the abstract, but OFFLINE-003 makes it routine rather
than a rare theoretical case: submitting a transaction now reliably triggers
a same-session sync moments later, and Rekap is the screen most likely to be
open right after Catat.

**Fix applied:** `_RekapScreenState` now tracks a `Set<String> _renderedIds`
alongside `_items`, cleared together on `reset: true`. `_loadMore` appends a
fetched row only if `_renderedIds.add(item.id)` returns `true` (i.e. the id
wasn't already rendered) — fetch order is preserved (still appended in
the order the page returned them, just skipping repeats), and
`_syncedCount`/`_hasMore`'s pagination math is computed exactly as before,
unaffected by the dedup (which only gates what reaches the render list, not
the offset accounting). **Regression test:** `rekap_screen_test.dart` —
*"rekap screen never renders the same transaction id twice when a pending
item syncs mid-scroll..."* — scripts a page-0/page-1 fetch pair where page 1
deliberately re-returns an id from page 0 (the exact shape of the shift
described above), scrolls to trigger the second page load, and asserts the
shared id renders exactly once while the genuinely new id also renders.
Confirmed this test fails on the pre-fix code (finds the shared-id text
twice) and passes on the fix.

### Finding 3 — LOW/MEDIUM: soft duplicate check never looks at pending local rows

**Where:** `transaction_repository.dart` `hasPossibleDuplicate` (Supabase-only
query) as used from `catat_screen.dart`.

While offline, two back-to-back identical entries (same category/amount/day
— the exact "Tambah Lagi" flow CLAUDE.md's batch-entry feature encourages)
never trigger the soft duplicate warning, because the check only queries
already-confirmed Supabase rows and the first entry hasn't synced yet. This
existed in a narrower form before OFFLINE-003 too (a race measured in
milliseconds online), but going offline turns that race window into the
entire offline duration. Non-blocking by design either way (CLAUDE.md: soft
warning, never blocks), so this is a missed nudge, not a data-integrity
problem — no duplicate id, no corrupted state, just no heads-up.

**Proposed follow-up (not a same-PR fix, needs design input):** have the
duplicate check also consult `LocalOutboxRepository.localTransactionsInRange`
for the current user/day/category/amount before deciding "not a duplicate."

### Finding 4 — LOW: `recoverStaleLeases()` doesn't run on a login→login transition without an app background/foreground cycle

**Where:** `sync_lifecycle_gate.dart`, mounted once at the app root
(`app.dart`, above `GoRouter`) — its `initState` (cold start) and
`didChangeAppLifecycleState` (resume) are the only two triggers that call
`runStartupSync()` → `recoverStaleLeases()`. Sign-out/sign-in is a
route-level transition (redirected by `app_router.dart`'s `redirect`), not
an app lifecycle event, so it never runs `recoverStaleLeases()` on its own.

Narrow multi-user-per-device scenario: if user A's app crashed mid-sync
(leaving a `SYNCING` row with a now-abandoned lease) and, days later, the
same device switches straight from user A to user B **without ever
backgrounding the app in between**, user A's stale-locked row simply waits
for the next real resume/restart rather than being reclaimed immediately.
Self-heals on the next foreground event; not a correctness bug, and outside
this project's realistic usage pattern (personal single-owner devices,
CLAUDE.md §1), but worth having on record for the ownership-isolation manual
test below.

**No fix proposed** — flagging for awareness, not urgency.

### Finding 5 — LOW: the real `MigrationStrategy.onUpgrade` path has zero automated coverage

**Where:** `kirain_database.dart`, `schemaVersion` 1→2→3.

Every Drift-backed test (`local_outbox_repository_test.dart`,
`transaction_repository_test.dart`, `local_first_transaction_service_test.dart`,
widget tests) constructs a **fresh** `NativeDatabase.memory()`, which always
takes the `onCreate: (m) => m.createAll()` path at the current
`schemaVersion` — never a real upgrade of an existing on-disk v1 or v2
database via `onUpgrade`. The `addColumn`/`createTable` migration steps
themselves have never been exercised by CI.

Current risk is low: the app hasn't shipped, so there's no real installed
base on an older schema yet — every future install starts fresh at v3. But
this closes off the moment any future schema bump (v4+) needs to run against
a genuinely populated v3 device, which is exactly the scenario CLAUDE.md's
"jangan ulangi insiden migration GENSITI" guardrail exists for.

**Proposed follow-up (not urgent, no same-PR fix):** either adopt Drift's
schema-export/verification tooling (`drift_dev`'s schema snapshot + generated
migration tests), or at minimum hand-write one test that opens a v2-shaped
on-disk database (via a raw `CREATE TABLE`/pre-migration fixture) and asserts
the v3 `onUpgrade` step succeeds without data loss.

### Finding 6 — Observational, not a gap: head-of-line blocking within one sync batch

**Where:** `sync_worker.dart` `_processBatch()` — items in a batch of up to
`batchSize` (10) are processed **sequentially**, `await`ing each
`_processItem` fully before starting the next. `SyncBackoff` defaults to
`base: 2s, max: 60s`; with `maxAttemptsPerItem = 5`, a persistently-retryable
item can burn up to ~30s of cumulative backoff (2+4+8+16s, before the 5th and
final attempt) before the *next* 9 queued items in that same batch are even
attempted.

Not a correctness bug — nothing is lost, and the next trigger (or the next
loop iteration once this item resolves) picks up the rest — but it's a real
latency characteristic worth Tech Lead awareness, especially relevant to the
OPPO A3s field test if the network there is consistently flaky rather than
fully offline (the worst case for this specific behavior).

## 2. Verified — no gap found

- **User ownership isolation.** Every read/write path in the pipeline
  (`eligibleBatch`, `localTransactionsInRange`, `retryFailedItem`,
  `fetchHistoryWithPending`, `LocalFirstTransactionService.recordTransaction`)
  resolves the current user via a **live closure**, re-evaluated on every
  call — never cached at provider-construction time — and every local-DB
  query filters by `userId` at the SQL level, not as a post-fetch check. This
  holds correctly across a logout/login cycle within the same running
  process. Backed by the existing OFFLINE-002 "login/logout identity
  boundary" test group, still green.
- **Dashboard aggregate correctly left untouched (Correction B).**
  `dashboard_summary.dart` still reads exclusively from
  `TransactionRepository.fetchInRange` (Supabase-only) — confirmed
  unmodified. This is intentional, approved scope, not an oversight, but
  real-device testers should be told explicitly: Home's progress bars will
  **not** move for a transaction until it actually syncs. Worth calling out
  so it isn't mistaken for a bug during manual QA (see checklist item 1).
- **Atomicity.** `insertLocalFirstTransaction` and `deleteSynced` both wrap
  their paired writes/deletes in one `_db.transaction(...)` — confirmed by
  re-reading the code and by the existing "atomic — a failure on the second
  insert rolls back the first" test.
- **FAILED never deletes the local echo (Correction C).** Only `deleteSynced`
  touches `LocalTransactions`; `markFailed` only ever updates
  `LocalOutboxItems`. Confirmed by code and by the "FAILED does not delete
  the LocalTransactions row" test.
- **ADR-001 id reuse across retries.** `OutboxDraft`'s id is threaded
  unchanged from `newId()` at Catat submit time through to the Supabase
  upsert payload; `upsert(onConflict: 'id', ignoreDuplicates: true)` makes a
  genuine retry-after-response-lost scenario a silent no-op success rather
  than a duplicate row or an error.
- **Error classification precision.** The 23505/409 id-conflict narrowing
  (`_isIdConflict`, matching `Key ("id")=...` specifically) still correctly
  distinguishes "this is our own idempotent retry" from "this is a real
  constraint violation" — re-verified against the classifier's existing test
  matrix, all passing.
- **Pagination-safe overlay injection.** The pending/failed overlay is only
  ever merged in at `offset == 0`; every later page delegates straight to
  `fetchHistory`, confirmed by `fetchHistoryWithPending`'s own test group.
- **Scope discipline.** `LocalFirstTransactionService`/
  `localFirstTransactionServiceProvider` are referenced from exactly the
  files they should be (`transaction_repository.dart`, `catat_screen.dart`,
  `sync_lifecycle_gate.dart`, and their own definition) — Goals and Recurring
  still write directly through `TransactionRepository.addTransaction` /
  `addSavingsContribution`, confirmed no local-first leakage into either.
- **ANDROID-001.** `INTERNET` permission present in `AndroidManifest.xml`,
  covered by `android_manifest_test.dart`, still passing.

## 3. Manual real-device QA checklist

For execution on OPPO A3s (Android 8.1, lower bound) and at least one
higher-end device (Galaxy Z Flip5 per CLAUDE.md §9). Each item states what
"pass" looks like.

### A. Offline → online transition
1. Turn on Airplane Mode. Record 3 transactions via Catat (mix of Wajib/
   Keinginan, at least one via "Tambah Lagi"). **Pass:** each appears
   instantly in Catat's success state and in Rekap with a "Belum tersinkron"
   badge; no network spinner, no delay.
2. While still offline, pull up Rekap and scroll past the first page.
   **Pass:** no duplicate rows appear (see Finding 2 — also re-check this
   specific step once back online, per step 4).
3. Turn Airplane Mode off. **Pass:** within a few seconds (no manual action
   needed), all 3 "Belum tersinkron" badges disappear from Rekap as items
   sync; Supabase table shows all 3 rows with the same ids the app generated.
4. With Rekap already open and scrolled past page 1 from step 2, watch it
   through the reconnect in step 3. **Pass:** no duplicate row appears as
   items transition from pending to synced (this is the live version of
   Finding 2 — capture a screen recording if a duplicate does appear).

### B. Force-kill / restart recovery
5. Record a transaction offline, then force-kill the app (not just
   background) before reconnecting. Relaunch with Wi-Fi/data already on.
   **Pass:** the transaction is still in Rekap ("Belum tersinkron" on
   relaunch), and syncs shortly after relaunch without user action.
6. Record a transaction, immediately force-kill the app *while online but
   before the local write could plausibly have synced yet* (kill within
   ~1 second of tapping "Oke, Catat"). Relaunch. **Pass:** the transaction
   exists exactly once — either already synced, or still pending and syncs
   on relaunch. Explicitly check Supabase for a duplicate row (two rows with
   different ids but the same amount/category/date).
7. Repeat step 6 several times in a row (5+) to specifically stress the
   claim/lease + `recoverStaleLeases` path. **Pass:** no duplicates, no item
   permanently stuck in a state that never resolves (check the
   `local_outbox_items` local DB state isn't needed for this — Rekap's badge
   state is the user-visible proxy).

### C. Sync recovery / retry
8. Record a transaction while offline, then artificially keep the device
   offline for several minutes (longer than a few sync trigger cycles) before
   reconnecting. **Pass:** still syncs correctly once reconnected — no retry
   budget was silently exhausted while offline (retries only spend budget on
   actual attempts, and there should be none while genuinely offline —
   this is really a check that offline time doesn't count against the item).
9. Use a network conditioning tool (or a very weak signal area) to simulate a
   flaky connection — several failed attempts before eventual success.
   **Pass:** the badge stays "Belum tersinkron" through the retries, then
   clears once it lands; no "Gagal disinkron" appears unless something is
   genuinely permanent.

### D. Duplicate prevention
10. Online: record a transaction, then immediately record another with the
    identical category/amount/date. **Pass:** the soft "Transaksi mirip nih"
    dialog appears on the second one.
11. Offline: repeat step 10. **Pass (documented, not a bug):** no dialog
    appears (Finding 3) — confirm this is the case so it isn't mistakenly
    reported as broken, and confirm both entries still land as two separate,
    legitimate rows once synced (not deduplicated away).

### E. FAILED retry
12. Force a permanent failure — easiest reliable way is to revoke/corrupt
    the session so a write gets rejected by RLS, or coordinate with backend
    to temporarily reject a specific payload. Confirm the item shows "Gagal
    disinkron" in Rekap. Tap the badge. **Pass:** the item moves back to
    "Belum tersinkron" and a fresh sync attempt fires (confirm via Supabase
    once the underlying condition is cleared that it eventually lands).

### F. Logout/login ownership isolation
13. Sign in as User A, record 2 transactions offline (don't let them sync),
    then sign out immediately (without reconnecting). Sign in as User B on
    the same device. **Pass:** User B's Rekap shows none of User A's
    transactions — not even a momentary flash of stale UI before loading.
14. Sign back in as User A (still offline the whole time). **Pass:** the 2
    transactions from step 13 are still there, still pending, and sync
    normally once reconnected — they were never lost or attributed to User B.
15. Repeat steps 13–14 but with a force-kill between the sign-out and the
    next sign-in (i.e. don't background/foreground the app in between —
    this specifically probes Finding 4). **Pass:** still no data leaks
    across users; any stale lease recovery may lag until the next resume,
    but ownership itself must never be violated.

### G. Release APK networking
16. Build a **release** APK (not debug) and install it fresh. Repeat a
    representative subset of sections A–C on the release build specifically
    — release builds strip some debug-only network affordances and this is
    the actual artifact that ships. **Pass:** offline queueing, sync,
    and retry all work identically to the debug build; specifically confirm
    no `MissingPluginException`/network-permission-denied errors show up
    that debug builds wouldn't have surfaced (this is exactly the class of
    issue ANDROID-001 fixed for INTERNET — confirm no adjacent release-only
    permission gap exists).

### H. OPPO A3s "Mode Hemat Energi" verification
17. On the OPPO A3s specifically (the project's designated low-end test
    device, MediaTek Helio A/G-class chipset), open Rekap (glass bottom nav
    + glass filter sheet) and Home (hero card) with "Mode Hemat Energi"
    **off**. Watch for frame drops while scrolling Rekap's list and toggling
    the filter sheet. **Pass/fail is a judgment call** — note whether it
    feels smooth or visibly stutters.
18. Go to Kamu → toggle "Mode Hemat Energi" **on**
    (`energy_saver_repository.dart` / `kamu_screen.dart`). Repeat step 17.
    **Pass:** blur effects are replaced with solid+opacity surfaces per
    CLAUDE.md's spec, and scrolling/filtering feels noticeably smoother than
    step 17 — this is the concrete verification CLAUDE.md's Liquid Glass
    section says must happen on this exact device before being considered
    done, not assumed from testing on other hardware.
19. With Mode Hemat Energi in either state, run through section A's offline
    → online transition end to end on this device specifically. **Pass:**
    the sync pipeline behaves identically to the higher-end test device —
    this device is the lower bound for CPU/RAM, not for correctness.

## 4. Recommendation

Findings 1 and 2 are fixed (see the status update at the top of this
document) — both changes are minimal, local to their own file, don't touch
`fetchHistoryWithPending` or any sync/outbox logic, and are each backed by a
regression test confirmed to fail pre-fix and pass post-fix. `flutter
analyze` is clean and the full suite (195 tests) is green.

Findings 3–6 remain tracked, not implemented, no urgency:

- Finding 5 (migration test coverage) should close before any v4 schema
  change ships to a populated device — the only one with a real deadline,
  just not this one.
- Findings 3, 4, 6 — track for awareness; revisit if real-device QA
  (checklist items 10–11 for Finding 3, 13–15 for Finding 4) turns up
  anything the reasoning above didn't anticipate.

No further code changes proposed in this PR. Awaiting Tech Lead re-review.

Awaiting direction on which (if any) to implement.
