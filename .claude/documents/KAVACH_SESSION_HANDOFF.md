# Kavach Hardening — Session Handoff

> Resume doc for a fresh session (no conversation memory). Both repos are COMMITTED (see §1). **Verify against the repo first** — run the two suites + `git log --oneline -3` before acting.

## 0. FIRST STEPS ON RESUME (do these before anything)

```bash
# App repo
cd /Users/Prabhu/Development/Projects/2-snabbit-runner-app/shared
./gradlew testDebugUnitTest --console=plain 2>&1 | grep -E "FAILED|BUILD"
cd .. && git status --short -- shared/ android/

# Plugin repo
cd /Users/Prabhu/Development/Projects/safety-kavach
./gradlew :shield:testDebugUnitTest --console=plain 2>&1 | grep -E "FAILED|BUILD"
git status --short && grep '^version' shield/build.gradle.kts
```

Expected: **app 1317 tests / 0 failures**, **plugin 23 tests / 0 failures**.

## 1. Repos & state (ALL COMMITTED as of handoff)

| Repo | Path | Branch | HEAD (this work) |
|---|---|---|---|
| App | `2-snabbit-runner-app` | `feat/kavach-kmp-integration` | `8172c1a3` "medium/low hardening + SOS-signal analytics batch" |
| Plugin | `safety-kavach` | `feat/kavach-kmp` | `ab09070` "0.1.5 — ML high-confidence gate…" |

- Both committed (NOT pushed). Working trees clean of source changes.
- Plugin `0.1.4` IS published to GitHub Packages; `ab09070` bumps to **`0.1.5` (committed, NOT yet published)**. App still pins `0.1.4` at `shared/build.gradle.kts:63,165`.
- `git log --oneline -3` in each repo confirms the HEADs above.

## 2. THE ONLY 2 PENDING ITEMS (both gated on publishing 0.1.5)

1. **RC plumbing** — in `shared/.../kavach/shield/data/ShieldConfigFactory.kt`, add:
   `mlConsecutiveFramesRequired = rc.getInt("expert_shield_ml_consecutive_frames", 3),`
   inside the `ShieldConfig` copy. References the 0.1.5 field `ShieldConfig.mlConsecutiveFramesRequired`, so it **cannot compile until the pin is 0.1.5**.
2. **Bump the pin** `shared/build.gradle.kts:63 + :165` from `0.1.4` → `0.1.5`, then run the full app suite against the published artifact.

**Sequence:** publish plugin 0.1.5 (GitHub Packages, `write:packages`) → bump pin → add RC plumbing → verify.

## 3. Plugin 0.1.5 payload (committed in safety-kavach ab09070; NOT yet published)

| Change | File | What |
|---|---|---|
| ML consecutive-frame gate | `ShieldDetectionPipeline.kt`, `ShieldConfig.kt`, `AndroidShieldController.kt`, `IosShieldController.kt` | Fire only after N consecutive AND-gate passes. Config `mlConsecutiveFramesRequired` (default 3). |
| Partials removed | `ShieldDetectionPipeline.kt`, `AndroidShieldController.kt`, `IosShieldController.kt` | `detection_evaluated` (~750/min noise) no longer emitted. |
| `restart()` fallback | `AndroidShieldController.kt` (`restartRecordingOrStart`) | Falls back to `start()` + emits `recording_scheduler_fallback_start` when scheduler wasn't running. |
| Suppression counters | `ShieldDetectionPipeline.kt` (near-miss), `AndroidShieldController.kt` (suppressed) | `ml_near_miss_count` on ML `sos_triggered`; `suppressed_signals` on terminal `sos_resolved` (denied/deescalated only). |
| Version | `shield/build.gradle.kts:12` | `0.1.5` |
| Tests | `shield/src/commonTest/.../ShieldDetectionPipelineTest.kt` (NEW) | 6 tests: consecutive gate + near-miss. |

## 4. App batch (committed in 8172c1a3)

C6 (`ShieldUploadCoordinator.kt` — delete .enc on both drop paths) · S3 (`SosCoordinator.kt` — compensating `denySoS()` on manual raise catch) · V1/V6 (`SafetyDataSourceImpl.kt` — `widgetName` gate + tests) · definition drift (`CurrentStateDto.kt` delegates to `asIntOrNull`, `ShieldLayerRestore.kt` uses `JobWidgetName.IN_PROGRESS`) · C1 (`JobKavachCoordinator.kt` — `expert_shield_arm_retry_exhausted`) · R2/R4 (`SafetyHomeViewModel.kt` + `SafetyHomeContract.kt` — SOS debounce + `sosInProgress` flag) · routes (`AnalyticsRoutesConfig.kt` — arm_retry_exhausted, api_skipped, degraded_mode, native_* incl. fallback_start). Plus V2 (`ShieldLayerRestore.kt` reconcile-down) and S1 (`SosCoordinator.kt` STATUS_PENDING edge guard).

## 5. Decisions locked (do NOT re-litigate)

- **Jobless SOS = NO Kavach layer** (no accel/ML/recording/FGS). Fixed via `isJobActive &&` at `AndroidShieldController.triggerSoS` (shipped in 0.1.4). Only confirmation notification shows. **Verified on device.**
- **R1 API-fail path:** keep best-effort ALERT (re-raise stays blocked; recovery is confirm/deny). NOT drop-to-IDLE.
- **ML high-confidence:** N consecutive frames, N from RC, default 3.
- **Partials:** stop emitting entirely (not throttle).
- **Recording restart:** start()-fallback + telemetry.
- **Suppression attach:** ML-initiated → `ml_near_miss_count` on `sos_triggered`; non-ML-while-ML-live → `suppressed_signals` on `sos_resolved`.
- **`AppErrorType.OTHER_ERROR`** for the SOS/activate transient — user said leave it.
- **`sos_visibility` fail-open** — only explicit `false` hides the SOS button.

## 6. Deferred (by user)

- **iOS** (not shipping): `isJobActive` gate parity, mic-from-ACCELEROMETER_ONLY, `!isJobActive` teardown on deny/deescalate, no `AppSosHost` mount, V5 (`startRecording` guard). One 0.1.x publish when iOS ships.
- **ML aggregate denominator** (broader per-session "how noisy") — the suppressed/near-miss counters are done; this separate broader stream is parked.
- **SOS-initiation rate cap (per-hour/day)** — user closed it; in-flight dedup was the ask, and it's done.

## 7. Everything else = DONE & GREEN

Critical (wrong-shape-200, S2) · Impl gaps (Glass/label-validation, degraded-mode event, KMP native telemetry collector, iOS SosPushEntry suspend, sos_visibility gate) · High (S1, V2, in-flight dedup) · Medium (C6, S3, V1/V6, drift; unbounded-await auto-fixed by refactor; S4 confirmed intentional) · Low (C1) · SOS-signal hardening R2–R6 · suppression visibility. ALL committed (app 8172c1a3, plugin ab09070).

## 8. Verify commands (per-item)

- Test result parity: both suites green (see §0).
- `git log --oneline -3` in each repo to confirm HEAD hasn't moved.
- After 0.1.5 publish: `./gradlew compileDebugKotlinAndroid` in app resolves `0.1.5` (fails with "Could not find com.safetykavach:shield:0.1.5" until published).
