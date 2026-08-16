# SPRINT-003 — Real-Device & Emulator QA Execution Plan

> Audited against `main` at commit `d9a264f` (PR #49, DRIFT-MIGRATION-001,
> merged). **No application code changed to produce this document.** Not
> merged — this is a planning artifact. Findings 3/4/6, Crashlytics, and
> OFFLINE-004 are untouched and out of scope here.

## 0. What changed since the last QA checklist was written

The 19-item checklist in `docs/offline-integration-001-qa-report.md` §3 is
the baseline this plan extends. Since it was written, two things changed
the picture:

- **CI now runs `flutter analyze` + `flutter test` automatically** on every
  PR/push (SPRINT-001, `.github/workflows/flutter-ci.yml`).
- **The v1→v2→v3 Drift migration path now has automated fixture-level
  tests** (DRIFT-MIGRATION-001, `test/kirain_database_migration_test.dart`)
  — 9 tests proving the real `onUpgrade` preserves data and enforces
  constraints, verified sensitive to a deliberately broken migration.

Neither of these replaces device-level QA — they narrow *what* device QA
still needs to worry about. Fixture-level migration tests prove the SQL
migration logic itself is correct; they say nothing about whether a real
Android APK update-in-place actually preserves the app's private storage,
whether the app survives a real OEM task-kill, or whether a real fingerprint
sensor's timing breaks anything. Those remain device-only concerns and are
now called out explicitly below (§4, new items I–L) rather than left
implicit.

## 1. New audit findings from this pass (config/environment, not app logic)

None of these required an application-code change to *discover*, and none
are being fixed in this PR per instruction — they're flagged so the QA
matrix below accounts for them accurately rather than testing against
assumptions that don't match the actual build config.

1. **`minSdkVersion` doesn't match CLAUDE.md's documented floor.**
   `android/app/build.gradle.kts` sets `minSdk = flutter.minSdkVersion`,
   never overriding it — meaning the project floor is whatever the
   installed Flutter SDK defaults to (**24**, confirmed from the Flutter
   3.47.0 toolchain's `FlutterExtension.kt`), not the **26** CLAUDE.md
   §3 states as the minimum. This doesn't put the OPPO A3s (Android 8.1,
   API 27) at any risk — 27 comfortably clears either floor — but it does
   mean the app is currently installable on Android 7.0/7.1 devices that
   have never been part of the declared support matrix and have zero test
   coverage, automated or manual. Flagged for a future explicit
   `minSdk = 26` in `build.gradle.kts`; not fixed here (application code).
2. **The release build type is signed with the debug keystore.**
   `buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }`
   — there is no real release signing config yet. A "release APK" built and
   tested per this plan validates release-mode *behavior* (the INTERNET
   permission merge ANDROID-001 fixed, R8/resource-shrinking if later
   enabled, asserts stripped) — it is **not** a Play Store/Galaxy Store
   distribution-ready artifact. That's a separate, larger pre-launch task
   this plan doesn't attempt to close.
3. **Minification is not yet enabled** (`isMinifyEnabled` unset, no
   `proguard-rules.pro` in the repo) — so there's currently no R8/ProGuard
   stripping risk to test for on drift/sqlite3's native bindings. Worth
   re-auditing once minification is ever turned on (it commonly needs keep
   rules for reflection-based native bindings) — not a concern today.
4. **Notification channels (Reminder Harian / Peringatan Budget / Update &
   Info, CLAUDE.md §3) aren't implemented yet** — no
   `flutter_local_notifications` or equivalent dependency exists in
   `pubspec.yaml`. Excluded from this plan entirely rather than listing
   untestable items for a feature that doesn't exist.
5. **OPPO A3s biometric hardware should be confirmed, not assumed.** Most
   OPPO A3s units shipped with a rear fingerprint sensor, but regional
   variants differ. Item E3 below now says "confirm hardware capability
   first" rather than assuming it's present.

## 2. Environment definitions

| Tag | Environment | What it's good for | What it can't tell you |
|---|---|---|---|
| **automated** | CI (`flutter analyze` + `flutter test`, GitHub Actions) | Pure Dart/widget-test-layer logic — already covers atomicity, ownership, classification, pagination-dedup, and now the v1→v2→v3 migration SQL path itself | Nothing about real Android OS behavior — no real process lifecycle, no real storage layer, no real network radios, no real OEM behavior |
| **emulator** | Android Studio AVD. Recommend at least two images: one at **API 26** (validates CLAUDE.md's declared floor specifically, given Finding 1 above) and one at a recent API (parity with Galaxy Z Flip5-class hardware) | Fast iteration, scriptable network conditions (airplane mode, bandwidth/latency profiles via extended controls or `adb`), virtual biometric enrollment (`adb -e emu finger touch <finger_id>`), reproducible force-kill (`adb shell am force-stop`) | Real GPU/CPU performance ceiling (an emulator on a dev machine is not a 2GB-RAM MediaTek chipset), real OEM background-process killing (ColorOS's is notably aggressive — no emulator reproduces this), real radio handoff between WiFi and cellular, real low-storage pressure, real fingerprint sensor timing/UX |
| **physical-device** | OPPO A3s 2/16GB (Android 8.1, MediaTek Helio A22-class) as the low-end floor; a higher-end device (Galaxy Z Flip5 per CLAUDE.md §9) for contrast | Everything the emulator can't — this is the device the "Mode Hemat Energi" verification and OEM-kill scenarios exist specifically for | Fast iteration — every physical-device cycle costs real install/uninstall time |
| **build-artifact** | No device needed — inspecting the build output itself (APK size, manifest merge result, `flutter build apk --release --analyze-size`) | Cheap, no device dependency, catches config regressions early | Nothing about runtime behavior |

## 3. Full test matrix

Baseline items (A1–H19) reproduced from `docs/offline-integration-001-qa-report.md`
§3, each now tagged. New items (I–L) close gaps identified in §0/§1 and by
re-reading OFFLINE-001/002/003 and the migration work against what §2's
environment table shows automation still can't reach.

### A. Offline → online transition

| # | Test | Env | Pass criteria |
|---|---|---|---|
| A1 | Airplane Mode on, record 3 transactions (mix Wajib/Keinginan, one via "Tambah Lagi") | emulator, physical-device | Each lands instantly with "Belum tersinkron"; no network spinner |
| A2 | While offline, scroll Rekap past page 1 | emulator, physical-device | No duplicate rows (dedup logic is automated-tested; this confirms it holds under real scroll timing) |
| A3 | Airplane Mode off | emulator, physical-device | All badges clear within seconds, no user action needed; Supabase shows matching ids |
| A4 | Watch Rekap live through the A3→A1 reconnect while scrolled past page 1 | emulator, physical-device | No duplicate appears as items transition pending→synced |

### B. Force-kill / restart recovery

| # | Test | Env | Pass criteria |
|---|---|---|---|
| B5 | Record offline, force-kill (not background) before reconnecting, relaunch online | emulator, physical-device | Transaction still pending on relaunch, syncs without action |
| B6 | Record online, force-kill within ~1s of tapping "Oke, Catat" | emulator, physical-device | Exactly one row lands server-side — explicitly diff Supabase for a duplicate (different id, same amount/category/date) |
| B7 | Repeat B6 five-plus times in a row | emulator, physical-device | No duplicates, nothing stuck permanently unresolved |

### C. Sync recovery / retry

| # | Test | Env | Pass criteria |
|---|---|---|---|
| C8 | Record offline, stay offline several minutes, reconnect | emulator, physical-device | Syncs correctly — offline time doesn't burn retry budget |
| C9 | Weak-signal/flaky connection (emulator: throttled network profile; physical: real weak-signal area) | emulator, physical-device | Badge stays "Belum tersinkron" through retries, clears once it lands; no false "Gagal disinkron" |

### D. Duplicate prevention

| # | Test | Env | Pass criteria |
|---|---|---|---|
| D10 | Online: two identical (category/amount/date) entries back to back | automated (`hasPossibleDuplicate` logic already unit-adjacent via repository), emulator for the actual dialog UX | Soft "Transaksi mirip nih" dialog appears on the second |
| D11 | Offline: repeat D10 | emulator, physical-device | No dialog (documented limitation, OFFLINE-INTEGRATION-001 Finding 3 — confirm it isn't mistakenly reported as a bug); both entries land as separate legitimate rows once synced |

### E. FAILED → manual retry

| # | Test | Env | Pass criteria |
|---|---|---|---|
| E12 | Force a permanent failure (RLS/session issue), confirm "Gagal disinkron", tap it | emulator, physical-device | Moves back to "Belum tersinkron", fresh sync attempt fires, eventually lands once the underlying condition clears |

### F. Logout/login ownership isolation

| # | Test | Env | Pass criteria |
|---|---|---|---|
| F13 | User A records 2 offline (unsynced), signs out immediately | emulator, physical-device | User B (same device) sees none of A's transactions, not even a momentary flash |
| F14 | Sign back in as A (still offline) | emulator, physical-device | A's 2 transactions still there, still pending, sync normally once reconnected |
| F15 | Repeat F13–F14 with a force-kill between sign-out and next sign-in (no background/foreground cycle) — probes OFFLINE-INTEGRATION-001 Finding 4 | emulator, physical-device | No cross-user data leak; stale-lease recovery may lag until next resume, but ownership itself must never be violated |

### G. Release APK networking

| # | Test | Env | Pass criteria |
|---|---|---|---|
| G16 | Build a **release** APK (`flutter build apk --release`), fresh install, repeat a representative subset of A–C | emulator, physical-device | Identical behavior to debug build; specifically confirm no `MissingPluginException`/permission-denied errors debug wouldn't have surfaced (the ANDROID-001 class of bug). Remember: debug-signed per §1 finding 2 — this validates release *build* behavior, not store-distribution readiness |

### H. OPPO A3s "Mode Hemat Energi" verification

| # | Test | Env | Pass criteria |
|---|---|---|---|
| H17 | Mode Hemat Energi **off**: scroll Rekap, open the filter sheet (glass surfaces) | physical-device only (OPPO A3s specifically) | Judgment call — note whether it stutters |
| H18 | Mode Hemat Energi **on**: repeat H17 | physical-device only | Blur replaced with solid+opacity; noticeably smoother than H17 — this is the concrete verification CLAUDE.md requires on this exact device, not assumed from other hardware |
| H19 | Either Mode Hemat Energi state: run section A end to end on this device | physical-device only | Sync pipeline behaves identically to higher-end hardware — this device is the CPU/RAM floor, not a correctness floor |

### I. Migration & app-update (new — closes the device-level gap DRIFT-MIGRATION-001 doesn't reach)

Fixture-level migration tests (`test/kirain_database_migration_test.dart`)
prove the SQL migration logic is correct. They cannot prove that Android's
own APK-update mechanism actually preserves the app's private storage
(where the SQLite file lives) rather than, say, a signing-mismatch forcing
an uninstall/reinstall that would silently wipe local data.

| # | Test | Env | Pass criteria |
|---|---|---|---|
| I20 | Install a build, record 2-3 transactions (leave at least one unsynced/offline), install a newer build **over** it (not uninstall first) | emulator, physical-device | App data (local queue + any pending badges) survives the update untouched — confirms Android's update-in-place semantics hold for this app's actual storage location, not just what the Drift-level tests assume |
| I21 | Same as I20, but specifically confirm the migration itself: verify (via the app's own UI, not raw DB inspection) that pre-update pending transactions still show and still sync correctly post-update | emulator, physical-device | No data loss, no duplicate, no stuck pending item introduced by the update itself |

### J. Low-memory & OEM background management (new — physical-only, emulators don't reproduce this)

The OPPO A3s's 2GB RAM plus ColorOS's aggressive background-process
management is a materially different risk than the "force-kill" scenarios
in §B, which are *user*-initiated. This is the OS killing the app
*without* the user asking it to, mid-sync, which is a distinct crash-
recovery path worth exercising specifically because ColorOS's task-killer
is notably more aggressive than stock Android or an emulator's default
behavior.

| # | Test | Env | Pass criteria |
|---|---|---|---|
| J22 | On the OPPO A3s: record a transaction, switch away to 4-5 other memory-heavy apps (camera, browser, a game) without returning to KIRAIN, then return | physical-device only | KIRAIN either survives in the background or, if the OS killed it, relaunches cleanly with all data intact (same pass criteria as force-kill, but via real OS memory pressure, not `adb`) |
| J23 | Repeat J22 specifically with an unsynced offline transaction pending at the moment of backgrounding | physical-device only | The pending transaction is neither lost nor duplicated on return |

### K. Hardware & environment variance (new)

| # | Test | Env | Pass criteria |
|---|---|---|---|
| K24 | App Lock: **first confirm the OPPO A3s unit actually has a working fingerprint sensor** (§1 finding 5), then enable biometric lock and unlock | physical-device (hardware-dependent) | Biometric prompt appears and unlocks correctly on real hardware |
| K25 | App Lock biometric flow, virtual sensor | emulator (`adb -e emu finger touch 1`, requires an AVD with fingerprint configured) | Same flow succeeds on virtual hardware — useful as a faster, repeatable proxy once K24 has confirmed real-hardware behavior once |
| K26 | App shortcut (long-press launcher icon → "Catat Transaksi") | emulator, physical-device | Launches straight into Catat |
| K27 | Home-screen widget: add to home screen, confirm it shows current budget summary, tap its Catat button | emulator, physical-device | Widget renders correct data, tapping launches straight into Catat (per `home_widget_sync.dart` / `KirainWidgetProvider.kt`) |
| K28 | Network radio handoff: start a sync on WiFi, physically move out of WiFi range onto mobile data mid-sync | physical-device only (emulator can toggle airplane mode but can't reproduce a real WiFi→cellular handoff) | Sync either completes or cleanly retries after the handoff — no stuck/corrupted state |
| K29 | Real low-storage pressure — the OPPO A3s only has 16GB total, plausibly near-full with OS + bundled apps in practice | physical-device only | App installs and functions under genuine constrained free space, not a simulated low-storage condition |

### L. Build & release artifact checks (new — build-artifact tag, no device needed)

| # | Test | Env | Pass criteria |
|---|---|---|---|
| L30 | `flutter build apk --release --analyze-size` | build-artifact | Final APK under CLAUDE.md's 30–50MB target |
| L31 | Inspect the merged release manifest (`flutter build apk --release` then check `build/app/outputs/.../AndroidManifest.xml` or `aapt dump badging`) | build-artifact | `INTERNET`/`USE_BIOMETRIC` present in the release-merged manifest, confirming ANDROID-001's fix holds — cheaper and faster than G16 for this specific regression, run it first |
| L32 | `minSdkVersion` sanity check against §1 finding 1 | build-artifact | Confirms current floor (24) vs. documented floor (26) — informational, not a blocker, just keeps the gap visible until it's deliberately closed |

## 4. Recommended execution order

1. **L30–L32** (build-artifact) — cheapest, no device time, catches config
   regressions before spending device time on anything else.
2. **Automated-adjacent items** (D10's underlying logic, all of §I's
   underlying migration correctness) are already covered by CI — skip
   re-deriving them, just confirm CI is green on the build being tested.
3. **Emulator pass** — everything tagged `emulator` above, both AVD images
   (API 26 floor + a recent-API image). Fast iteration; fix anything found
   here before spending physical-device time on the same bug.
4. **Physical-device pass, higher-end device first** (Galaxy Z Flip5 or
   equivalent) — catches anything emulator-specific that doesn't generalize,
   before the slower OPPO A3s pass.
5. **Physical-device pass, OPPO A3s** — full §H, §J, §K24, §K28, §K29 (the
   items with no emulator substitute at all), plus a spot-check of
   everything else that passed on the higher-end device.

## 5. What stays out of scope here

Per instruction: OFFLINE-INTEGRATION-001 Findings 3/4/6 are *exercised* by
this plan (D11, F15) to gather real evidence, but not *fixed* — any bug
they surface goes back to the Tech Lead as a new finding, not an
in-flight fix. Crashlytics, OFFLINE-004, and any UI feature work are
untouched. No merge — this document alone is the SPRINT-003 deliverable.
