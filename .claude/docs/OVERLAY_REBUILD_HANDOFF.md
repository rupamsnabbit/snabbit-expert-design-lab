# SNABBIT-RUNNER — New-Job Overlay REBUILD · Context Injection

> Paste as background context in a new session. Reimplementing the Android new-job overlay from scratch. Everything below is verified against the tree at HEAD `6455bbc2` (branch `job-v2-integration-adapter`) + uncommitted work, unless flagged.

## 0. GUARDRAILS (hard)
- Android-only Flutter app, runners/experts. Pkg `com.snabbit.runner`. State=`provider`/ChangeNotifier (**NO** Riverpod/Freezed). Shorebird code-push; Firebase RC runtime flags. Risky zones: bg-service/location/maps/notification/FCM.
- BUILD GATE (ONLINE, never `--offline`): `./android/gradlew -p android :shared:compileDebugKotlinAndroid :shared:testDebugUnitTest :shared:detekt :app:compileDebugKotlin`. No root `./gradlew`. `:app`-only change → `:app:compileDebugKotlin` suffices (transitively builds :shared main). FVM for Flutter.
- `assembleDebug`(=`flutter run`) builds :shared main+:app, NOT :shared tests. Manifest merge NOT compile-checked → validate edits w/ `:app:processDebugMainManifest`. detekt=:shared only, maxIssues:0, NO baseline (banned material3/`Color` import hard-fails; only `SnabbitScreen.kt` excluded). `:app` Kotlin=compile-checked only.
- **NEVER `dart format`** (repo pre-Dart-3.10 → whole-file churn). `dart analyze <file>` OK. iOS not locally compilable (koin klib broken) → keep `commonMain` pure, verify CI/Xcode.
- Git self-driven: advise cmds, don't run mutating/networked git. All overlay work is **uncommitted**.
- DO-NOT-PUSH (revert pre-commit): `globals.dart`(currentEnv→alphaEnv staging); `runner_http.dart`(fake new-job ~L343, currently commented); `runner_rt_data.dart`(TEST overlay force-flag `kDebugMode`, ~L71); `gradle.properties`(GH Pkgs PAT); `blocklist/di/BlockListModule.kt`(`FieldTestMockBlockListRepository`, real binding commented).
- Analytics: critical→CleverTap/Mixpanel only; debug telemetry→Coralogix via `MonitoringServiceHelper`. No silent catch (log via MonitoringServiceHelper / Crashlytics).

## 1. GOAL · DECISIONS · WHY-REBUILD
- **GOAL**: render the `RUNNER_NEW_JOB` card when a job is allocated, across 3 app states; Accept/Deny KMP-direct (needs baseUrl+token+location).
- **DECISION**: reimplement the Android overlay from scratch — current impl "not quite working". Root friction = single-activity coupling (below), not a bug in the KMP job UI or state transport (those work).
- **3-STATE MODEL — design against this**:
  - **FG** (app visible): show job **in-app**, NO draw-over window.
  - **BG-alive** (runner in another app, process alive): **draw-over** other apps.
  - **KILLED** (process dead): draw-over via **native FCM only**.
- **CORRECTED MODEL (key insight; corrects the prior handoff)**: the backend HIGH-pri **data** push is required **ONLY for KILLED**. FG + BG-alive are driven by the live app + `RunnerStateStore` → **NO push needed**. Prior doc over-generalized "needs a push" onto all states; that's wrong.
- **ROOT FRICTION (why it worked on `refactor/job-v2` but broke here)**: the "all feature UI → single activity" merge (`origin/expert-v2-shift-jobs`) **deleted the self-sufficient `JobActivity`** and moved the FG job UI into `ActiveJobOverlay` = the **overlay slot of the bottom-nav `home_shell` screen**, rendered ONLY inside `NavigationHostActivity` (NHA) in root-shell mode. Two coupling defects followed:
  - **(A)** FG job UI now needs a root-shell NHA already alive. Launcher FG branch `startActivity(NHA, REORDER_TO_FRONT|SINGLE_TOP)` **no-ops if none exists** (empty-backstack NHA `finish()`es) → nothing shows.
  - **(B)** Launcher decided FG/BG from `MainActivity` lifecycle, but w/ CMP home ON (default) the FG surface is NHA and MainActivity is **STOPPED behind it** → FG misread as BG → **drew over the live app**. → FIXED this session (AppForegroundTracker, §3).
- **LOCKED DECISIONS (this session)**:
  - FG detection = process-wide `AppForegroundTracker` (started-activity counter). NOT `ProcessLifecycleOwner` (not on classpath; adds androidx.startup manifest provider). NOT `ActivityManager` importance (fooled by app's own bg FGS).
  - baseUrl → `PreferenceStorage` (non-secret; avoids Tink/auth-crypto) for cold-start HTTP.
  - WS2 FG-guard on the native push hook (skip draw-over if FG).
  - (A) deferred: CMP home is default-ON so NHA is usually present in FG; (A) only bites after a terminal Flutter handoff finished NHA.
- **BACKEND BLOCKER (external, cannot build client-side)**: new-job push MUST be **data-only + `android.priority=high`**, `data={name:"NEW_JOB_ALLOCATION", job_id, envelope:<current_state JSON>}`. data-only → `onMessageReceived` fires when killed; high-pri → grants bg-FGS-start allowlist (API 31+). **Not sent yet** → KILLED overlay doesn't fire today (job push = notification+data hybrid → goes to tray → `onMessageReceived` never runs; tap → WS3 opens app in-app).
- **REBUILD DECISION 1 (open — the crux of the rebuild)**: FG job-surface strategy —
  - **Opt A** — keep single-activity: render job as `ActiveJobOverlay` in NHA root-shell home; make NHA always-present OR recreate-on-demand (seed `home_shell` on `NavigationController` + `EXTRA_ROOT_SHELL`) + AFT detection. Pro: matches "one activity". Con: coupled to `expert_cmp_home_screen_enabled` RC + nav bridge.
  - **Opt B** — standalone always-launchable job surface (`JobActivity`-style `ComponentActivity` hosting `JobScreen`), decoupled from home. Pro: self-sufficient, this is what WORKED on `refactor/job-v2`. Con: reintroduces a 2nd activity (fights "single activity by design").
  - **Opt C** — hybrid: keep the standalone draw-over `Service` (NJOS) for BG/killed (already decoupled), fix FG via A (or B for FG only).
  - Reference impl for Opt B: `git show refactor/job-v2:android/app/src/main/kotlin/com/snabbit/runner/job/JobActivity.kt` (161 lines, the working version) — **reproduced verbatim + annotated in Appendix A**.

## 2. CORE ARCHITECTURE
- Stack: Flutter(Dart) UI/orchestration + KMP `:shared` (commonMain/androidMain, Compose-MP) + Android host `:app`. DI=Koin (`getKoin().get<T>()`, `by inject()`; VMs host-constructed). Koin cold-started in `SnabbitRunnerApplication.onCreate→KmpBootstrap.initialize` (independent of Flutter); `hydrateAll()` restores bearer token cold (Tink).
- **State bridge (Dart→KMP, FWD)**: `RunnerRtDataProvider._fetchData→_publishRunnerState→RunnerStateChannel.pushState(json)→RunnerStatePlugin→RunnerStateStore.pushState(rawJson)→StateFlow<RunnerState?>`. REV: `store.requestRefresh→plugin→ch.invokeMethod("requestRefresh")→Dart _handleKmpRefreshRequest→fetch`. RC kill `expert_enable_publish_runner_state_to_kmp` (default ON). Transport today = Dart polling `current_state` (MQTT future via `RunnerStateSource` seam).
- **Surfaces by state** (current impl; rebuild per DECISION 1):
  - FG → `JobScreenLauncherPlugin.maybeLaunch` fronts NHA (REORDER_TO_FRONT|SINGLE_TOP) → `ActiveJobOverlay` renders `JobScreen` over the bottom-nav tabs.
  - BG-alive → `startForegroundService(NewJobOverlayService)` (draw-over `TYPE_APPLICATION_OVERLAY` + `FLAG_DIM_BEHIND`, specialUse FGS). Gated: `overlayEnabled` (RC, default OFF, debug force-ON) `&& canDrawOverlays && OverlayService.instance==null`.
  - KILLED → `SnabbitPushService.onMessageReceived` (native FCM hook; needs backend push).
- **Cold overlay data flow**: FCM data push → `SnabbitPushService` seeds `RunnerStateStore.pushState(envelope)` → `startForegroundService(NJOS)` → builds KMP `JobViewModel` from Koin off `RunnerStateSource`(→RSS) → renders `NewJobOverlaySurface`; Accept → `JobActionRepository` (KMP HTTP).
- **KEEP (works — reuse, don't rebuild)**: KMP job module (JobViewModel/JobScreen/JobContract, RunnerStateSource, JobActionRepository) · RunnerStateStore + bridge (RunnerStatePlugin, RunnerStateChannel, Dart publish) · NetworkConfigStore + WS1 baseUrl persist · AppForegroundTracker · OverlayLifecycleOwner (Compose-in-service) · NewJobOverlaySurface/Content (KMP UI) · channels · WS3 tap route.
- **REBUILD/RECONSIDER**: FG surface strategy (AJO⊂NHA coupling) · JobScreenLauncherPlugin FG/BG router · SnabbitPushService killed-path (draw-over vs full-screen-intent notification).
- **CRUFT (delete)**: `JobActivity.kt` (already deleted/empty).

## 3. CRITICAL LOGIC & CODE (pseudo)
```kotlin
// ── 3-STATE DECISION (corrected). state arrives in RSS (Dart publish OR native seed) ──
onNewJobState(stage):
  if !isKmpStage(stage): resetGuards(); return
  if AppForegroundTracker.isForeground:                       // FIX(B): ANY Activity STARTED, not MainActivity RESUMED
      surfaceInApp()                                          // FG: front NHA root-shell → AJO renders  [DECISION-1 if NHA absent]
  else if stage==NEW_JOB && overlayEnabled                    // RC default OFF; debug kDebugMode force-ON
        && canDrawOverlays && OverlayService.instance==null:  // AWOL not already overlaying
      startForegroundService(NewJobOverlayService)            // BG-alive draw-over
  // KILLED handled only by SnabbitPushService below (no live plugin/activity)

// ── AppForegroundTracker  [APP/AppForegroundTracker.kt]  KEEP ──
object AppForegroundTracker : Application.ActivityLifecycleCallbacks {
  val started = AtomicInteger(0)
  val isForeground get() = started.get() > 0                  // thread-safe read (FCM binder thread)
  onActivityStarted { started.incrementAndGet() }
  onActivityStopped { started.updateAndGet { if (it>0) it-1 else 0 } }   // guard negative
}
// registered: SnabbitRunnerApplication.onCreate → registerActivityLifecycleCallbacks(AppForegroundTracker)
// WHY not ProcessLifecycleOwner (not on cp + startup manifest provider) / ActivityManager importance (bg FGS → false-FG)

// ── SnabbitPushService (native FCM entry)  [APP/push/SnabbitPushService.kt]  KILLED path ──
: FlutterFirebaseMessagingService(), KoinComponent
val rss: RunnerStateStore by inject()
onMessageReceived(m):
  if fromCleverTap: CleverTapAPI.pushNotificationViewedEvent(extras)
  if m.data["name"]=="NEW_JOB_ALLOCATION":
    try:
      seedNewJobState(m.data)                                 // UNCONDITIONAL: feeds BOTH surfaces off one store
      if !AppForegroundTracker.isForeground:                  // WS2 FG-GUARD: skip draw-over when FG (in-app handles)
        startForegroundService(NJOS, extra=EXTRA_SERVICE_ID?)
    catch: Log.e(...)                                          // FGS refused / Koin fail-open → notification fallback
  super.onMessageReceived(m)                                  // ALWAYS → Dart cache/notif path
seedNewJobState(d): env = d["envelope"] ?: d["job_id"]?.let{ """{"widget_name":"RUNNER_NEW_JOB","widget_data":{"job_id":$it}}""" }; if(env) rss.pushState(env)

// ── NewJobOverlayService (draw-over host)  [APP/job/overlay/NewJobOverlayService.kt]  KEEP ──
Service (specialUse FGS via ServiceCompat.startForeground, type SPECIAL_USE)
onStartCommand: if(overlayView==null) showOverlay(); return START_NOT_STICKY    // single-window / idempotent (safe double-start)
showOverlay: vm = JobViewModel(source=RunnerStateSource→RSS, actions=JobActionRepository, location, clock, blockList, prefStorage, actionStore, serviceId, scope, actionScope)
  window = TYPE_APPLICATION_OVERLAY + FLAG_DIM_BEHIND (dim .5), Compose via OverlayLifecycleOwner + MaterialTheme{ NewJobOverlaySurface }
  self-dismiss when uiState leaves NewJob/Loading; onAccept: vm.Accept on process-lived actionScope + bringAppToForeground + dismiss
  addView catch SecurityException (SAW revoked TOCTOU) → stopSelf → notification fallback

// ── WS1 baseUrl cold-persist  [SH_C/core/network/NetworkConfigStore.kt]  KEEP ──
pushNetworkConfig(base,ver): _config.value=NetworkConfig(base,ver); if(base && store) persistScope.launch{ store.putString("net_base_url",base); putString("net_version_code",ver) }
suspend seedFromCache(): if(_config.value!=null||store==null) return; base=store.getString("net_base_url")?:return; _config.value=NetworkConfig(base, ver?:"")
suspend awaitReady() = _config.first{ it!=null && it.baseUrl.isNotBlank() }   // HTTP gate
// KmpBootstrap hydrate (Dispatchers.IO): + getKoin().get<NetworkConfigStore>().seedFromCache()  [after StoreManager.hydrateAll()]
```
- **ENVELOPE CONTRACT**: `{"widget_name":"RUNNER_NEW_JOB","widget_data":{"job_id":N,...}}`. `job_id` REQUIRED (accept/deny reads `state.widgetData["job_id"]`). `RunnerStateStore.pushState` never throws (logs decode fail). StateFlow replays latest → seed-before-start safe.
- **COUPLING TRAP (must resolve in rebuild)**: `ActiveJobOverlay()` bound ONLY in `BottomNavScreenModule` (home_shell overlay slot). NHA root-shell requires `EXTRA_ROOT_SHELL` + a non-empty `NavigationController.backStack` (empty → `finish()`). Entry = `NavigationBridgePlugin.openNativeDestination("home_shell")` (called from `partner_home.dart` on mount when `expert_cmp_home_screen_enabled` ON). A bare `startActivity(NHA)` w/o these → finishes → no UI.

## 4. STATE & APIs
- **Schema**: `RunnerState(@SerialName("widget_name") widgetName:String?, @SerialName("widget_data") widgetData:JsonObject?)` [SH_C/core/runnerstate]. `NetworkConfig(baseUrl, versionCode)`. Stages: `RUNNER_NEW_JOB | RUNNER_JOB_POST_ACCEPT | RUNNER_JOB_CHECK_IN | RUNNER_JOB_IN_PROGRESS | RUNNER_POST_CHECKOUT`.
- **State mgmt**: Koin singles `RunnerStateStore`, `NetworkConfigStore`, `StoreManager`(Tink `bearer_token`), `JobActionStore`, `JobServiceIdHolder`. Dart=`provider` (`RunnerRtDataProvider` polls `current_state` = source of truth). PrefStorage keys (DataStore `snabbit_preference_storage`, **unencrypted**): `net_base_url`, `net_version_code`.
- **RC flags**: `expert_enable_new_job_overlay` (default **OFF**; Dart pushes via `job_overlay` ch; debug force-ON via `runner_rt_data` `kDebugMode||RC`). `expert_cmp_home_screen_enabled` (default **ON** — gates NHA root-shell home). `expert_enable_publish_runner_state_to_kmp` (default ON).
- **MethodChannels** `com.snabbit.runner/…`: `job_overlay`(setOverlayEnabled, setServiceId) · `runner_state`(pushState, requestRefresh) · `network_config`(pushConfig).
- **Endpoints** (base staging `maestro-core.stg.snabbit.net`): `POST /api/v1/jobs/{jobId}/accept_job` body `{job_id, location?}` (location effectively REQUIRED → 400 "Runner is not on duty" if off-duty/missing) · `GET .../runners/{app_config,me}` · `current_state` (feeds RSS) · `internationalization_file/ENGLISH`. Known: `GET .../jobs/kmp/task_collection→404` (backend/deploy, not client); `POST /atlas-iot/api/v1/iot→403` pre-existing.
- **FCM contract**: data-only + `android.priority=high` (WHY in §1). Current job pushes appear notification+data hybrid → killed→tray, `onMessageReceived` NOT invoked → backend change required. `NEW_JOB_ALLOCATION` already carries `data["name"]` (Dart `isJobAllocationNew` main.dart:1049; WS3 tap notification_service.dart:167).
- **Cold facts**: token cold-safe (hydrated). baseUrl cold via WS1 `seedFromCache`. `JobActionRepository` hard-needs baseUrl seed; `RunnerStateSource` needs RSS seed; others (Clock/Store/PrefStorage/BlockList-mock/Location) OK cold.

## 5. STRUCTURAL MAP  (KEEP / REBUILD / CRUFT)
prefix SH_C=`shared/src/commonMain/.../shared` · SH_A=`shared/src/androidMain/.../shared` · APP=`android/app/src/main/kotlin/com/snabbit/runner`
- **KEEP**
  - `SH_C/features/job/presentation/{JobViewModel,JobScreen,JobContract}.kt`, `.../newjob/{NewJobOverlaySurface,NewJobOverlayContent}.kt` — stage-agnostic MVI + overlay UI, reused by ALL surfaces.
  - `SH_C/features/job/{data/state/RunnerStateSource(→BridgeRunnerStateSource), domain/repository/JobActionRepository, data/{JobActionStore,JobServiceIdHolder,LocationProvider}, domain/JobClock, di/JobModule}.kt`.
  - `SH_C/core/runnerstate/RunnerStateStore.kt` — `StateFlow<RunnerState?>`; pushState/snapshot/requestRefresh; never throws.
  - `SH_C/core/network/NetworkConfigStore.kt` — baseUrl gate + WS1 persist+seedFromCache. `SnabbitHttpClientImpl.execute→awaitReady()`.
  - `APP/kmp_bridge/RunnerStatePlugin.kt` — Dart↔KMP state bridge (on MainActivity).
  - `APP/job/overlay/NewJobOverlayService.kt` — standalone draw-over FGS host (Compose-in-service). Decoupled → works for BG/killed.
  - `APP/AppForegroundTracker.kt` — process FG primitive (untracked/new).
  - `APP/compose_overlay/service/OverlayLifecycleOwner.kt` — Compose-in-service lifecycle (reused by NJOS + AWOL).
  - `APP/job/JobScreenExtras.kt` — intent-extra keys (EXTRA_SERVICE_ID, JobStrings).
  - `SH_A/core/KmpBootstrap.kt` — cold Koin+hydrate+baseUrl seed. `APP/SnabbitRunnerApplication.kt` — calls it + registers AppForegroundTracker.
- **REBUILD / RECONSIDER**
  - `APP/kmp_bridge/JobScreenLauncherPlugin.kt` — FG/BG router. FG branch (`REORDER_TO_FRONT` NHA) = the coupling. Rebuild per DECISION 1. (FIX(B) already applied: uses `AppForegroundTracker.isForeground`.)
  - `APP/push/SnabbitPushService.kt` — killed-path FCM hook (WS2 + FG-guard). Works but gated on backend push; reconsider draw-over vs full-screen-intent.
  - `SH_A/features/bottomnav/ActiveJobOverlay.kt` (bound in `BottomNavScreenModule` overlay slot) — FG surface, coupled to NHA root-shell.
  - `APP/navigation/NavigationHostActivity.kt` + `navigation/bridge/NavigationBridgePlugin.kt` — root-shell home; NHA renders `controller.backStack`, finishes on empty; launched via `openNativeDestination("home_shell")` + `EXTRA_ROOT_SHELL`.
- **CRUFT**: `APP/job/JobActivity.kt` (DELETED; refactor/job-v2 version = Opt B reference — **Appendix A**). NOTE: only the file itself was deleted — its `job`-package collaborators `AndroidTtsController.kt` + `JobScreenExtras.kt` survived, so re-adding it compiles on HEAD (verified 2026-07-14).
- **Dart**: `lib/providers/runner_rt_data.dart` (poll current_state → publish RSS → push overlay flag; `_pushNewJobOverlayFlag` L66) · `lib/services/{runner_state_channel,network_config_channel,job_overlay_channel,notification_service}.dart` · `lib/main.dart` (bg FCM handler name-switch ~L328/L846+, `isJobAllocationNew` L1049).
- Deep-dive docs on disk: `.claude/docs/NEW_JOB_OVERLAY.md` (Phase A detail), `.claude/docs/RUNNER_STATE_BRIDGE.md` (bridge detail).

## VERIFY (after rebuild)
- Gate §0 + `:app:processDebugMainManifest` (manifest not compile-checked) + `dart analyze <touched>`.
- On-device E2E: revert DO-NOT-PUSH or re-enable the `runner_http` fake; grant "Display over other apps"; then
  - **FG**: app open, trigger job → shows in-app, **NO draw-over**.
  - **BG-alive**: background into YouTube, trigger job → draw-over appears over YouTube.
  - **KILLED**: `adb shell am force-stop com.snabbit.runner`; send data-only HIGH-pri FCM `{name:NEW_JOB_ALLOCATION, job_id, envelope}`; logcat `NewJobOverlayService`/`JobScreenLauncher`.

## Appendix A — Opt-B reference: `JobActivity.kt` (verbatim, from `refactor/job-v2`)
The self-sufficient FG surface that **worked pre-merge**. Opt B = re-add this (or a new-job-only trim of it). Read these before reusing:
- **Re-add, not re-derive**: verified 2026-07-14 — every symbol this file references still exists on HEAD. Only `JobActivity.kt` was deleted; its `job`-package neighbours `AndroidTtsController.kt` + `JobScreenExtras.kt` survived, and the contact/connectivity deps live in `:shared`. So pasting it back compiles (adjust only if you trim scope).
- **VM wiring is IDENTICAL to `NewJobOverlayService.showOverlay` (§3)**: same `getKoin().get<>()` dep set, same process-lived `actionScope` (`SupervisorJob()+Dispatchers.Main.immediate`) so accept/deny/rating POSTs survive `finish()`, same self-finish on `JobUiState.NotInJobFlow`. → the KEEP KMP pieces slot in unchanged; **only the host window differs** (ComponentActivity vs draw-over Service). This is why Opt B "just works": it reuses everything, decouples the host.
- **Decoupled launch** (fixes coupling defects A+B): `JobScreenLauncherPlugin` FG branch → `startActivity(JobActivity, extras)` — NO NHA root-shell / `EXTRA_ROOT_SHELL` / non-empty backstack precondition. FIX(B)'s `AppForegroundTracker.isForeground` still decides FG-vs-BG upstream.
- **Divergences to decide in the rebuild**:
  - *Scope*: this hosts the **FULL** flow (New→CheckIn→InProgress→Completed via `JobScreen` morph), so it pulls TTS (`AndroidTtsController`) + contact (`DefaultCustomerContactHandler`/`CallingDataSource`/`CustomerContactLauncher`/`ContactStrings`) + `NetworkMonitor`/`LocalConnectivityStatus`. A **new-job-only** FG surface (matching NJOS, which self-dismisses when leaving NewJob/Loading) can drop TTS + contact.
  - *Back* = `moveTaskToBack(true)` (lock into job flow), NOT finish; registered before `setContent` so sheet back-handlers outrank it.
  - *i18n + serviceId* arrive via intent extras (`JobScreenExtras.stringsFrom/serviceIdFrom`).

```kotlin
package com.snabbit.runner.job

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.lifecycleScope
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.core.connectivity.LocalConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.presentation.contact.ContactStrings
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import com.snabbit.runner.shared.features.job.presentation.contact.DefaultCustomerContactHandler
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.presentation.JobScreen
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.JobViewModel
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import org.koin.mp.KoinPlatform.getKoin

/**
 * Native host for the Compose Multiplatform Job screen. Launched by
 * [com.snabbit.runner.kmp_bridge.JobScreenLauncherPlugin] when `current_state` enters
 * `RUNNER_NEW_JOB` (observed off the bridged RunnerStateStore).
 *
 * State comes from the bridged `RunnerStateStore` (via `RunnerStateSource`, a Koin
 * single); job actions go KMP-direct via `JobActionRepository`. `JobScreen` renders the
 * KMP-hosted stages — **New Job → Check-In → In-Progress → Completed** — and morphs between
 * them as the polled envelope advances (no re-launch). This Activity **finishes itself once
 * the runner leaves the job flow** (a non-job / attendance state), handing back to Flutter —
 * which polls the same state — for the downstream lifecycle.
 *
 * i18n labels arrive as Intent extras (default to the English fallbacks).
 */
class JobActivity : ComponentActivity() {

    // Read-aloud engine for the check-in navigation card's "Listen" pill; released in onDestroy.
    private lateinit var tts: AndroidTtsController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Lock the runner into the job flow: while this Activity is up, device back never drops to
        // Flutter/home. Registered BEFORE setContent so the sheets' own back handlers (SnabbitBottomSheet
        // — dismiss, or consume when forced) are composed later and outrank this. With no sheet open,
        // back backgrounds the app (the job stays live; a poll / the overlay bring it back). The Activity
        // itself only leaves the flow via the state stream (NotInJobFlow → finish()).
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                moveTaskToBack(true)
            }
        })

        val strings = JobScreenExtras.stringsFrom(intent)

        // Platform TTS for the check-in nav card's "Listen" pill (host bridge, like location).
        tts = AndroidTtsController(this)

        val viewModel = JobViewModel(
            source = getKoin().get<RunnerStateSource>(),
            actions = getKoin().get<JobActionRepository>(),
            location = getKoin().get<LocationProvider>(),
            clock = getKoin().get<JobClock>(),
            blockListDataSource = getKoin().get<BlockListRepository>(),
            preferenceStorage = getKoin().get<PreferenceStorage>(),
            // Shared accept/deny store (process single) — an accept begun on the overlay is still
            // in-flight here, so the New-Job Accept shows loading instead of re-arming (ECPO #1).
            actionStore = getKoin().get<JobActionStore>(),
            strings = strings,
            scope = lifecycleScope,
            // Job action POSTs (accept / deny / customer rating) run on a process-lived scope so an
            // in-flight call survives this Activity finishing when the runner leaves the job flow —
            // notably the rating POST when the Completed screen auto-dismisses (ECPO-760).
            actionScope = actionScope,
            serviceId = JobScreenExtras.serviceIdFrom(intent),
        )

        // Customer contact actions for the check-in + in-progress screens. Without a real handler
        // JobScreen falls back to a no-op and Call/Map do nothing; wire the masked-call data source
        // + platform launcher here (chat intentionally omitted — feature disabled). Feedback
        // ("Call initiated") is surfaced by JobScreen's snackbar.
        val contact = DefaultCustomerContactHandler(
            calling = getKoin().get<CallingDataSource>(),
            launcher = getKoin().get<CustomerContactLauncher>(),
            strings = ContactStrings(),
            scope = lifecycleScope,
        )

        // Stay up for all KMP-hosted job stages (New Job → Check-In → In-Progress → Completed) so
        // JobScreen can morph between them as `current_state` advances. `Loading` is the cold-mount
        // tick (ignored). Once the runner leaves the job flow (`NotInJobFlow` — attendance / a
        // non-job state), finish and let Flutter — polling the same `current_state` — take over.
        viewModel.uiState
            .onEach { state ->
                when (state) {
                    is JobUiState.NewJob,
                    is JobUiState.AwaitingCheckIn,
                    is JobUiState.InProgress,
                    is JobUiState.Completed,
                    JobUiState.Loading -> Unit
                    JobUiState.NotInJobFlow -> finish()
                }
            }
            .launchIn(lifecycleScope)

        // Block-success confirmation as a PLATFORM toast (applicationContext), not a Compose toast in
        // JobScreen: blocking is the last action before "Ready for next job" → finish(), which would tear
        // a Compose toast down before it's seen. An OS toast is screen-independent and survives (ECPO #10).
        viewModel.blockedToast
            .onEach { Toast.makeText(applicationContext, strings.customerBlockedToast, Toast.LENGTH_SHORT).show() }
            .launchIn(lifecycleScope)

        // Device connectivity monitor (Koin single) resolved here so the composition stays
        // Koin-free (mirrors the ViewModel / contact-handler wiring above).
        val networkMonitor = getKoin().get<NetworkMonitor>()

        setContent {
            MaterialTheme {
                // Feed device connectivity into the tree so SnabbitActionFooter's baked-in banner
                // ("No/Bad internet") reflects real network state. The monitor's WhileSubscribed
                // means its network callback is held only while this screen is on-screen.
                val connectivity by networkMonitor.status.collectAsState()
                CompositionLocalProvider(LocalConnectivityStatus provides connectivity) {
                    JobScreen(viewModel = viewModel, strings = strings, contact = contact, tts = tts)
                }
            }
        }
    }

    override fun onDestroy() {
        // Release the native TTS engine with the screen.
        if (::tts.isInitialized) tts.shutdown()
        super.onDestroy()
    }

    private companion object {
        /**
         * Process-lived scope for job action network POSTs (accept / deny / customer rating) so an
         * in-flight call survives this Activity finishing when the runner leaves the job flow
         * (`NotInJobFlow` → [finish], which cancels [lifecycleScope]). Notably the customer-rating
         * POST must still land when the Completed screen auto-dismisses (ECPO-760). Finite
         * fire-and-forget tasks — deliberately never cancelled. Mirrors `NewJobOverlayService`.
         */
        private val actionScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }
}
```
