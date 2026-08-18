# OFFLINE-INTEGRATION-001 — Findings 3, 4, 6 Review

> Tech Lead direction: re-open Findings 3, 4, and 6 from
> `docs/offline-integration-001-qa-report.md` §1, one at a time, each covering
> root cause / impact / remediation options / recommendation / test strategy /
> schema-API-UI impact / scope estimate. **This is a review for Tech Lead
> approval — no fix is implemented in this document or its PR.**
> `flutter analyze`/`flutter test` were not re-run for this pass since no code
> changed; the last known-green baseline is PR #50 (`aa1c0fc`/`63d7432`, 204/204
> passing, merged as `ee4860a`).
>
> **Real-device QA remains environment-blocked, not completed** (per
> `docs/sprint-003-qa-execution-report.md`) — nothing in this review assumes
> or claims that status has changed. Where a finding's original write-up
> pointed at a manual QA checklist item as the way to confirm behavior in
> practice, that item is still unexecuted and is called out as such below,
> not treated as evidence either for or against the finding.
>
> Findings 1 and 2 are already fixed (OFFLINE-INTEGRATION-001, merged).
> Finding 5 (migration test coverage) was already closed by DRIFT-MIGRATION-001
> (PR #49, merged) — not revisited here, out of this task's scope.

---

## Finding 3 — Soft duplicate check never looks at pending local rows

**Original severity:** LOW/MEDIUM. **Where:**
`lib/features/transactions/data/transaction_repository.dart`,
`hasPossibleDuplicate()`, called from
`lib/features/catat/catat_screen.dart` `_doSubmit()` (lines ~138–145).

### 1. Root cause

`hasPossibleDuplicate()` queries only Supabase's `transactions` table:

```dart
Future<bool> hasPossibleDuplicate({
  required String categoryId,
  required num amount,
  required DateTime date,
}) async {
  final rows = await _client
      .from('transactions')
      .select('id')
      .eq('category_id', categoryId)
      .eq('amount', amount)
      .eq('transaction_date', isoDate(date))
      .limit(1);
  return rows.isNotEmpty;
}
```

It never consults `LocalOutboxRepository.localTransactionsInRange` — the
same local read path `fetchHistoryWithPending` already uses for its
optimistic overlay, and which `TransactionRepository` already holds a
reference to (`_localOutbox`, constructor-injected). Two failure modes stem
from this single gap, both root-caused the same way:

- **Fully offline:** the Supabase call throws (no network). Catat's call
  site wraps it in its own `try/catch` and treats any failure as "not a
  duplicate" by design (a soft check must never block on network trouble) —
  so an offline duplicate is silently waved through, not because the logic
  decided it wasn't a duplicate, but because the only place it looks can't
  be reached at all.
- **Online, race window:** the first entry's local-first write has landed
  in `LocalTransactions`/`LocalOutboxItems` but hasn't synced to Supabase
  yet (typically milliseconds, but real). A second identical entry's check
  queries Supabase, finds nothing, and the warning never fires — even
  though the true duplicate is sitting one table away, locally, the entire
  time.

Both cases are the same underlying gap: the check has exactly one source of
truth (Supabase) when the app now has two (Supabase + local pending rows),
and OFFLINE-003 made the second one routine rather than a millisecond-scale
edge case.

### 2. Impact to KIRAIN V1

Low. Duplicate detection is explicitly **soft/non-blocking** per CLAUDE.md
— this gap never corrupts data, never blocks a save, never produces a
duplicate *id* or an inconsistent state. The two entries land as two
legitimate, separate rows either way (already verified — QA checklist item
11 documents this as the accepted behavior, not a bug).

What it does undermine: CLAUDE.md names batch entry ("Tambah Lagi") and
duplicate detection as two named V1 features, and this gap means the second
one silently stops doing anything precisely in the scenario the first one
is built for — a user firing off several quick back-to-back entries, most
plausibly right after each other, most plausibly while offline (the
"Tambah Lagi" flow's whole reason to exist). It's a missed nudge in exactly
the moment the nudge would be most useful, not a correctness defect.

### 3. Remediation options

- **A. Extend `hasPossibleDuplicate` to also check local pending rows.**
  Query `_localOutbox.localTransactionsInRange(userId, start, end)` bounded
  to the same day, filter to matching `categoryId`/`amount`, OR-combine
  with the existing Supabase result. All data needed is already resident
  on-device (no new network cost); mirrors the merge pattern
  `fetchHistoryWithPending` already established.
- **B. Route the check through a shared merged-read helper** (reuse/extend
  `fetchHistoryWithPending`'s merge logic instead of a second bespoke
  query). Heavier than needed — this check only needs an existence
  boolean, not a full merged, sorted list.
- **C. Accept as a documented limitation, no fix.** Consistent with the
  original finding's framing ("missed nudge, not a data-integrity
  problem"), but leaves a named V1 differentiator quietly non-functional in
  its most relevant scenario.

### 4. Recommendation

**Option A.** Smallest change that actually closes the gap: same
dependency the repository already holds, same query shape
`fetchHistoryWithPending` already uses elsewhere, no new network calls, no
change to the check's non-blocking contract. Low risk, proportionate to a
LOW/MEDIUM finding.

### 5. Test strategy

- Unit tests on `TransactionRepository.hasPossibleDuplicate` (new tests in
  `transaction_repository_test.dart`, following the existing seam pattern
  — inject a fake/in-memory `LocalOutboxRepository`):
  - Supabase has zero matching rows, but a matching **pending** local row
    exists for the same user/category/amount/day → returns `true`.
  - Supabase already has the match (today's passing case) → still returns
    `true`, unaffected.
  - Neither source has a match → returns `false`.
  - A local row exists but for a **different user** → returns `false`
    (ownership isolation preserved, same discipline as every other local
    read path in this codebase).
- Widget-level regression in `widget_test.dart`/`catat_screen_test.dart`:
  script an offline "Tambah Lagi" flow (record once, record again
  identically) and assert the "Transaksi mirip nih" dialog now appears —
  this directly targets manual QA checklist item **D11** ("Offline: repeat
  step 10... no dialog appears (Finding 3)"), which was documented as
  expected-no-dialog behavior specifically *because* of this gap. If this
  fix ships, item D11's expected result in
  `docs/sprint-003-real-device-qa-plan.md` would need updating in a future
  plan revision (not done here — that's a plan edit, out of this review's
  scope) — and its physical/emulator confirmation is still environment-
  blocked, unchanged by this proposal.

### 6. Schema / API / UI changes needed

**None.** `LocalTransactions` already carries `categoryId`, `amount`,
`transactionDate` — no new column. No Supabase schema or API change — this
never touches the network. No UI change — same dialog, same trigger point,
just a wider definition of "is a duplicate."

### 7. Scope estimate

**Small — under 1 day.** One method body change plus the unit/widget tests
above; no new dependency wiring (`_localOutbox` is already constructor-
injected into `TransactionRepository`).

---

## Finding 4 — `recoverStaleLeases()` doesn't run on a login→login transition without a background/foreground cycle

**Original severity:** LOW. **Where:**
`lib/core/sync/sync_lifecycle_gate.dart` (`initState`,
`didChangeAppLifecycleState`) and `lib/core/router/app_router.dart`
(`redirect`, driven by `AuthRepository.onAuthStateChange`).

### 1. Root cause

`recoverStaleLeases()` is reachable from exactly two triggers, both inside
`SyncLifecycleGate`:

```dart
// initState — cold start
unawaited(ref.read(syncWorkerProvider).runStartupSync());
...
// didChangeAppLifecycleState — resume
if (state == AppLifecycleState.resumed) {
  unawaited(ref.read(syncWorkerProvider).runStartupSync());
}
```

Sign-out/sign-in flows through `AuthRepository.onAuthStateChange` →
`GoRouterRefreshStream` → `app_router.dart`'s `redirect` callback, which
only decides *navigation* (send to `/sign-in` or away from it) — it never
touches `SyncWorker`. `AuthRepository` itself (`sendOtp`, `verifyOtp`,
`signOut`) has no sync-related call anywhere. So a straight-through
A → sign out → B → sign in sequence, with the app never backgrounded in
between, never calls `recoverStaleLeases()` on its own — confirmed by
reading both files end to end, not inferred.

### 2. Impact to KIRAIN V1

Very low. CLAUDE.md §1 states the typical usage pattern explicitly: **one
user on one device at a time** — this is not a shared-device app by design.
The scenario needs all three of: user A had a genuinely abandoned SYNCING
lease (app died mid-sync), a second user signs in on the *same physical
device*, and the handoff happens with zero background/foreground cycle in
between — a narrow, atypical sequence even in a household-sharing scenario
CLAUDE.md doesn't target for V1.

Already-verified properties limit the blast radius further (QA report §2,
"Verified — no gap found"): ownership isolation holds unconditionally at
the SQL-filter level regardless of lease state, so this never leaks user
A's data to user B. The only effect is user A's specific stuck item waits
longer than ideal to retry — self-heals at the very next resume or
restart. Not a correctness bug, not a data-safety bug — a delay bound,
and a loose one.

### 3. Remediation options

- **A. Call `recoverStaleLeases()` directly from `AuthRepository`'s sign-in
  path.** Rejected in the reasoning below before even reaching
  "recommendation" — puts sync-domain knowledge inside the auth feature,
  crossing a boundary this codebase otherwise keeps clean (auth doesn't
  currently know `SyncWorker` exists).
- **B. Subscribe `SyncLifecycleGate` to `AuthRepository.onAuthStateChange`
  directly**, and treat a `signedIn` event the same as a resume: call
  `recoverStaleLeases()` then `processQueue()`. Keeps all sync-trigger
  wiring inside the one widget already responsible for it (matches the
  file's own doc comment: "wraps the whole app... to wire up... ADR-002's
  ...sync triggers"), same shape as the existing connectivity-stream
  subscription already in the file.
- **C. No fix — document as an accepted limitation.** Matches the original
  finding's own conclusion ("flagging for awareness, not urgency") and
  KIRAIN's stated single-owner-device usage pattern.

### 4. Recommendation

**Option C, with Option B on record as the low-risk path if Tech Lead
wants closure anyway.** The scenario sits outside CLAUDE.md's stated
primary usage pattern, self-heals, and never compromises ownership
isolation — the bar this project uses elsewhere for "worth fixing now"
isn't met. If it's fixed anyway (e.g. to remove the asterisk on manual QA
item F15, or as defense-in-depth before any future multi-device work),
Option B is the smallest correct change: it reuses `SyncLifecycleGate`'s
existing responsibility instead of leaking sync concerns into
`AuthRepository`.

### 5. Test strategy (if Option B is approved)

- Extend `sync_lifecycle_gate` tests (or add a new test file mirroring the
  existing connectivity-subscription test pattern) asserting: a
  `signedIn` `AuthState` event triggers `recoverStaleLeases()` +
  `processQueue()`; a `signedOut` or `tokenRefreshed` event does **not**
  (avoid firing unnecessary sync work on every token refresh).
- Extend OFFLINE-002's existing "login/logout identity boundary" test
  group with the exact repro manual QA checklist item **15** describes:
  user A writes offline → sign out (no backgrounding) → sign in as B → back
  to A, with a **force-kill** substituted for the backgrounding step this
  finding is specifically about — assert the stale lease is reclaimed
  without needing an app lifecycle event. Checklist item 15 itself is
  physical-device-tagged and still environment-blocked (per the SPRINT-003
  execution report) — this automated test is a stand-in that exercises the
  same code path, not a substitute for eventually running it on real
  hardware.

### 6. Schema / API / UI changes needed

**None.** Purely a trigger-wiring change inside `SyncLifecycleGate`
(subscribing to one more existing stream); no schema, no Supabase API
surface, no UI.

### 7. Scope estimate

**Small — under 1 day** for Option B (a few lines mirroring the existing
connectivity-subscription pattern, plus the tests above). **Zero** if
Option C (no fix) is chosen, which is the recommendation.

---

## Finding 6 — Head-of-line blocking within one sync batch

**Original severity:** Observational, not a gap. **Where:**
`lib/core/sync/sync_worker.dart`, `_processBatch()` / `_processItem()`.

### 1. Root cause

```dart
Future<void> _processBatch() async {
  ...
  final items = await _outbox.eligibleBatch(limit: batchSize, userId: userId);
  for (final item in items) {
    await _processItem(item);
  }
}
```

Items in a batch (`batchSize = 10`) are processed **strictly
sequentially** — each `await _processItem(item)` fully completes,
including its own internal retry-with-backoff loop
(`maxAttemptsPerItem = 5`, `SyncBackoff(base: 2s, max: 60s)`, full jitter),
before the next item in the batch is even attempted. A persistently-
retryable item can burn up to 4 backoff waits (nominal ceiling
2+4+8+16 = 30s before jitter; actual elapsed time is uniformly random
under each cap, so typically less but bounded by that ceiling) before
giving up for this pass — and every other queued item behind it in the
same batch waits for that whole sequence before its own first attempt
starts.

### 2. Impact to KIRAIN V1

Low, and explicitly non-correctness: nothing is lost, nothing duplicated,
no wrong data ever shown — the next trigger (or the rest of this same loop
once the blocking item resolves) picks up whatever's left. Since
OFFLINE-003's optimistic local-first display already treats "pending" as
an expected, normal state (not an error), the user-visible effect is
narrow: on a flaky-but-not-fully-offline connection specifically, later
items in the same batch can stay "Belum tersinkron" longer than they'd
otherwise need to, purely because an earlier item in the same batch is
mid-retry. Most relevant to the OPPO A3s field-test profile named in the
original finding (flaky signal rather than clean offline) — a condition
real-device QA hasn't been able to exercise yet (still environment-
blocked).

### 3. Remediation options

- **A. No fix — document as an accepted, informational latency
  characteristic.** The original finding's own framing.
- **B. Bound elapsed *time* per item instead of attempt *count*,** handing
  off remaining attempts to the next batch/trigger once a per-item time
  budget is exceeded. Adds real complexity: `retryCount`'s semantics are
  already used elsewhere (surfaced to the user via `errorMessage`/history,
  read by `markPendingForRetry`) and would need to represent "attempts
  across passes," not just "attempts within one claim."
- **C. Bounded concurrency within a batch** — process items in small
  concurrent groups (e.g. 2–3 at a time via `Future.wait`) instead of one
  at a time, so one item's backoff no longer fully blocks its batch-mates.
  Each `_processItem` call is already independently safe to run
  concurrently: `claimForSync` is a conditional per-row SQL `UPDATE`
  (`WHERE id = ? AND sync_status = 'pending'`), and `deleteSynced`/
  `markFailed`/`markPendingForRetry` are all scoped to a single row by id
  — nothing in the current per-item logic assumes exclusive access to the
  whole batch.
- **D. Fully concurrent per-item retry loops** for the whole batch at
  once. Closest to eliminating the effect entirely, but changes the
  concurrency posture `SyncWorker`'s own doc comments currently describe
  (the single-flight `_guarded()` framing is about not running two
  *batches* concurrently, not about intra-batch concurrency, so this
  wouldn't violate that guarantee — but it's a bigger behavioral shift
  than C and deserves its own explicit review before being treated as
  equivalent-risk to C).

### 4. Recommendation

**Option A (no fix) for V1.** This matches the original finding's own
"observational, not a gap" framing, and the impact is bounded to a
specific, narrow network condition that never blocks or corrupts anything
— exactly the kind of latency characteristic that's reasonable to accept
rather than engineer around pre-launch. If OPPO A3s field testing (still
environment-blocked, not yet executed) surfaces this as an actual
user-perceptible pain point once it's finally run, **Option C** is the
right next step to revisit — it's the smaller, more contained of the two
concurrency options and doesn't require re-deriving new per-item safety
invariants (they already hold).

### 5. Test strategy (only if Option C is approved later — not now)

Extend `sync_worker_test.dart`: seed a batch where item 1 is scripted to
fail-then-succeed-after-backoff (using the existing injectable
`delay`/`random` seams so no real wall-clock wait is needed) and items
2–N are scripted to succeed immediately; assert that, under bounded
concurrency, items 2–N complete without waiting for item 1's full backoff
sequence to finish first.

### 6. Schema / API / UI changes needed

**None**, under any option. This is entirely internal to
`SyncWorker._processBatch`'s iteration strategy — no schema, no Supabase
API shape change, no UI.

### 7. Scope estimate

**Zero** — recommendation is no fix for V1. If Option C is revisited
later: small-to-medium, on the order of a few hours to one day, weighted
toward writing the concurrency-safety tests above rather than the
implementation itself (which is a small, contained change to one loop).

---

## Summary for Tech Lead decision

| # | Recommendation | Scope if approved | Schema/API/UI |
|---|---|---|---|
| 3 | **Fix** — extend `hasPossibleDuplicate` to also check local pending rows (Option A) | <1 day | None |
| 4 | **No fix** (Option C) — document as accepted limitation; Option B available if closure is wanted anyway | <1 day if B is chosen instead | None |
| 6 | **No fix** (Option A) — document as accepted, informational latency characteristic; revisit with Option C only if real-device QA later surfaces it as a real pain point | 0 now; small-medium if C is later revisited | None |

No implementation has been done for any of the three. Awaiting Tech Lead
approval on which (if any) to proceed with, and in what order. Real-device
QA remains environment-blocked and not completed, unchanged by this review.
