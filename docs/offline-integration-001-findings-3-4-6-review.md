# OFFLINE-INTEGRATION-001 — Findings 3, 4, 6 Remediation Proposal

> **Revision note:** this document was first written as a lighter-weight
> review (root cause / impact / remediation options / recommendation / test
> strategy / schema-API-UI impact / scope estimate per finding). This
> revision **expands it in place, on the same branch/PR**, into the full
> Remediation Proposal structure the Tech Lead asked for on reassessment —
> it supersedes the earlier pass rather than sitting alongside it, since
> `main` has not moved (still `ee4860a`, PR #49 + PR #50 merged, PR #50 not
> touched or reopened) and the underlying analysis hasn't changed, only its
> required depth. No new branch was created for this revision.
>
> **No changes have been implemented for any finding. No code PR has been
> opened or will be opened for this task** — this document is a docs-only
> deliverable for Tech Lead review. OFFLINE-004 and Crashlytics remain
> **not started**, and stay that way until this proposal is reviewed and a
> finding is explicitly assigned.
>
> Verified against `main` at `ee4860a` (current as of this revision — `git
> diff main origin/main` on every file cited below returns empty, i.e. no
> drift since the code was last read for this analysis). `flutter analyze`/
> `flutter test` were not re-run since no code changed; last known-green
> baseline remains PR #50 (204/204 passing).
>
> **Real-device QA remains environment-blocked, not completed**
> (`docs/sprint-003-qa-execution-report.md`) — nothing below assumes or
> claims that status has changed. Where a finding points at a manual QA
> checklist item as the way to confirm behavior on real hardware, that item
> is still unexecuted and called out as such, not treated as evidence
> either way.
>
> Findings 1 and 2 are already fixed and merged. Finding 5 (migration test
> coverage) was already closed by DRIFT-MIGRATION-001 (PR #49, merged) —
> out of scope here.

---

## Finding 3 — Soft duplicate check never looks at pending local rows

**Original severity:** LOW/MEDIUM.

### Exact current behavior (from code, `main` @ `ee4860a`)

`lib/features/transactions/data/transaction_repository.dart`:

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

Called from `lib/features/catat/catat_screen.dart` `_doSubmit()`
(lines ~138–145):

```dart
var isDuplicate = false;
try {
  isDuplicate = await ref
      .read(transactionRepositoryProvider)
      .hasPossibleDuplicate(categoryId: category.id, amount: amount, date: DateTime.now());
} catch (_) {
  isDuplicate = false;
}
if (isDuplicate) {
  final proceed = await _confirmDuplicate(category, amount);
  if (proceed != true) return;
}
```

This is the entire mechanism — one Supabase-only query, wrapped in a
try/catch at the call site that treats any failure (including "no network")
as "not a duplicate" by design, since the check must never block a save.

### Original finding & root cause

**Where:** the same location above. **Root cause:** the check has exactly
one data source (Supabase's `transactions` table) while the app, since
OFFLINE-003, has two (Supabase + `LocalOutboxRepository`'s local pending
rows via `localTransactionsInRange`, which `TransactionRepository` already
holds a reference to as `_localOutbox` — constructor-injected, confirmed by
re-reading the constructor). Two failure modes share this one root cause:

- **Fully offline:** the Supabase call throws; the call site's catch turns
  that into "not a duplicate" — not because the logic decided so, but
  because the only place it looks is unreachable.
- **Online, race window:** the first entry has landed locally but hasn't
  synced yet; the Supabase query genuinely returns empty because the true
  duplicate isn't there yet.

### Still reproducible?

**Yes.** Confirmed by re-reading the exact code above against current
`main` — nothing about this method or its call site changed across PR #49
or PR #50 (both were migration-tests and QA-docs work respectively;
neither touched `transaction_repository.dart` or `catat_screen.dart`).
`grep` across `test/` (repeated for this revision) still finds zero test
exercising a scenario where `hasPossibleDuplicate` returns `true` from a
local-only match — every widget-test fake stubs it to `false`.

### Severity & impact to KIRAIN V1

Low. Duplicate detection is explicitly **soft/non-blocking** (CLAUDE.md) —
this never corrupts data, never blocks a save, never produces a duplicate
*id* or an inconsistent state; both entries land as two legitimate rows
either way (already-verified behavior, QA checklist item 11). What it does
undermine: CLAUDE.md names both "Tambah Lagi" batch entry and duplicate
detection as V1 features, and this gap silently disables the second
precisely during the scenario the first is built for (fast repeat entries,
plausibly offline). A missed nudge in the moment it would matter most, not
a correctness defect.

### Security / data-integrity implications

**None.** No authorization boundary is crossed (the check only ever reads
data the current session is already allowed to see — Supabase RLS still
applies to the query, and the local read path is already user-scoped
everywhere else in this codebase). No CHECK constraint, foreign key, or
uniqueness invariant is at risk — a "missed" duplicate is still a fully
valid, independently-idish row on both sides. This is a UX-completeness gap,
not a data-integrity gap.

### Recommended remediation

Extend `hasPossibleDuplicate` to also query
`_localOutbox.localTransactionsInRange(userId: ..., start: dayStart, end: dayStart + 1 day)`,
filter to matching `categoryId`/`amount`, and OR-combine with the existing
Supabase result. All data needed is already resident on-device (no new
network cost); mirrors the merge pattern `fetchHistoryWithPending` already
established for the same local/remote split.

### Alternative approach

Route the check through a shared merged-read helper (reuse/extend
`fetchHistoryWithPending`'s merge logic) instead of a second bespoke query.
Rejected as the primary recommendation: heavier than needed for what's
just an existence boolean, and couples this check to a method whose real
job is paginated list rendering.

### Files / modules likely affected

- `lib/features/transactions/data/transaction_repository.dart` —
  `hasPossibleDuplicate` body only; no signature change needed (already
  has `_localOutbox` available).
- `test/features/transactions/data/transaction_repository_test.dart` (or
  wherever its existing tests live) — new cases.
- `test/widget_test.dart` / `catat_screen_test.dart` — new regression case
  for the offline "Tambah Lagi" flow.
- No other module needs to change — `catat_screen.dart`'s call site is
  unaffected (same method signature, same return type).

### Migration / API / UI implications

**None.** No Drift schema change (`LocalTransactions` already carries
`categoryId`/`amount`/`transactionDate`) — the CLAUDE.md migration-approval
gate ("jangan jalankan migration tanpa 'OK, jalankan'") does not apply
here. No Supabase schema or REST/RPC surface change. No UI change — same
dialog, same trigger point, only a wider definition of "is a duplicate."

### Regression-test strategy

- Unit tests on `TransactionRepository.hasPossibleDuplicate`: (a) Supabase
  has zero matches but a matching **pending** local row exists for the
  same user/category/amount/day → `true`; (b) Supabase already has the
  match (today's passing case) → still `true`; (c) neither source matches
  → `false`; (d) a local match exists for a **different user** → `false`
  (ownership isolation, consistent with every other local read path).
- Widget-level regression: script an offline "Tambah Lagi" flow (record
  once, record again identically) and assert the "Transaksi mirip nih"
  dialog now appears. This directly targets manual QA checklist item
  **D11** — its expected result would need updating in a future
  `sprint-003-real-device-qa-plan.md` revision if this ships (a plan edit,
  not done here, and out of this proposal's scope); its physical/emulator
  confirmation stays environment-blocked regardless.
- `flutter analyze` clean, full `flutter test` suite green, 0 regressions,
  as the acceptance bar already used for every prior fix in this
  engagement (Findings 1/2, DRIFT-MIGRATION-001).

### Definition of Done

1. `hasPossibleDuplicate` consults both Supabase and local pending rows,
   OR-combined.
2. All four unit-test cases above added and passing.
3. Offline "Tambah Lagi" widget regression test added, confirmed failing
   pre-fix / passing post-fix (same fail-then-pass discipline used for
   Findings 1/2 and DRIFT-MIGRATION-001).
4. `flutter analyze` — 0 issues. `flutter test` — full suite green, no
   regressions elsewhere.
5. No schema/migration/API/UI change introduced.
6. Change scoped to exactly the files listed above — no drift into
   Sync Worker, Goals/Recurring, or other OFFLINE-00x behavior.
7. Opened as its own PR, **not merged**, awaiting Tech Lead review —
   consistent with this engagement's standing gate.

---

## Finding 4 — `recoverStaleLeases()` doesn't run on a login→login transition without a background/foreground cycle

**Original severity:** LOW.

### Exact current behavior (from code, `main` @ `ee4860a`)

`lib/core/sync/sync_lifecycle_gate.dart` — the only two call sites of
`recoverStaleLeases()` (via `runStartupSync()`):

```dart
// initState — cold start
unawaited(ref.read(syncWorkerProvider).runStartupSync());
...
// didChangeAppLifecycleState — resume
if (state == AppLifecycleState.resumed) {
  unawaited(ref.read(syncWorkerProvider).runStartupSync());
}
```

`lib/core/router/app_router.dart` — the sign-in/sign-out path, driven by
`AuthRepository.onAuthStateChange` via `GoRouterRefreshStream`:

```dart
redirect: (context, state) {
  final isSignedIn = authRepository.currentUser != null;
  final isAuthRoute = _authRoutes.contains(state.matchedLocation);
  if (!isSignedIn && !isAuthRoute) return '/sign-in';
  if (isSignedIn && isAuthRoute) return '/';
  return null;
},
```

This `redirect` callback only ever returns a route or `null` — it has no
side channel to `SyncWorker`. `lib/features/auth/data/auth_repository.dart`
(`sendOtp`, `verifyOtp`, `signOut`) confirmed to have zero references to
`SyncWorker`/`recoverStaleLeases`/`processQueue` anywhere in the file.

### Original finding & root cause

**Where:** the three files above. **Root cause:** `recoverStaleLeases()`
is reachable from exactly two triggers (cold start, resume), both app
**lifecycle** events. Sign-out→sign-in is a **navigation/auth** event with
no wiring into the sync domain at all. A straight A→sign out→B→sign in
sequence, with the app never backgrounded in between, never calls
`recoverStaleLeases()` — confirmed by reading all three files end to end,
not inferred from documentation.

### Still reproducible?

**Yes**, by the same code-reading method above — none of `sync_lifecycle_
gate.dart`, `app_router.dart`, or `auth_repository.dart` changed across
PR #49/#50 (`git diff main origin/main` empty on all three).

### Severity & impact to KIRAIN V1

Very low. CLAUDE.md §1 states the intended usage pattern explicitly: one
user, one device, at a time — this scenario needs a same-device handoff
between two different accounts with zero backgrounding in between, outside
KIRAIN's stated primary usage pattern even before considering how narrow
the trigger condition (an already-abandoned SYNCING lease) is on top of
that. Self-heals at the very next resume or cold start.

### Security / data-integrity implications

**None** — this is the load-bearing fact that keeps this LOW rather than
MEDIUM. Already verified (QA report §2, "Verified — no gap found") and
re-confirmed here by code: every local read/write path
(`eligibleBatch`, `localTransactionsInRange`, `syncStatusesForIds`)
resolves the current session's `userId` as a **live closure** and filters
at the SQL level, not a post-fetch check. Concretely: `eligibleBatch`
queries `WHERE sync_status = 'pending' AND user_id = ?` scoped to the
*current* session's user — user B's session can never even see user A's
stale-locked row as a claim candidate, regardless of its lease state.
There is no code path where a stuck lease becomes cross-user-visible data;
the only effect is a delay on when *A's own* item next gets a retry
attempt, self-resolving at A's next resume.

### Recommended remediation

**Accept as-is, no fix**, on the record with an explicit revisit trigger
(see alternative). The scenario sits outside CLAUDE.md's stated usage
pattern, self-heals, and carries zero security/data-integrity risk — this
project's own bar for "worth fixing pre-launch" (used consistently for
Findings 1 and 2, both of which had real user-facing or data-shape impact)
isn't met here.

### Alternative approach

If Tech Lead wants closure anyway (e.g. to remove the caveat on manual QA
checklist item F15, or as defense-in-depth ahead of any future multi-device
work per CLAUDE.md's v1.3 `household_id` roadmap note): subscribe
`SyncLifecycleGate` to `AuthRepository.onAuthStateChange` directly and
treat a `signedIn` event the same as a resume — call `recoverStaleLeases()`
then `processQueue()`. This keeps all sync-trigger wiring inside the one
widget already responsible for it (its own doc comment: "wraps the whole
app... to wire up... ADR-002's ...sync triggers"), the same shape as the
file's existing connectivity-stream subscription. Explicitly **not**
recommending wiring this into `AuthRepository` itself — that would leak
sync-domain knowledge into the auth feature, crossing a boundary this
codebase otherwise keeps clean.

### Files / modules likely affected (only if the alternative is later assigned)

- `lib/core/sync/sync_lifecycle_gate.dart` — new subscription to
  `AuthRepository.onAuthStateChange`, gated to `signedIn` events only.
- New/extended test file mirroring the existing connectivity-subscription
  test pattern.
- `lib/features/auth/data/auth_repository.dart` and `app_router.dart` —
  read-only dependency (`onAuthStateChange` already public), no change
  needed to either.

### Migration / API / UI implications

**None**, under either the recommendation or the alternative. No schema,
no Supabase API surface, no UI — purely internal trigger wiring if ever
implemented.

### Regression-test strategy (only if the alternative is later assigned)

- New test asserting a `signedIn` `AuthState` event triggers
  `recoverStaleLeases()` + `processQueue()`; a `signedOut` or
  `tokenRefreshed` event does **not** (avoid unnecessary sync work on every
  token refresh).
- Extend OFFLINE-002's existing "login/logout identity boundary" test
  group with manual QA checklist item **15**'s exact repro (A writes
  offline → sign out, no backgrounding → sign in as B → back to A, with a
  force-kill substituted for backgrounding) — assert the stale lease is
  reclaimed without an app lifecycle event. Item 15 itself is
  physical-device-tagged and still environment-blocked; this automated
  test exercises the same code path as a stand-in, not a substitute for
  eventually running it on real hardware.

### Definition of Done

**As accepted (recommended path):**
1. This finding recorded as "Accepted, no fix" against
   `docs/offline-integration-001-qa-report.md`'s tracking, via this
   proposal's approval — not a silent edit to that report.
2. No code change.
3. Ownership-isolation invariant re-confirmed unaffected (done above).

**If the alternative is explicitly assigned instead:**
1. `SyncLifecycleGate` subscribes to `onAuthStateChange`, calls
   `recoverStaleLeases()` + `processQueue()` on `signedIn` only.
2. New tests per the strategy above, passing.
3. `flutter analyze` clean, `flutter test` full suite green.
4. No schema/API/UI change introduced.
5. Opened as its own PR, not merged, awaiting review.

---

## Finding 6 — Head-of-line blocking within one sync batch

**Original severity:** Observational, not a gap.

### Exact current behavior (from code, `main` @ `ee4860a`)

`lib/core/sync/sync_worker.dart`:

```dart
Future<void> _processBatch() async {
  final userId = _currentUserId();
  if (userId == null) return;
  final items = await _outbox.eligibleBatch(limit: batchSize, userId: userId);
  for (final item in items) {
    await _processItem(item);
  }
}
```

`batchSize = 10`, `maxAttemptsPerItem = 5`,
`SyncBackoff(base: Duration(seconds: 2), max: Duration(seconds: 60))` with
full jitter (`lib/core/sync/sync_backoff.dart`,
`delayForAttempt`: `random.nextDouble() * min(base * 2^attempt, max)`).
`_processItem` claims the row (`claimForSync`, a conditional per-row SQL
`UPDATE ... WHERE id = ? AND sync_status = 'pending'`), then loops up to
`maxAttemptsPerItem` times, `await`ing `_backoff`-governed delays between
retryable failures before moving to the next item in `items`.

### Original finding & root cause

**Where:** the same loop above. **Root cause:** batch items are processed
**strictly sequentially** — each item's full retry-with-backoff sequence
(`await _processItem(item)`) completes before the next item is even
attempted. A persistently-retryable item can consume up to 4 backoff waits
(nominal ceiling `2+4+8+16 = 30s` before jitter; actual elapsed time is
uniformly random under each cap, so typically less, but bounded by that
ceiling) before this pass gives up on it — every other queued item behind
it in the same batch waits for that entire sequence before its own first
attempt starts.

### Still reproducible?

**Yes** — `sync_worker.dart` and `sync_backoff.dart` are both unchanged
across PR #49/#50 (`git diff main origin/main` empty on both), and the
sequential `for` loop plus the `batchSize`/`maxAttemptsPerItem`/backoff
constants are exactly as originally documented.

### Severity & impact to KIRAIN V1

Low, explicitly non-correctness: nothing lost, nothing duplicated, no
wrong data shown — the next trigger (or the rest of this same loop, once
the blocking item resolves) picks up whatever's left. OFFLINE-003's
optimistic local-first display already treats "pending" as a normal,
expected state, not an error, so the visible effect is narrow: on a
flaky-but-not-fully-offline connection specifically, later items in the
same batch can stay "Belum tersinkron" longer than strictly necessary.
Most relevant to the OPPO A3s field-test profile the original finding
named (flaky signal, not clean offline) — a condition real-device QA
hasn't exercised yet (still environment-blocked).

### Security / data-integrity implications

**None**, and worth stating the current design's implicit *benefit* here:
strictly sequential processing means there is currently **no concurrency
between items in a batch to reason about** — no shared mutable state, no
possibility of two items' writes interleaving unexpectedly. Introducing
concurrency later (see alternative) doesn't currently threaten integrity
either, since `claimForSync`/`deleteSynced`/`markFailed`/
`markPendingForRetry` are all already scoped to a single row by `id` at
the SQL level — but it does mean any future concurrency change should be
reviewed specifically for this property rather than assumed safe by
analogy to today's sequential code.

### Recommended remediation

**Accept as-is, no fix**, matching the original finding's own framing
("observational, not a gap"). The impact is bounded to a specific, narrow
network condition that never blocks or corrupts anything — a reasonable
characteristic to accept pre-launch rather than engineer around before
there's field evidence it matters in practice.

### Alternative approach

**Bounded concurrency within a batch** (e.g. process items in groups of
2–3 via `Future.wait` instead of one at a time) if OPPO A3s field testing
(still environment-blocked, not yet executed) surfaces this as an actual
user-perceptible pain point. Preferred over two other options considered
and rejected:

- *Time-bounding per item instead of attempt-count-bounding* — rejected:
  would change `retryCount`'s semantics (currently "attempts within one
  claim," used elsewhere for diagnostics/backoff) into something
  representing attempts *across* passes, a bigger and riskier change than
  the problem warrants.
- *Fully concurrent per-item retry loops for the whole batch at once* —
  rejected as the first-choice alternative: bigger behavioral shift than
  bounded concurrency, and while it wouldn't violate `_guarded()`'s
  single-flight guarantee (that's about not running two *batches*
  concurrently, not about intra-batch concurrency), it deserves its own
  explicit review rather than being treated as equivalent-risk to bounded
  concurrency.

### Files / modules likely affected (only if the alternative is later assigned)

- `lib/core/sync/sync_worker.dart` — `_processBatch`'s iteration strategy
  only; `_processItem`'s internals unchanged.
- `test/core/sync/sync_worker_test.dart` — new concurrency-behavior test.

### Migration / API / UI implications

**None**, under either the recommendation or the alternative — entirely
internal to `SyncWorker._processBatch`'s iteration strategy.

### Regression-test strategy (only if the alternative is later assigned)

Extend `sync_worker_test.dart`: seed a batch where item 1 is scripted to
fail-then-succeed-after-backoff (using the existing injectable
`delay`/`random` seams, no real wall-clock wait needed) and items 2–N
succeed immediately; assert that, under bounded concurrency, items 2–N
complete without waiting for item 1's full backoff sequence.

### Definition of Done

**As accepted (recommended path):**
1. Finding recorded as "Accepted, informational" against the
   OFFLINE-INTEGRATION-001 report's tracking, via this proposal's
   approval.
2. No code change.
3. Explicit revisit trigger on record: only reopen if real-device QA
   (once unblocked) surfaces this as an actual user-perceptible issue on
   a flaky-connection profile.

**If the alternative is explicitly assigned instead:**
1. `_processBatch` processes items with bounded concurrency (group size
   to be confirmed with Tech Lead, 2–3 suggested).
2. New concurrency test per the strategy above, passing.
3. `flutter analyze` clean, `flutter test` full suite green.
4. No schema/API/UI change introduced.
5. Opened as its own PR, not merged, awaiting review.

---

## Remediation Proposal — priority summary

| # | Finding | Reproducible? | Security/data-integrity risk | Recommendation | Priority |
|---|---|---|---|---|---|
| 3 | Soft duplicate check misses local pending rows | Yes | None | Fix — extend `hasPossibleDuplicate` to check local pending rows too | **P1** |
| 4 | `recoverStaleLeases()` not triggered on login→login without a background cycle | Yes | None (ownership isolation independently holds regardless of lease state) | Accept-as-is; alternative fix on record if Tech Lead wants closure | **Accept-as-is** |
| 6 | Head-of-line blocking within one sync batch | Yes | None (sequential processing has no cross-item concurrency to reason about) | Accept-as-is; revisit only if real-device QA surfaces real pain | **Accept-as-is** |

**Priority rationale:**
- **P1, not P0**, for Finding 3: no data damage, no security exposure, save
  path stays non-blocking either way — this is a UX-completeness gap in a
  named V1 differentiator, not a defect that risks user data or trust.
  Cheap to fix (<1 day) and worth doing before V1 ships, but nothing here
  is on fire.
- **Accept-as-is** for Findings 4 and 6: both self-heal, both carry zero
  security/data-integrity risk (independently re-verified above, not just
  restated from the original finding), and both sit outside or at the very
  edge of CLAUDE.md's stated V1 usage assumptions. Neither meets this
  project's own bar for pre-launch urgency, matching how Findings 1 and 2
  were the only two the original QA report treated as "concrete blockers."
- No **P0** or **P2** assignment applies to any of the three under current
  evidence — P0 would require a security/data-loss path (none exists here);
  P2 would imply "worth doing eventually but not urgent, and not simply
  accepted" — Findings 4 and 6 are better described as accepted with a
  named revisit trigger than as a vague backlog item.

**Nothing in this proposal has been implemented.** No code PR has been
opened. Per instruction, **OFFLINE-004 and Crashlytics remain not started**
until this proposal is reviewed and a specific finding is explicitly
assigned. Real-device QA remains environment-blocked and not completed,
unaffected by this reassessment.
