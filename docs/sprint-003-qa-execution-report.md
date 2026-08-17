# SPRINT-003 — QA Execution Report

> Executed against `docs/sprint-003-real-device-qa-plan.md` as the test
> contract, on `main` at commit `3f2a392` (branch `claude/sprint-003-qa-plan`,
> PR #50), plus final verification against `c02a2c0` after this report was
> first drafted. Run `2026-08-16`/`2026-08-17` in this session's remote
> execution container. **No application code was changed, and no bug found
> during this pass was fixed directly** — anything found is recorded as a
> finding for Tech Lead triage, per instruction. This report is the
> separate execution artifact; `docs/sprint-003-real-device-qa-plan.md`
> itself was **not edited** — the one correction this pass surfaced (§5.1)
> is recorded here as a finding, not applied silently to the agreed plan.

## Summary

| Category | Status | Count |
|---|---|---|
| Automated (`flutter analyze` + `flutter test`) | **PASS** | 2/2 checks, 204/204 tests |
| Build-artifact (§L) | **PARTIAL** | 1 PASS (source-level), 1 PARTIAL, 1 BLOCKED |
| Emulator baseline setup | **BLOCKED** | environment has no Android SDK / no virtualization |
| Device/emulator-tagged matrix items (§§A–K) | **BLOCKED** | 28 items, all BLOCKED on environment grounds |
| OPPO A3s physical-device items (§H, §J, §K24/K28/K29) | **BLOCKED** | no physical device reachable from this environment |
| **FAIL** anywhere in this pass | **None** | nothing that was actually executable failed |

Full detail and evidence for every line above is in §§0–4 below.

## 0. Environment reality check (read this first)

Before executing anything, this container was checked for the tooling the
plan's `emulator` and `build-artifact` tiers need:

| Requirement | Check | Result |
|---|---|---|
| Android SDK (`adb`, `emulator`, `avdmanager`, `sdkmanager`) | `which adb emulator avdmanager sdkmanager` | **None present** — `flutter doctor -v` confirms: "✗ Unable to locate Android SDK" |
| Hardware virtualization (needed for the Android emulator to run at all, even headless) | `grep -Eo 'vmx\|svm' /proc/cpuinfo` | **Empty** — no virtualization extensions exposed to this container |
| KVM device node | `ls /dev/kvm` | **No such file** |
| KVM kernel module | `lsmod \| grep kvm` | **Not loaded** |
| Network egress to fetch the Android SDK ourselves | `curl -I https://dl.google.com/android/repository/commandlinetools-linux-*.zip` | **HTTP 403** — this environment's outbound proxy doesn't allow it |

**Conclusion:** this container cannot install, build for, or run anything
requiring the Android SDK or the Android emulator — not due to a shortcut
taken here, but because none of the underlying capabilities exist in this
remote execution environment. Every item in the QA plan tagged `emulator`,
`physical-device`, or `build-artifact` (except the two config checks that
only need to read source files, §2 below) is marked **BLOCKED** for that
reason, not attempted-and-failed. This matches the QA plan's own
instruction to mark the OPPO A3s BLOCKED when the environment doesn't allow
it — the same standard is applied here to the emulator tier too, since
neither is actually reachable from this container.

## 1. Automated checks — executed, with evidence

Run twice this session — once during initial execution, once as final
verification after tidying this report — same commands the
`flutter-ci.yml` workflow runs, both times on a clean `flutter pub get`:

```
$ flutter analyze                                  (2026-08-16, initial)
Analyzing kirain-app...
No issues found! (ran in 1.7s)

$ flutter test                                     (2026-08-16, initial)
...
00:15 +204: All tests passed!

$ flutter analyze                                  (2026-08-17, final verification)
Analyzing kirain-app...
No issues found! (ran in 11.2s)

$ flutter test                                      (2026-08-17, final verification)
...
00:14 +204: All tests passed!
```

- **`flutter analyze`: PASS — 0 issues, both runs.**
- **`flutter test`: PASS — 204/204 passing, both runs** (193 pre-existing +
  9 DRIFT-MIGRATION-001 + 2 OFFLINE-INTEGRATION-001 regression tests, per
  the running total established across prior sprints).

Identical results both times — no drift, no flake, no regression between
the initial pass and final verification. This is the entirety of what
"automated" coverage in the plan's §2 environment table actually reaches —
pure Dart/widget-test-layer logic.

## 2. Build-artifact checks — 1 PASS (source-level), 1 PARTIAL, 1 BLOCKED

The plan's §L items assume a real `flutter build apk --release` is
possible. It isn't here (§0). Two of the three were still partially
checkable by reading source directly, without building:

| # | Test | Status | Evidence |
|---|---|---|---|
| L30 | APK size via `--analyze-size` | **BLOCKED** | Requires an actual release build; no Android SDK to build with |
| L31 | Merged release manifest contains `INTERNET`/`USE_BIOMETRIC` | **PARTIAL — source-level PASS, build-level BLOCKED** | The *authored* `android/app/src/main/AndroidManifest.xml` declares both (`grep uses-permission` confirms `android.permission.INTERNET` and `android.permission.USE_BIOMETRIC` present, lines 9–10). This proves the ANDROID-001 fix is still in the source. It does **not** prove the *merged* manifest a real build produces still has them — manifest merging can theoretically be affected by plugin/library manifests in ways only a real build surfaces. That verification stays BLOCKED. |
| L32 | `minSdkVersion` sanity vs. CLAUDE.md's documented 26 | **PASS (source-level, re-confirmed this session)** | `android/app/build.gradle.kts:22` still reads `minSdk = flutter.minSdkVersion` (no override); the installed Flutter 3.47.0 toolchain's own default is confirmed `24` (`FlutterExtension.kt:26`). Matches the finding already on record in the QA plan §1 — re-verified, not newly discovered, no drift since the plan was written. |

## 3. Emulator baseline (§1 of the instruction)

**BLOCKED.** Per §0's environment check, no AVD could be created or booted
in this container — there is no Android SDK to create one with, and no
virtualization capability to run one on even if the SDK were somehow
present. Nothing in §§A–L tagged `emulator` could be executed as a result.

## 4. Full matrix results (Sections A–L)

Status legend: **PASS** (executed, passed) / **FAIL** (executed, failed) /
**BLOCKED** (couldn't be executed in this environment) / **PARTIAL**
(part of the item is checkable without a device/build, part isn't).

| # | Test | Plan tag(s) | Status | Note |
|---|---|---|---|---|
| A1–A4 | Offline/online transition | emulator, physical-device | **BLOCKED** | No emulator or device reachable |
| B5–B7 | Force-kill/restart recovery | emulator, physical-device | **BLOCKED** | Same |
| C8–C9 | Sync recovery/retry | emulator, physical-device | **BLOCKED** | Same |
| D10 | Online duplicate dialog | *plan tagged this "automated (adjacent)" — corrected below* | **BLOCKED** | See §5 finding 1: this tag was optimistic. No automated test actually exercises the "Transaksi mirip nih" dialog appearing (`grep` across `test/` finds zero references to that string, or to a scenario where `hasPossibleDuplicate` returns `true`) — the widget-test fakes all stub it to return `false`. Genuinely needs emulator/device. |
| D11 | Offline duplicate (no dialog) | emulator, physical-device | **BLOCKED** | — |
| E12 | FAILED → manual retry (device UI) | emulator, physical-device | **BLOCKED** | The *underlying* retry mechanics (`SyncWorker.retryFailedItem`, badge tap wiring) are automated-tested (`sync_worker_test.dart`, `rekap_screen_test.dart`) and passed in §1 — this item is specifically the on-device UX confirmation, which stays BLOCKED |
| F13–F15 | Logout/login ownership isolation (device) | emulator, physical-device | **BLOCKED** | Underlying ownership-filtering logic is automated-tested and passed in §1; this item is the on-device visual confirmation |
| G16 | Release APK behavior | emulator, physical-device | **BLOCKED** | Also needs a real build (§2, L30/L31) |
| H17–H19 | OPPO A3s Mode Hemat Energi | physical-device only | **BLOCKED** | Per instruction #7 — physical device not available in this environment |
| I20–I21 | Migration & app-update (device-level) | emulator, physical-device | **BLOCKED** | The *SQL-level* migration correctness this item exists alongside is automated-tested (`kirain_database_migration_test.dart`, 9/9 passing, part of §1's 204) — the *Android update-in-place* behavior this item specifically targets needs a real install, stays BLOCKED |
| J22–J23 | Low-memory/OEM background kill | physical-device only | **BLOCKED** | OPPO A3s / ColorOS-specific, no substitute environment exists for this at all |
| K24 | Biometric, real hardware | physical-device (hardware-dependent) | **BLOCKED** | — |
| K25 | Biometric, virtual finger | emulator | **BLOCKED** | No emulator |
| K26–K27 | App shortcut, home-screen widget | emulator, physical-device | **BLOCKED** | — |
| K28 | Real WiFi↔cellular handoff | physical-device only | **BLOCKED** | — |
| K29 | Real low-storage pressure | physical-device only | **BLOCKED** | — |
| L30 | APK size via `--analyze-size` | build-artifact | **BLOCKED** | See §2 |
| L31 | Merged release manifest permissions | build-artifact | **PARTIAL** | See §2 |
| L32 | `minSdkVersion` sanity check | build-artifact | **PASS** | See §2 |

**Tally: 2/2 automated checks PASS (§1, 204/204 tests), 1 build-artifact
PASS + 1 PARTIAL + 1 BLOCKED (§2), 28 device/emulator-tagged items BLOCKED
(§§A–K).** Zero FAIL anywhere — nothing that *was* actually executable in
this environment failed.

## 5. Findings from this pass

1. **The QA plan's D10 tag was optimistic and should be corrected.**
   `docs/sprint-003-real-device-qa-plan.md` currently tags D10 as
   `automated (hasPossibleDuplicate logic already unit-adjacent via
   repository), emulator for the actual dialog UX` — on actually trying to
   execute the "automated" half this session, there is no such test. The
   duplicate-check dialog path (`_confirmDuplicate` /
   "Transaksi mirip nih" in `catat_screen.dart`) has zero automated
   coverage; every widget-test fake stubs `hasPossibleDuplicate` to return
   `false` specifically to avoid exercising it. Recommend re-tagging D10 as
   fully `emulator, physical-device` in the plan doc (no code change
   needed for this correction — just a doc edit — not made here since this
   report's job is to record findings, not silently patch the plan out
   from under a Tech-Lead-reviewed document).
2. **Everything device/emulator-tagged is BLOCKED by environment, not by
   any newly discovered defect.** No FAIL was produced anywhere in this
   pass. This report should not be read as "QA passed" for sections A–L —
   only §1 (automated) and part of §2 (build-artifact, source-level only)
   were actually exercised. The remaining ~28 items are exactly where they
   were before this session: specified, tagged, and waiting on real
   hardware or an environment with Android SDK + virtualization access.
3. **No regressions.** `flutter analyze` and `flutter test` both re-confirm
   clean/green on the exact commit this report is filed against, matching
   the state CI already reported after PR #49.

## 6. What still needs a human with real tooling/hardware

Everything marked BLOCKED in §4, unchanged from the plan's own §4
recommended execution order: build-artifact checks first (now that Android
SDK access exists somewhere with one), then emulator pass (two AVDs — API
26 floor + a recent-API image), then physical higher-end device, then the
OPPO A3s last. None of this can be advanced further from this remote
container.

## 7. Explicitly not done, per instruction

No bug fixes applied (none were found to fix, in any case — see §5.2). No
work started on OFFLINE-INTEGRATION-001 Findings 3/4/6, Crashlytics, or
OFFLINE-004. Nothing merged.
