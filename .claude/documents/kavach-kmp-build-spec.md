---
title: Kavach KMP Completion — Build Spec (autonomous run)
purpose: Grounded, per-increment build spec for closing all doable KMP/CMP pending work. Anchors a multi-window autonomous run. KMP/CMP-only — NO Dart, NO Flutter MethodChannel, NO host bridge.
grounded: workflow wf_60c71454-625 (8 agents) — plugin contract + §12/§16 + enablement/consent/perms + analytics/push/sync + Step8 UI + Step9 IG + web-tech + :shared patterns. Full output: tasks/wf82gtcmi.output.
mode: self-resolve high-confidence, no halts, no over-engineering, KMP-first.
---

# RUN STATUS (autonomous, 2026-07-10)
- ✅ **2a** event routing + IG analytics (Step 9) — `ShieldEventRouter` + IG-07/08/10/11 + error. Verified.
- ✅ **2b** lifecycle seam + foreground→reconcile (§16 core) — `AppLifecycle` expect/actual + `ShieldForegroundReconciler`. Verified.
- ✅ **2c** consent POST hard-gate (D-5) — `ShieldConsentApi(Impl)` + `activate()` gate + consent analytics. Verified.
- ✅ **2e** deterrence audio — `DeterrenceCoordinator` (SOS-active→RC-delay→play→`expert_shield_deterrence_played`, cancel on leave) + `DeterrenceAudioPlayer` seam: Android MediaPlayer+AudioManager USAGE_ALARM w/ **C13 volume-restore fix**; iOS AVAudioPlayer+AVAudioSession `.playback`/`.duckOthers` (NO system-volume force — verified no public iOS API). mp3→composeResources. 4 tests. Verified (JVM + iosArm64). **Web-verified (official Android/Apple docs) + 2/2 adversarial on both load-bearing claims.**
- Every increment: `:shared:testDebugUnitTest` (full suite) + `:shared:compileKotlinIosArm64` green. KMP/CMP-only, no Dart.
- ⛔ **REMAINING work is NOT high-confidence-autonomous** — each needs a USER DECISION (workflow-classified, file-level evidence):
  - **HOST-CONTEXT-dependent** (need the *excluded* host bridge feeding jobId + job widget_data): §12 manual-promotion+persist; §16 expected_layer restore; auto-start enablement branch; upload `currentJobId` wiring. `KavachModule.kt:75 currentJobId={null}`.
  - **DEVICE-verification-required** (no full Xcode here, per MEMORY ios_native_test_run_env): 2f permissions UX; Phase 4 UI screens (+ missing DS dialog atom); Phase 6 Darwin engine (`KtorClient.ios.kt` throws) + iOS Koin bootstrap (absent).
  - **APPROVAL-gated**: serialization 1.9.0→1.11.0 (no driver; needs Kotlin 2.3.x; build.gradle.kts:71 no-unapproved-bump); Phase 7 data/ restructure (user said "wait for approval").

# §10 HOST-DATA MOCK (2026-07-10, user-directed) — ✅ DONE (verified: full JVM suite + iosArm64)
- Goal: KMP-only DTOs + gateways + mocks for `current_state` + `runner/me` + KMP-native RC → wire §10 enablement, verifiable without Flutter.
- Shipped (commonMain, all KMP/CMP, zero Dart): `RunnerMeDto`/`SafetyShieldDto`, `CurrentStateDto`/`ShieldWidgetSlice`(+`jobIdAsInt` coercion); `CurrentStateGateway`+`ShieldProfileGateway` (+`Default*` no-host fallbacks); `Canned*` seeded mocks; `CannedShieldRemoteConfigGateway` (seedable KMP RC, no plugin-default dup). `KavachDataSourceImpl.activate()` rewritten → consent-if-needed + §10 layer (present=partner∧customer → MONITORING_ONLY; autoStart=present∧auto∧jobId → +RECORDING+MONITORING; !present → ACCELEROMETER_ONLY floor). Envelope verified 2 sources: `safety_shield` at runners/me root.
- **BEHAVIOR CHANGE**: activate() is now enablement-gated. With `Default*` gateways (no host) → accelerometer-only floor; canned/fake → full ladder. More correct (§10 parity) but differs from the prior unconditional-ladder commit.
- Tests: `RunnerMeDtoTest`, `CurrentStateDtoTest`, `KavachDataSourceImplTest` gate table (7 activate cases) + `Fake{CurrentState,ShieldProfile}Gateway`.
- ⛔ DEFERRED / USER DECISIONS (R4): **A** prod data source — HTTP re-fetch (SosApiImpl-style, aligns with "no Flutter dep") vs Flutter-owned `RunnerStateStore` read (+ the `ShieldUploadCoordinator` sync `currentJobId` seam depends on this). **B** consent_version drift. Also: `:app` canned overlay for on-device run; expected-layer reconcile / manual-restore (host-context); who calls activate() on the job-start edge (host trigger).

# PURE-KMP DEFECT FIXES (2026-07-11, post-audit) — ✅ DONE (verified: full JVM suite + iosArm64)
- D1 upload coordinator eager (`createdAtStart`) + backlog `processQueue()` drain on start (was dead — init never ran, collector never attached). D2 background-aware auto-deny — `SosCoordinator` injects `AppLifecycle`, auto-deny only while foreground (backgrounded → stays ALERT for resume re-prompt; safety). D3 `KavachHomeScreen` renders `uiState.error` via DS snackbar (was invisible). D4 `job_id` attached to `/sos/initiate` from `CurrentStateGateway`. New tests + ctor updates across 5 test files.
- STILL pending after this (unchanged): Decision-A prod data source (currentJobId for uploads stays `{null}`), connectivity-drain (platform seam), coordinator analytics (~35 events), conditions() monitors (battery/disk seams), §12/§16 restore, permissions, iOS, Phase 7.

# Locked decisions (resolved forks)
- RC source = keep `DefaultRemoteConfigGateway` (plugin defaults); GitLive `dev.gitlive:firebase-config:2.4.0` = flagged future real-source (no native pod now).
- Killed-state = wire lifecycle→`SosCoordinator.reconcile()` (E3); DEFER `ShieldSosPushStore` (FCM writer is host/out-of-scope; reconcile is Flutter's own fallback).
- Lifecycle = new `core/lifecycle/AppLifecycle` expect/actual (Android `ProcessLifecycleOwner` via `lifecycle-process` [have]; iOS `NSNotificationCenter` app-state).
- Analytics = REUSE `core/analytics/AnalyticsTracker` (+ route table); inject + `track("expert_shield_*", props)`. iOS providers absent = flagged.
- IG-08/09 = catch `Throwable`→`expert_shield_error`; SKIP `serviceNotRunning` reinit-ladder (Flutter-channel artifact, no plugin 1:1).
- §16 persistence = `StoreManager` slot (reuse `EncryptedStore`), key `shield_manual_monitoring_active`.
- `data/` restructure = LAST (cosmetic; functional gaps first).
- serialization 1.9.0→1.11.0. coroutines stay 1.11.0 (built vs 2.2.20 — smoke-test). Koin 4.2.1.

# Plugin contract (safety-kavach, authoritative — agent 1)
- `ShieldController` (commonMain): 20 suspend fns + `shieldState`/`recordingState`/`monitoringState: StateFlow` + `events: SharedFlow<ShieldEvent>`.
- 6 `ShieldEvent`: EncryptedAudio(filePath,aesSecretKey,iv,authTag) · SoSTriggered(source,triggerType) · PermissionStatus(permission,status) [declared, NOT emitted by AndroidController] · Error(code,message,details?) · Instrumentation(eventName,props,timestamp) · NotificationAction(action,source,timestamp).
- SafetyState{IDLE,ACCELEROMETER_ONLY,MONITORING_ONLY,RECORDING_ONLY,MONITORING,SOS_PENDING,SOS_CONFIRMED}. RecordingState{IDLE,RECORDING,PAUSED}. MonitoringState{IDLE,ACTIVE,MONITORING_ONLY}.
- **Plugin drives ALL state**; app one-way reads StateFlows + issues intent via fns. NO job-id in contract (only no-arg onJobStarted/onJobEnded).
- **Invariant #4 CONFIRMED in plugin (Android)**: `doDenySoS` denyTarget=MONITORING if preSosState==MONITORING_ONLY; `doDeescalate` target=MONITORING if preSosState==MONITORING_ONLY. So app delegation to plugin previousState is CORRECT (no app PreSosSnapshot). iOS plugin = unconditional MONITORING (plugin's concern).
- Permissions seam = CHECK-ONLY; requestPermissions == checkPermissions (no dialog). App owns request UI.

# Phase 2 — Step 6 shield logic (KMP) — the trunk
Landing = `KavachDataSourceImpl` (adapter, OD-1) + `SosCoordinator` (domain) + new event-router + gateways. Reuse patterns (agent 8): `Foo`/`FooImpl` + `single<Foo>{FooImpl(dep=get())}`, named get(), best-effort (report+null, no throw), private Json, companion path consts, DTOs private @Serializable at bottom.

## 2a. Event routing + IG analytics (Step 6 routing + Step 9) — FIRST — ✅ DONE (verified: JVM tests + iosArm64 compile green)
- Shipped: `domain/ShieldEventRouter.kt` (eager Koin single, self-start, KMP-pure) → IG-07 started/resumed, IG-10 paused, IG-11 permission_changed, error. `KavachDataSourceImpl.activate()` try/catch → IG-08 `expert_shield_error` + rethrow. Route table already seeds all keys. Tests: `ShieldEventRouterTest` (6) + `KavachDataSourceImplTest` IG-08. Fakes: `FakeAnalyticsTracker`, `FakeShieldController.failOnInitialize` + mutable state flows.
- Deferred (flagged in router KDoc): `Instrumentation`→Plane-2 `expert_shield_native_*` (needs plugin eventName enum); `expert_shield_stopped` on job-end (2b).
- New `domain/ShieldEventRouter.kt` (Koin single, owns scope, injects `ShieldController`+`AnalyticsTracker`+`CurrentTimeMs`): collects `events` + `recordingState` StateFlow.
- recordingState.RECORDING → `expert_shield_started`/`_resumed` (IG-07; disambig via prior-was-paused) `{trigger,mode:"recording"}`; PAUSED → `expert_shield_paused` (IG-10) `{reason:"audio_interruption",mode:"recording"}`.
- events.PermissionStatus → `expert_shield_permission_changed` (IG-11) `{permission,status,context:"runtime_change"}`. events.Error → `expert_shield_error`. events.Instrumentation → route Plane-1 (`shield_<name>`) + Plane-2 map (8 native keys → `expert_shield_native_*`).
- activate() catch Throwable → `expert_shield_error {error:"start_failed",error_type:"exception",error_message}` (IG-08). IG-09 serviceNotRunning ladder = SKIP (no plugin 1:1).
- Analytics event names verified: `tracking_events.dart` (agent 4 list). Two planes: Plane1=Coralogix(observability), Plane2=Mixpanel/CleverTap(milestones). Reuse `AnalyticsTracker.track(name,props)`.

## 2b. Lifecycle seam + reconcile/start triggers (§16 core) — ✅ DONE (verified: JVM tests + iosArm64 compile green)
- Shipped: `core/lifecycle/AppLifecycle.kt` (common interface `foreground: StateFlow<Boolean>` + `expect fun platformAppLifecycle()`); Android actual = `ProcessLifecycleOwner` (lifecycle-process, already a dep); iOS actual = `UIApplication` DidBecomeActive/DidEnterBackground via `NSNotificationCenter`. `domain/ShieldForegroundReconciler.kt` (eager single): foreground→`SosCoordinator.reconcile()` (closes the dead reconcile() — it had no caller). Koin: `single<AppLifecycle>{platformAppLifecycle()}` + eager reconciler. Tests: `FakeAppLifecycle` + `ShieldForegroundReconcilerTest` (3). Launch-into-foreground reconciles once (StateFlow replay).
- Deferred: upload-queue drain on foreground (connectivity not wired); unifying coordinator start()-hoist (routers self-start eagerly — acceptable).

## 2b-notes-original. Lifecycle seam + reconcile/start triggers (§16 core)
- New `core/lifecycle/AppLifecycle.kt`: interface `{ val foreground: StateFlow<Boolean> ; fun observe... }` + `expect fun platformAppLifecycle(): AppLifecycle`. Android actual=ProcessLifecycleOwner; iOS actual=NSNotificationCenter (UIApplicationDidBecomeActive/DidEnterBackground).
- Wire: on foreground → `SosCoordinator.reconcile()` (currently dead) + drain (deferred). Hoist coordinator event-collection `start()` to lifecycle/job-start (currently self-starts on injection).

## 2c. Consent POST gate (D-5) — ✅ DONE (verified: JVM tests + iosArm64 compile green)
- Shipped: `data/ShieldConsentApi.kt` (+`ShieldConsentException`) + `ShieldConsentApiImpl` (POST `api/v1/runners/me/safety-shield/consent`, body `{consent:true,consent_version:"1.0"}`, 2xx→true; best-effort report). `KavachDataSourceImpl.activate()` = consent hard-gate: submit→success fires `expert_shield_consent_given` + starts engine; failure fires `expert_shield_consent_error` + throws `ShieldConsentException` (engine untouched). Koin + `FakeShieldConsentApi` + 2 gate tests. Grounded 1:1 vs Dart `shield_http.activateSnabbitShield` + `activateConsent`.
- ⛔ DEFERRED (host-job-context-dependent — needs the excluded host bridge feeding jobId + job widget_data): enablement/auto-start branch (partnerEnabled·customerConsent·autoEnabled·jobId), the §10 present/enabled→layer algorithm, and the runner-profile enablement read (`/runners/me` safety_shield is host-owned profile state, not a KMP re-fetch). These are NOT pure-KMP-closeable.

## 2c-original. Enablement/consent/auto-record (agent 3)
- `core/profile/ProfileGateway.kt` seam: `enabled:Boolean`, `consentGiven:Boolean?` (null≠false), `consentAt:String?`. KMP impl fetches `GET /api/v1/runners/me` → safety_shield.* via SnabbitHttpClient (or seam+default if endpoint unconfirmed — flag). Separate current-state seam for widget_data.snabbit_shield_{consent,auto}_enabled.
- Gating: shieldEnabled = partnerEnabled && customerConsent; autoStart = shieldEnabled && autoEnabled && jobId!=null; SOS/shield-start gate = runner consentGiven==true.
- Consent POST (SosApi-style): `POST api/v1/runners/me/safety-shield/consent` body `{consent:true,consent_version:"1.0"}`; success=200; NOT parsed; NO revoke/reconcile (parity).
- `activate()` gate chain: apply enablement branch (present→MONITORING_ONLY; present+enabled→MONITORING+RECORDING; !present→ACCELEROMETER_ONLY) = the expected_layer algorithm (agent 2 `_ensureExpectedShieldState`). Make init idempotent. Never downgrade (stop only at job-end).

## 2d. §12 promotion + §16 expected_layer + persist
- expected_layer = base(enablement) + raised(manual/SOS). Restore algorithm (agent 2 table): guard no-job/active-SOS; read native shieldState; compute present/enabled (enabled = present && (auto || wasManual[persisted])); raise only, never downgrade.
- Persist `shield_manual_monitoring_active` (StoreManager). Layer itself NOT persisted (re-derive from native getState + flag + /sos/active).
- Manual activation: MONITORING_ONLY→Activate→"Got it"(education sheet)→startRecording→PERMANENT MONITORING+RECORDING + persist(true).
- Deny/deescalate layer restore = delegate to plugin (invariant #4 handled plugin-side, confirmed). Reconcile triggers = 2b lifecycle.

## 2e. Deterrence (agent 3)
- `domain/ShieldDeterrence.kt` + audio seam (expect/actual play/stop/volume). Asset `audio/shield_deterrence.mp3` → composeResources. Delay = RC `expert_shield_sos_deterrence_delay_secs` default 3. Gate on active-SOS. **RESTORE volume after** (Flutter gap C13 — leaves at 1.0). Emit `expert_shield_deterrence_played`.

## 2f. App-driven permissions (agent 3) — logic; UI = Phase 4
- Permission seam over ShieldController.checkPermissions + KMP request (Grant lib already dep `dev.brewkits:grant-core:2.0.0`). Contexts: micOnly, micAndLocation. Results: granted/denied/permanentlyDenied. Hard-gate + settings-redirect + resume-recheck. Auto NEVER prompts mic.

# Phase 3 — Step 7 triggers
- Wire `ShieldUploadQueue.processQueue()` + `ShieldUploadCoordinator` start + connectivity/resume via the 2b lifecycle seam. currentJobId seam still host-fed (flagged) — but wire the trigger points.

# Phase 4 — Step 8 UI (agent 5, 1:1 refs)
Real assets to bring (composeResources/drawable, SVG→XML via svg2vectordrawable): shield_vector_lines_blue, shield_icon_blue, shield_protect_icon, shield_monitoring_icon, shield_sos_icon, shield_sos_active_dots_bg, shield_half_circles, phone_icon, shield_banner_icon. Off-scale colors already tokenized (bgErrorStrong/textErrorBright/textNeutralInk/etc.); NEW token needed: `#016EE6` (consent/activation title — distinct from shieldBlue #1B7DE9) → add DS token (existing-naming, e.g. `text.infoRoyal` already=indigo.500 #326FE3? NO — #016EE6 distinct; add `blue.650` already=#016EE6 ✓ → semantic textInfoDeep already maps #016EE6 ✓ REUSE). `#828282`=textNeutralGrey (have). Battery badge `#F70F79`(brand)/`#FFD5D8`/`#D03254` — add if building battery pill.
- Mic-permission screen · Location-permission screen · Accessibility dialog (2-action; DS: SnabbitBottomSheet or dialog — no DS dialog atom, flag). Copy/keys in agent-5 sheet.
- Consent parity: wire T&C SnabbitRichText → `https://snabbit-app-policies.s3.ap-south-1.amazonaws.com/Privacy_Policy_Expert_App.pdf`; real hero (shield_icon_blue + vector_lines_blue + circles); loading state; fix strings (INTRODUCING / "I Agree" / "…accept…"; split-weight "Snabbit कवच").
- SOS-active: real siren + dots-bg + half-circles + ribbon + pink gradient + `_SOSCirclesPainter` (Canvas, #FEAAAA); phone icon on Call btn. NOTE: Flutter has NO back-intercept→endSos (verified absent) — do NOT add.
- Battery sheet: label pill (LOW BATTERY / SNABBIT SHIELD LIMITED) + CDN icon (SnabbitRemoteImage) + fix CTA "I will do"; blocked-vs-warning variant.
- Education sheet: hero + fix (KeepPhoneSheetContent has body, needs hero).
- Storage: banner already present (KavachCard) — fix copy "Clear storage to enable safety recording.".

# Phase 5 — Step 9 IG = folded into 2a (event router).

# Phase 6 — Step 5 Android + iOS KMP
- serialization 1.9.0→1.11.0 (shared/build.gradle.kts). 
- iOS KMP: iOS Koin bootstrap (mirror KmpBootstrap — currently ABSENT in iosMain), shieldIosModules() wiring, `defaultHttpClientEngine()` iOS actual (currently throws NotImplementedError → implement Darwin engine), iOS analytics providers (flagged — SDKs needed), lifecycle iOS actual. Compile-verify via compileKotlinIosArm64.

# Phase 7 — data/ restructure (LAST) + commit
- network/(SosApi,ShieldUploadApi) local/(ShieldUploadQueue,db) config/(ShieldConfigFactory) upload/(ShieldKeyWrapper,ShieldFileReader); coordinators stay domain/. Update KavachModule + .sq package.

# Verify each: `:shared:testDebugUnitTest` + `:shared:compileKotlinIosArm64`. commonMain purity. D1/D2. errors→AppErrorType.
# ⛔ Out-of-scope (Xcode/devices/sign-off): Swift ML module, iOS on-device runtime (P4.2), on-device parity (Step 10), cutover (Step 11).
