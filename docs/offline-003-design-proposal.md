# OFFLINE-003 — Local-First Transaction Integration: Design Proposal

> Status: **APPROVED WITH CONDITIONS (round 1) → revised below → awaiting final
> sign-off.** No OFFLINE-003 code has been written. This revision addresses the
> four required corrections from the round-1 review (§2, §4, §5/§7, §9 — each
> marked **[Round 2 correction]** at the affected section). Nothing will be
> implemented until final sign-off on this revision.
>
> Builds on: ADR-001 (client-generated UUID v4 + local outbox), ADR-002 (foreground
> sync engine — PR #41, #42, #43, all merged).

## Round 1 → Round 2 changelog

Round 1 approved decisions (unchanged, restated for the record):
1. Two tables: `LocalTransactions` (display) + `LocalOutboxItems` (delivery).
2. Both rows written in one atomic Drift transaction.
3. UUID generated exactly once in Catat, reused by `LocalTransactions`,
   `LocalOutboxItems`, and Supabase.
4. OFFLINE-003 covers Catat only — Savings Goal and Recurring stay direct-to-Supabase.
5. Offline edit/delete stays V2.
6. Double-tap protection is now in scope (was an open question in round 1).

Round 1 required corrections, addressed in this revision:
- **A.** Feed merge must be deterministically ID-deduplicated, not assumed
  non-overlapping — see §4, new invariant + three new test cases.
- **B.** Dashboard aggregate top-up is deferred out of OFFLINE-003 entirely — see
  §4, race-window reasoning, and the new follow-up placeholder.
- **C.** FAILED is explicitly a delivery state, not a deletion trigger — see §5/§7.
- **D.** Double-tap gets a synchronous submission guard, before any async work —
  see §9.

---

## 0. Scope

In scope: making **Catat** (`lib/features/catat/catat_screen.dart`) write locally
first, with the outbox draining it via the OFFLINE-002 sync engine, and making
Rekap/Home show pending items optimistically.

Out of scope (explicitly, see §10): Savings Goal contributions and Recurring
transaction confirmation stay on the existing direct-to-Supabase path for now.
Offline edit/delete remains V2. No Supabase schema changes.

---

## 1. How Catat becomes local-first

**Today:** `CatatScreen._submit()` calls `TransactionRepository.addTransaction(id:
newId(), ...)`, which does `_client.from('transactions').insert(...)` directly —
a network call the UI awaits before showing success. Offline, this just throws.

**Proposed:** Catat's submit handler stops calling `TransactionRepository`
directly. Instead:

1. Generate the UUID once: `final id = newId();` (unchanged from OFFLINE-001's
   pattern — the id is decided before anything is persisted anywhere).
2. Call a new `LocalFirstTransactionService.recordTransaction(id: id, ...)` that
   performs **one atomic local Drift write** (§2) and returns as soon as that
   local write lands — no network wait.
3. UI shows success immediately (same "Oke, Catat" confirmation as today) and
   the row appears in Rekap/Home right away via the optimistic read (§4),
   tagged "belum tersinkron" (§5).
4. `triggerSyncAfterOutboxInsertion(ref)` (already built in OFFLINE-002, currently
   unused) fires — fire-and-forget — to attempt an immediate sync if connectivity
   allows. Whether that succeeds or not, the user already saw success in step 3.

`TransactionRepository.addTransaction`/`.addSavingsContribution` (the direct
Supabase path) are **not removed** — they stay exactly as-is for the two call
sites this proposal keeps out of scope (§10).

---

## 2. Local transaction + outbox as one atomic Drift transaction

**Proposal: two local tables, one atomic write.**

- `LocalOutboxItems` (existing, OFFLINE-001/002) stays exactly what it is:
  **delivery mechanics only** — `sync_status`, `retry_count`, `locked_at`,
  `error_message`. Nothing about display.
- New table, `LocalTransactions`: **display data only** — `id`, `user_id`,
  `category_id`, `goal_id`, `amount`, `note`, `transaction_date`, `created_at`,
  `expense_type`. No sync-status column (see why in §5 — deliberately not
  denormalized).

Both rows share the same `id` (§3) and are written together:

```dart
await db.transaction(() async {
  await db.into(db.localTransactions).insert(LocalTransactionsCompanion.insert(
    id: id, userId: userId, /* ...display fields... */
  ));
  await db.into(db.localOutboxItems).insert(LocalOutboxItemsCompanion.insert(
    id: id, userId: userId, /* ...same fields, plus syncStatus: pending... */
  ));
});
```

`db.transaction()` wraps both inserts in one SQLite transaction. If the process
dies between them, SQLite rolls the whole thing back on next open — there is no
state where one row exists without the other. This is the direct answer to "in
one atomic Drift transaction": it's not two independent writes hoping to land
together, it's one SQL transaction.

**[Round 1 decision — approved as proposed.]** The alternative (reusing
`LocalOutboxItems` alone as the display source, no second table) was considered
and is not used: it would mean the UI reads a table whose primary purpose is
sync bookkeeping (mixing concerns), and a separate `LocalTransactions` row
gives a clean "does this id still have a local-only row?" existence check for
cleanup, rather than inferring display state from delivery state.

Symmetric cleanup: `SyncWorker`'s existing success path (`deleteSynced`) is
extended to delete the matching `LocalTransactions` row in the same
`db.transaction()`, for the same all-or-nothing reason.

**Schema impact:** adds `LocalTransactions` table, drift schema v3 (v2 was
OFFLINE-002's `lockedAt` column), migrated via `m.createAll()` / new
`onUpgrade` step — same pattern as the v1→v2 migration already shipped.

---

## 3. One UUID, reused everywhere

Unchanged principle from ADR-001, extended one layer up: `newId()` is called
**exactly once**, in Catat's submit handler, before any write happens. That
same `id` is passed explicitly into both the `LocalTransactions` insert and the
`LocalOutboxItems` insert (both already take `id` as a required parameter, not
something generated internally — this is the same discipline OFFLINE-001
already enforced on `TransactionRepository`). When `SyncWorker` eventually calls
`TransactionSyncService.upsertTransaction(item)`, `item.id` (from the outbox
row) is what's sent as `transactions.id` to Supabase. One id, three places,
generated once — never regenerated at any layer, matching ADR-002's existing
invariant.

---

## 4. Optimistic feed reading local transactions

Rekap/Home currently fetch straight from Supabase
(`TransactionRepository.fetchHistory`/`fetchInRange`). Proposed: a merge step,
not a full local-first read architecture (that's a much bigger change than
what's being asked here, and V1 doesn't need it — only the *not-yet-synced*
gap needs covering).

### 4.1 Feed merge — **[Round 2 correction A]**

Round 1 assumed the local/Supabase result sets never temporally overlap
(local row deleted before the synced row could appear in a fetch). Correct
per Tech Lead review: don't rely on that assumption holding under a real race
(e.g. `SyncWorker` marks a row synced and starts its delete, but a concurrent
Rekap fetch's Supabase call and local query interleave around it). The merge
must be **deterministically keyed by `transaction.id`**, not "shouldn't
overlap in practice."

**Invariant:** the same `transaction.id` must never produce two rendered rows
in the merged feed, regardless of ordering or timing between the Supabase
fetch and the local query.

**Algorithm** (`TransactionRepository.fetchHistoryWithPending(...)`):
1. Fetch the normal Supabase page/range → list `A`.
2. Query `LocalTransactions` for the same date range, current user (§9) → list `B`.
3. Build the merged result keyed by `id`: start from a `Map<String, Transaction>`
   populated from `A`, then add each item from `B` **only if its `id` is not
   already a key** — i.e. Supabase's copy wins on overlap, never the local one.
   Supabase's row is the confirmed, server-authoritative version (real
   `created_at`, guaranteed post-RLS-write state); the local row's only job is
   to fill the gap *before* that confirmation exists.
4. Sort the merged map's values by `transaction_date`/`created_at`, same
   ordering as today.

This makes de-duplication a property of the merge algorithm itself, not a
timing assumption about when `SyncWorker` happens to delete things.

**New tests for the race/overlap case** (added to the Definition of Done table
below too):
- Transaction present in `LocalTransactions` only (not yet synced) → renders once, "belum tersinkron".
- Transaction present in the Supabase result only (already synced, local row already cleaned up) → renders once, no badge.
- Transaction present in **both** (the race: synced server-side, but the local row hasn't been cleaned up yet by the time this fetch ran) → renders **exactly once**, using the Supabase copy, no badge — proving the invariant holds under overlap, not just in the clean-sequential case.

### 4.2 Dashboard aggregate top-up — **[Round 2 correction B, deferred]**

Round 1 proposed adding `LocalTransactions` amounts client-side on top of the
Supabase RPC's Zona Aman/Kirain totals. **Removed from OFFLINE-003 scope per
Tech Lead review**: a client-side top-up has its own race window — if a sync
completes *during* an aggregate fetch, the pending amount could get added on
top of a total that the RPC had already started including server-side (or
vice versa, dropped from both), producing a double-count or undercount that's
strictly worse than "stale for a moment."

**For OFFLINE-003:** dashboard aggregates keep using the existing Supabase RPC
as the sole source, unchanged. This means a just-recorded transaction shows up
in Rekap/Home's list immediately (§4.1) but does **not** move the Zona Aman/
Kirain progress bar until it actually syncs. That gap is an accepted, explicit
limitation of this PR — not silently glossed over.

**Follow-up placeholder:** local financial aggregate consistency (making the
progress bar reflect pending amounts safely) is deferred to a separate,
later design task — call it OFFLINE-004 — scoped and reviewed on its own once
OFFLINE-003 has shipped and the merge pattern above has been proven in
production.

---

## 5. Showing PENDING/FAILED transactions to the user

**[Round 2 correction C]** Stating explicitly, per Tech Lead review: **FAILED
is a delivery state on `LocalOutboxItems`, not a deletion trigger for
`LocalTransactions`.** Moving to FAILED changes only `LocalOutboxItems.
sync_status` (via the existing `markFailed`, OFFLINE-002) — it never touches
`LocalTransactions`. The user's local record of "I made this transaction"
persists, visibly, through PENDING → SYNCING → FAILED → (manual retry) →
PENDING → ... for as many cycles as it takes. The **only** thing that deletes
a `LocalTransactions` row is confirmed server sync (`deleteSynced`, §2/§8) —
never a failure, no matter how permanent the classifier says it is. A
transaction the user recorded does not disappear because the network or a
validation rule rejected it; it stays visible and retriable until it's
actually on the server.

Per CLAUDE.md's own existing spec ("indikator kecil 'belum tersinkron'"):

- A `LocalTransactions` row's badge is derived by checking whether a matching
  `LocalOutboxItems` row still exists, and if so, its `sync_status`:
  - Row exists, `pending`/`syncing` → small "belum tersinkron" chip (existing
    KIRAIN tone — informational, not alarming).
  - Row exists, `failed` → a distinct "Gagal disinkron, ketuk buat coba lagi"
    chip, tappable, wired to `SyncWorker.retryFailedItem(id)` (already built in
    OFFLINE-002, currently unused — this closes that PR's "known limitation #3").
  - Row doesn't exist → fully synced (and by §2/§4, the `LocalTransactions` row
    itself is gone too by then, so this case doesn't even need checking in
    practice; it's the steady state after cleanup).
- Deliberately **not** storing a denormalized status on `LocalTransactions`
  itself — a live lookup against `LocalOutboxItems` (by id, already indexed as
  its primary key) is one cheap query, and avoids a whole class of "the two
  tables disagree about status" bugs from keeping two copies of the same fact
  in sync by hand.

---

## 6. Offline behavior

No behavior change to Catat's success path between online and offline — that's
the point of local-first. The local atomic write (§2) doesn't touch the network
at all, so it succeeds identically either way. The only thing offline changes
is how long the "belum tersinkron" badge (§5) stays before flipping to synced —
governed entirely by OFFLINE-002's existing trigger set (connectivity change,
app resume, etc.), unchanged by this proposal.

---

## 7. Behavior when Supabase sync fails

Reuses OFFLINE-002's classifier outcomes as-is, mapped to the badge (§5):

- **Retryable** (network/429/5xx): stays "belum tersinkron" through the
  existing backoff loop; user unaffected functionally.
- **Permanent** (validation/RLS/FK/malformed payload): → FAILED → "Gagal
  disinkron" badge, user can tap to retry manually. Per §5's correction: this
  is a delivery-state change only — the `LocalTransactions` row is untouched
  and stays visible. This is new user-visible surface area — today a permanent
  failure is invisible (item just sits in the outbox forever). Making it
  visible is this proposal's answer to OFFLINE-002's "known limitation #3."
- **authRequired** (401): indistinguishable from "still syncing" to the user —
  same "belum tersinkron" badge, resolves automatically once the session's
  valid again, no special UI.

---

## 8. Crash recovery between local commit and sync

Three windows, each already covered by an existing guarantee — no new recovery
mechanism needed, just correct composition of what's already built:

- **Crash during the atomic write itself:** SQLite's transaction rollback (§2)
  means neither row exists after restart. From the user's view, nothing was
  saved — they'd re-enter it. Same guarantee SQLite already gives; not new.
- **Crash after the atomic commit, before sync starts:** `SyncWorker.
  runStartupSync()` (OFFLINE-002, already built) picks up the still-PENDING
  outbox row on next launch automatically. No special-casing needed.
- **Crash mid-sync (claimed, SYNCING, killed):** OFFLINE-002's stale-lease
  recovery (`recoverStaleLeases`, 5-minute default) reclaims it to PENDING on
  next startup — already built, already tested in PR #42.

---

## 9. Preventing duplicate local transactions

- `id` is the primary key on **both** `LocalTransactions` and
  `LocalOutboxItems` — a genuine duplicate write with the same id is
  structurally impossible (constraint violation), the same guarantee OFFLINE-001
  already established for the outbox alone.
- **[Round 2 correction D — now in scope, not optional.]** Real remaining risk:
  a double-tap on "Oke, Catat" before the button visually disables, which would
  call `newId()` twice and create two *different* legitimate-looking
  transactions — not a same-id duplicate, a UX double-submission bug. This
  exists today in the direct-to-Supabase flow too, but is being fixed as part
  of OFFLINE-003 rather than deferred.

  **Design:** a synchronous guard checked and set *before* any `await` in the
  submit handler — not `setState` (which schedules a rebuild; the disabled
  visual state can lag a frame behind, leaving a real re-entrancy window), and
  not a `Future`-based lock (same problem: the check-and-set has to happen on
  the same synchronous tick as the tap, before the event loop yields to
  anything else).

  ```dart
  bool _isSubmitting = false; // plain field, not part of build state

  Future<void> _onSubmitTap() async {
    if (_isSubmitting) return;   // synchronous check
    _isSubmitting = true;        // synchronous set — both on the same tick,
                                  // before the first `await` below
    try {
      final id = newId();
      await _localFirst.recordTransaction(id: id, /* ... */);
      // ...optimistic success UI, trigger sync...
    } finally {
      _isSubmitting = false;
    }
  }
  ```

  A second tap that lands before the first `await` yields sees `_isSubmitting
  == true` synchronously and returns immediately — no second `newId()`, no
  second write, regardless of how long the async work underneath takes or how
  fast the two taps arrive.
- The existing soft duplicate check (`hasPossibleDuplicate` — same category/
  amount/day, non-blocking warning) is unrelated and unaffected — it's a UX
  nudge against re-entering the same real-world expense, not an identity check.
- User-ownership boundary (§ Definition of Done): the `LocalTransactions` merge
  query (§4) filters by current session's `userId`, exactly like OFFLINE-002's
  `eligibleBatch` already does for the outbox — same guard, same reasoning,
  applied to the new read path.

---

## 10. Migration from the current direct-to-Supabase architecture

- **`TransactionRepository.addTransaction`/`.addSavingsContribution` are not
  changed or removed.** A new `LocalFirstTransactionService` is added
  alongside them. This is additive, not a breaking refactor — the two write
  paths stay independently testable and reviewable.
- **Catat only** switches to the new local-first path. This directly matches
  the proposal's title/§1 and is the case that actually motivates offline
  support (interactive, user-facing, the primary "quick-add while offline"
  scenario).
- **Savings Goal contributions** (`SavingsGoalRepository.contribute`) and
  **Recurring confirmation** (`RecurringTransactionRepository.confirmOccurrence`)
  are proposed to **stay on the direct path** for now. Both chain a *second*
  Supabase write right after the transaction insert (`_bumpAmount` for goals,
  `next_due_date` update for recurring) — making either local-first raises its
  own atomicity/optimistic-UX questions (does the goal's balance update
  optimistically too? what if that fails but the transaction succeeds?) that
  aren't covered by this design's 10 questions. Proposing these as a later,
  separately-scoped follow-up rather than silently expanding OFFLINE-003.
- **Read-path migration** (Rekap/Home switching to the merged fetch, §4) is the
  largest actual code-touching surface — it changes tested behavior
  (`dashboard_summary_test.dart`, `rekap_screen_test.dart`, the home dashboard
  tests in `widget_test.dart`), so those need new coverage for the merged view
  without breaking existing assertions about the synced-only case.
- No feature flag proposed — added complexity not asked for — but recommending
  this land behind an explicit manual QA gate before being called "done," the
  same pattern this project already uses for physical-device checks (e.g. the
  OPPO A3s Mode Hemat Energi verification from PR #40, the release-APK network
  check from PR #43).

---

## Definition of Done — test coverage plan

Mapped 1:1 to the Tech Lead's required list:

| Requirement | Where it's tested |
|---|---|
| Online transaction | `LocalFirstTransactionService` test: submit with a fake sync service that succeeds promptly → local row + outbox row both eventually cleared |
| Offline transaction | Same, fake sync service always throws `SocketException` → local write still succeeds, row visible with "belum tersinkron", nothing lost |
| Local transaction + outbox atomicity | Force a failure between the two inserts inside `db.transaction()` (test double throwing after the first insert) → assert **both** tables end up empty, not just one |
| Duplicate prevention | Insert the same `id` into `LocalTransactions`/`LocalOutboxItems` twice → primary-key violation, not a silent second row |
| Restart after offline save | Close + reopen the Drift db (same technique as OFFLINE-001's existing reopen test) → local transaction + outbox row both survive with the same id |
| Sync success | `SyncWorker` succeeds → both `LocalTransactions` and `LocalOutboxItems` rows deleted atomically |
| Sync retry | Transient failure → item stays PENDING, `LocalTransactions` row still shows "belum tersinkron", succeeds on a later attempt |
| Supabase response lost after server commit | Extends OFFLINE-002's existing `alreadySynced`/23505-on-id test — confirm the `LocalTransactions` row is also cleaned up in that path, not just the outbox row |
| User ownership boundary | Merge query filters `LocalTransactions` by current `userId` — test that user A's pending row never appears in user B's fetched feed, mirroring OFFLINE-002's `eligibleBatch` ownership tests |
| UI optimistic/local state | Widget test: Rekap/Home render "belum tersinkron"/"Gagal disinkron" based on outbox presence/status, and the badge disappears once the row is gone (synced) |
| **[Round 2 — §4.1 correction A]** Feed merge dedup, local-only | Item only in `LocalTransactions` → renders once, "belum tersinkron" |
| **[Round 2 — §4.1 correction A]** Feed merge dedup, Supabase-only | Item only in the Supabase result (already cleaned up locally) → renders once, no badge |
| **[Round 2 — §4.1 correction A]** Feed merge dedup, overlap/race | Item present in **both** simultaneously → renders **exactly once**, using the Supabase copy — the invariant test |
| **[Round 2 — §5/§7 correction C]** FAILED does not delete `LocalTransactions` | Force a permanent-error classification → `LocalOutboxItems.sync_status == failed`, `LocalTransactions` row still present and still fetchable |
| **[Round 2 — §9 correction D]** Double-tap guard | Two synchronous, back-to-back calls to the submit handler (no `await` between them in the test) → only one `LocalTransactions`/`LocalOutboxItems` row pair created |

---

## Final design summary

Catat switches from a synchronous direct-to-Supabase write to a local-first
write: one `newId()`, one atomic Drift transaction inserting matching
`LocalTransactions` (display) + `LocalOutboxItems` (delivery, existing table)
rows, immediate optimistic UI, fire-and-forget sync trigger. Rekap/Home read
through a new ID-keyed, Supabase-wins-on-overlap merge (§4.1) that provably
never double-renders a transaction. Dashboard aggregates are explicitly **not**
touched in this PR (§4.2, deferred to a future OFFLINE-004). FAILED is
delivery-only and never deletes the user's local record (§5/§7). A synchronous
(non-`setState`, non-`Future`-based) submission guard prevents double-tap
double-writes (§9). Savings Goal and Recurring stay on the existing direct
path; offline edit/delete stays V2; no Supabase schema changes.

## Affected files

**New:**
- `lib/core/database/local_transactions_table.dart` — the `LocalTransactions` Drift table.
- `lib/core/sync/local_first_transaction_service.dart` — `recordTransaction()`, the atomic write (§2).
- Drift schema v3 migration in `lib/core/database/kirain_database.dart` (adds `LocalTransactions`, same `onUpgrade` pattern as v1→v2).

**Modified:**
- `lib/features/catat/catat_screen.dart` — submit handler switches to `LocalFirstTransactionService`; adds the synchronous double-tap guard (§9).
- `lib/features/transactions/data/transaction_repository.dart` — adds `fetchHistoryWithPending(...)` (§4.1); existing `addTransaction`/`addSavingsContribution`/`fetchHistory`/`fetchInRange` untouched.
- `lib/core/sync/sync_worker.dart` — success path (`deleteSynced`) extended to also delete the matching `LocalTransactions` row, in the same atomic transaction (§2/§8). No change to the FAILED/retryable paths (§5/§7 correction C — deliberately not touching `LocalTransactions` there).
- `lib/features/rekap/rekap_screen.dart`, `lib/features/home/home_screen.dart` (or their data providers) — switch to the merged fetch; render the "belum tersinkron"/"Gagal disinkron" badges (§5).

**Not touched:** `lib/features/goals/data/savings_goal_repository.dart`, `lib/features/recurring/data/recurring_transaction_repository.dart` (§10), any Supabase migration under `supabase/migrations/`, `handle_new_user()`.

## Migration plan

1. Add the `LocalTransactions` table + schema v3 migration, `LocalFirstTransactionService`, and the extended `SyncWorker` cleanup — additive, no existing call site changes yet.
2. Switch Catat's submit handler to the new service (§1) + add the double-tap guard (§9). This is the one behavior-changing step for the write path.
3. Add `fetchHistoryWithPending(...)` and switch Rekap/Home's read providers to it (§4.1); add the sync-status badges (§5).
4. `TransactionRepository.addTransaction`/`.addSavingsContribution` remain in place, still used by Goals/Recurring — no removal, no deprecation in this PR.
5. Manual QA gate before calling this "done" (matching this project's existing pattern for physical-device checks): confirm on a real device that offline-created transactions appear immediately, sync once connectivity returns, and a forced permanent failure shows the FAILED badge and retries correctly on tap.

## Test plan

See the Definition of Done table above — 10 original cases plus the 5 new
Round 2 cases (feed-merge dedup ×3, FAILED-doesn't-delete, double-tap guard).

**Awaiting final Tech Lead sign-off. No implementation until then.**
