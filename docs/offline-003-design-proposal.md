# OFFLINE-003 — Local-First Transaction Integration: Design Proposal

> Status: **PROPOSAL — NOT APPROVED, NOT IMPLEMENTED.** No OFFLINE-003 code has been
> written. This document exists to be reviewed and approved by the Tech Lead before
> any implementation begins, per Sprint 0 process.
>
> Builds on: ADR-001 (client-generated UUID v4 + local outbox), ADR-002 (foreground
> sync engine — PR #41, #42, #43, all merged).

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

**Alternative considered and rejected:** reuse `LocalOutboxItems` alone as the
display source (no second table), since it already has every display field.
Rejected because it would mean the UI reads a table whose primary purpose is
sync bookkeeping (mixing concerns), and because keeping a `LocalTransactions`
row until sync completes gives a clean "does this id still have a local-only
row?" existence check for `SyncWorker` cleanup, rather than needing to infer
display state from delivery state. Flagging this as a real fork — happy to
revisit if Tech Lead prefers the single-table version.

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

- New method, e.g. `TransactionRepository.fetchHistoryWithPending(...)`: fetches
  the normal Supabase page/range, **and** queries `LocalTransactions` for rows
  in the same date range belonging to the current user (§9), and merges them —
  pending rows sorted in alongside synced ones by `transaction_date`/`created_at`,
  same as today's ordering.
- De-duplication is structural, not best-effort: a `LocalTransactions` row is
  deleted (§2) in the same atomic step that deletes its `LocalOutboxItems` row
  on sync success, so by the time a synced transaction would start appearing in
  a fresh Supabase fetch, its local echo is already gone. There's no window
  where both a local and a server copy of the same id are live long enough to
  double-render (SyncWorker's delete happens before that HTTP response is even
  returned to its caller).
- Dashboard aggregates (Zona Aman/Kirain progress, "Progress Cukup") are
  Supabase RPC-calculated today. This proposal adds a client-side top-up: after
  fetching the RPC's totals, add in `LocalTransactions` amounts for the current
  budget cycle before rendering the progress bar. **Flagging this as the
  trickiest part of the design** — it needs the exact same cycle-boundary logic
  the RPC uses (`BudgetCycle.current`, already in `lib/core/utils`), and it's
  the one place a bug would show wrong numbers rather than just a stale badge.
  Worth a focused review pass on its own once this proposal is approved.

---

## 5. Showing PENDING/FAILED transactions to the user

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
  disinkron" badge, user can tap to retry manually. This is new user-visible
  surface area — today a permanent failure is invisible (item just sits in the
  outbox forever). Making it visible is this proposal's answer to OFFLINE-002's
  "known limitation #3."
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
- Real remaining risk: a double-tap on "Oke, Catat" before the button disables,
  which would call `newId()` twice and create two *different* legitimate-looking
  transactions — not a same-id duplicate, a UX double-submission bug. This
  exists today in the direct-to-Supabase flow too; not new to this proposal.
  Recommended fix (small, separable): disable the submit button synchronously
  on tap, before any async work starts. Happy to fold into OFFLINE-003 or keep
  as its own tiny follow-up — Tech Lead's call.
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

---

## Open questions for Tech Lead

1. **Two-table vs. one-table** (§2): confirm `LocalTransactions` +
   `LocalOutboxItems` as separate tables, or prefer reusing `LocalOutboxItems`
   alone for display?
2. **Dashboard aggregate top-up** (§4): confirm client-side merge of pending
   local amounts into the RPC-calculated Zona Aman/Kirain totals is the right
   call, given it's the part most likely to show a wrong number if buggy.
3. **Goals/Recurring scope** (§10): confirm staying out of scope for OFFLINE-003
   is correct, or should either be pulled in now?
4. **Double-tap submit guard** (§9): fold into this PR, or a separate tiny
   follow-up?

No implementation will begin until this is reviewed and approved.
