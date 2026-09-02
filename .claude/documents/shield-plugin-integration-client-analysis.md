---
title: Snabbit Shield — Full Client-Side Plugin Integration (business logic, state, bridge, UI, wiring)
scope: /Users/Prabhu/Development/Projects/2-snabbit-runner-app (Dart/Flutter) ONLY. Native `safety_shield` plugin (git dep v1.0.0) internals OUT of scope; its boundary is recorded.
companion_to: shield-backend-integration-analysis.md (backend APIs, upload queue, DB schema, encryption envelope — NOT re-tabled here)
method: 8 file-scoped deep-read agents (2 batches), file:line evidence, read-only. Branch feat/kavach-kmp-with-ai-skills.
produced: 2026-07-10
status: as-implemented snapshot (facts, not fixes)
---

# Shield Plugin Integration — Client Implementation

Records everything in `2-runner-app` (minus pure backend detail, which lives in the companion doc): the plugin bridge, state sync in/out, state management, consent, lifecycle/business logic, the SOS state machine, the client crypto touchpoint, all UI, and app wiring. All paths repo-relative under `lib/`.

## 0. Architecture & layering (no repository layer)

```
UI (widgets)                        SnabbitShieldCard, *BottomSheet, SOSActiveScreen, shield_ui_prompts
   │ reads via Provider / callbacks up
State (ChangeNotifier)              SnabbitShieldProvider (recording/monitoring/SOS/storage) · ShieldConsentProvider (prompt only)
   │ owned by ↓
Orchestrator (facade)              SafetyShieldAdapter  ── delegates to ──▶ SosFlowCoordinator · ShieldStartStopController · ShieldEventHandler · ShieldDeterrenceAudio
   │ calls into ↓                                          │ business logic + SOS state machine
Plugin bridge                      SafetyShield.instance (package:safety_shield)  — method calls OUT, event streams IN
Data/outbox (per companion doc)    ShieldHttp (static) · ShieldUploadQueue · ShieldDatabase (sqflite) · ShieldEncryptor (RSA) · ShieldSosPushStore (prefs)
Global handles                     GlobalState().shieldAdapter, .shieldUploadQueue   (globals.dart:203-204)
```

**Verdict — layering (evidence-backed):** There is **NO Repository, NO UseCase/ViewModel layer.** Pattern = **provider + adapter (orchestrator) + queue/db/http direct-wiring**. Roles: orchestration = `SafetyShieldAdapter`; "repository" role split across static `ShieldHttp` (network) + `ShieldDatabase`/`ShieldUploadQueue` (persistence outbox); consent "repository" = `UserProfileProvider` + `ShieldHttp.activateSnabbitShield()`. Provider self-describes as a *"thin reactive state holder"* (`snabbit_shield_provider.dart:22-26`).

**State ownership is triplicated** (a key structural note): the two `ChangeNotifier`s live inside `SafetyShieldAdapter`, the adapter is held as a `partner_home` State field, AND mirrored into `GlobalState().shieldAdapter` — three references to the same objects.

---

## 1. Plugin bridge & state sync

**Mechanism:** plain Dart package API — `_shield = SafetyShield.instance` (`safety_shield_adapter.dart:52`, import `:7`). Not MethodChannel/Pigeon at the app layer (the plugin encapsulates that). The adapter is a **plain facade class** (not singleton, not ChangeNotifier) — `safety_shield_adapter.dart:38,107`.

### 1a. Commands OUT (app → plugin), direct in adapter

| # | Method | Args | Line | Trigger |
|---|---|---|---|---|
| 1 | `initialize(config)` | `SafetyShieldConfig` | :228 | first init |
| 2 | `initialize(fallbackConfig)` | ML-disabled | :248 | primary init threw + ML was on |
| 3 | `notifyStreamsReady()` | — | :284 | after subscribe |
| 4,13 | `onJobStarted()` | — | :365,:632 | job start / accel restore |
| 5,14 | `startAccelerometerOnly()` | — | :371,:633 | Layer-1a floor |
| 6,9,10,15 | `checkPermission(microphone)` | — | :380,:498,:530,:645 | gate/resume re-check |
| 7 | `requestPermission(microphone)` | — | :385 | mic denied |
| 8,16 | `startMonitoringOnly()` | — | :388,:647 | mic granted |
| 11 | `downgradeToAccelerometer()` | — | :550 | resume, mic revoked |
| 12 | `getShieldState()` | — | :596 | read native truth |
| 17 | `triggerManualSoS()` | — | :737 | SOS slider path |
| 18 | `confirmSoS()` | — | :743 | right after trigger |
| 19 | `shutdown()` | — | :808 | dispose |

**Delegated OUT** (issued inside collaborators, not adapter): `startShield/stopShield` (controller), `triggerManualSoS/confirmSoS/denySoS/deescalateSoS` (coordinator — `sos_flow_coordinator.dart:484,849,390/901,433`), `onJobStarted/onJobEnded`, `discardAESKey` (event handler — see §5). **No runtime "push-config" method exists** — config is passed only at `initialize`.

### 1b. Events IN (plugin → app)

Single subscribe point `_eventHandler.subscribe()` (`adapter:280`); single cancel `_eventHandler.cancel()` (`:142,:518,:806`). All 9 streams are owned by `ShieldEventHandler` (`shield_event_handler.dart:76-119`, all cancelled `:124-132`):

| Stream | Handler | Core decision | Line |
|---|---|---|---|
| `onEncryptedAudioReady` | `_handleEncryptedAudio` | snapshot jobId pre-await; drop if queue/jobId null (analytics); read bytes; RSA-wrap key; enqueue; discardAESKey; delete file | :137-221 |
| `onSoSTriggered` | `_handleSoSTriggered` | map source→api, `triggerType` ml/non_ml, `initiateSosAndShowSheet`; complete manual completer if `source==manual`. **No dedup guard here** | :223-236 |
| `onRecordingStateChanged` | — | idle/recording/paused → provider; emits Started/Resumed/Paused analytics | :238-273 |
| `onMonitoringStateChanged` | — | idle/monitoringOnly/active → provider. **No analytics** | :275-289 |
| `onError` | — | provider error + `expertShieldError`; Crashlytics on modelLoadFailed/uncaughtException | :291-319 |
| `onPermissionStatusChanged` | — | log + `expertShieldPermissionChanged` | :321-340 |
| `onAccessibilityServiceStatus` | — | **log-only no-op** (no provider/analytics/action) | :342-352 |
| `onInstrumentationEvent` | — | Coralogix forward (throttled) + product-milestone map (debounced) | :393-431 |
| `onNotificationAction` | — | pure delegate → `coordinator.handleNotificationAction` | :433-434 |

Adapter wires the handler with callbacks (`adapter:147-158`): shieldProvider, sosCoordinator, log/logError, trackShieldEvent, currentJobId, activeTrigger, encryptor, uploadQueue (`_uploadQueue ?? GlobalState().shieldUploadQueue`).

### 1c. Adapter lifecycle

`initialize()` → `_ensureInitialized()` (`adapter:181-299`): guarded by `_initialized` + coalesced via in-flight `_initializeFuture`/`Completer`. Order: load RSA PEM (non-fatal on fail `:194-208`) → `_shield.initialize(config)` (ML-disabled fallback retry `:245-271`) → subscribe streams `:280` → `notifyStreamsReady` `:284`. Both init attempts fail → returns `false`, no subscribe, **silent no-op** (callers `if(!ok) return`). Recovery: `onAppResumed` re-init on mic revocation (`:516-524`). Dispose (`:798-810`): `coordinator.dispose` → `stopShield` (3s cap, errors swallowed) → cancel streams → `shutdown` (ordering lets the last clip flush).

---

## 2. State management

**Approach:** `ChangeNotifier` + `provider` package, exposed via `ChangeNotifierProvider.value` (owned by adapter, not the tree). `partner_home.dart:1046-1047`.

### 2a. `SnabbitShieldProvider` state (`snabbit_shield_provider.dart`)

| Field | Type | Line | Notifies? |
|---|---|---|---|
| `_isShieldRecording` | bool | 29 | ✓ |
| `_isRecording` / `_elapsedSeconds` / `_amplitude` | bool/int/double | 30-32 | ✓ |
| `_isPaused` / `_isRecorderPaused` | bool | 33-34 | ✓ |
| `_error` | String? | 35 | ✓ |
| `_isLowStorage` | bool | 36 | ✓ (diff-guarded) |
| `_isSOSMode` | bool | 37 | ✓ |
| `_monitoringAcknowledged` | bool | 38 | ✓ |
| `_isStartingMonitoring` | bool | 39 | ✓ |
| `_preSosSnapshot` (`PreSosSnapshot`) | obj? | 40 | **✗ silent (undocumented)** |
| `_isAccelerometerOnly` | bool | 42 | **✗ intentional** (:143-144) |
| `_isMonitoringOnly` | bool | 44 | **✗ intentional** (:149-150) |

`PreSosSnapshot` (`:7-20`): immutable {wasShieldRecording, wasMonitoringAcknowledged, wasAccelerometerOnly, wasMonitoringOnly} — captured pre-SOS, restored by coordinator on resolve. `reset()` clears all + notifies (`:170-185`). `updateStorageStatus()` is the only mutator doing I/O (`:190`).

### 2b. `ShieldConsentProvider` state (`shield_consent_provider.dart`)

| Field | Type | Line | Notifies? |
|---|---|---|---|
| `_isLoading` | bool | 13 | ✓ |
| `_consentSheetDismissed` | bool | 14 | ✗ |
| `_isSheetVisible` | bool | 15 | ✗ |
| `_sheetCompleter` | Completer<bool>? | 16 | ✗ |

**Holds no "granted" flag** — authoritative consent = `UserProfile.consentGiven` (see §3).

### 2c. Registration & propagation

- Adapter created `partner_home.dart:267-270`; published `GlobalState().shieldAdapter=_shield` `:271`; queue created in `main.dart:607` → `GlobalState().shieldUploadQueue` `:611`.
- Providers exposed `.value` `:1046-1047`; consumed via `Selector`/`Consumer<SnabbitShieldProvider>` (`:1312,1479,1505,1544`).
- **Propagation contract:** UI reacts only through `notifyListeners`. API result → state: recording/upload results flow adapter→provider setters→notify→rebuild; consent activation writes `UserProfileProvider.consentGiven=true` (cross-provider). The 3 silent mutators (accel-only, monitoring-only, pre-SOS) are invisible to rebuilds until another notify fires.

---

## 3. Consent state machine (`shield_consent_provider.dart`)

**Authoritative value = `UserProfile.consentGiven` (backend-owned).** The provider only orchestrates the prompt + activation call.

- `needsConsent(user)` = `user?.consentGiven != true` — treats `null` as needs-consent (deliberate privacy fix, `:29-35`).
- `canShowOnWidget(name)` — suppressed on blocklist (`GlobalState().appConfig?.blockedShieldConsentWidgets`, else 4 hardcoded states `:20-27`).
- Two entry paths: **opportunistic** `showConsentIfNeeded()` (respects `_consentSheetDismissed`, needs `safetyShieldEnabled`, `:42-51`) vs **hard-gate** `ensureConsent()` (ignores dismissed, always shows if missing, `:57-72`). Race: if sheet already visible, `ensureConsent` awaits the shared completer (`:66-68`).
- Activation `activateConsent()` (`:115-142`): `_isLoading=true`+notify → `ShieldHttp.activateSnabbitShield()` (`:119`) → on 200 write `userProfileProvider.consentGiven=true` (`:124`) + `expertShieldConsentGiven`.
- **No consent version. No revoke path** (`consentGiven` only ever set true). Gates: shield start (thus recording + SOS).

---

## 4. Lifecycle & business logic

### 4a. Start/stop (`shield_start_stop_controller.dart`)

| Event | Trigger | Action | Line |
|---|---|---|---|
| Job start + auto | `onJobStartedAndAutoStart` | `onJobStarted()`, `updateStorageStatus`, `startShield(auto)`, `syncActiveSosState` | 94-113 |
| Generic start | `startShield(trigger)` | gate chain (below) | 116 |
| Stop | `stopShield()` | stopMonitoring + stopRecording (guarded), reset, accel off, setInitialized(false) | 404-421 |
| Job end / logout / consent revoke | `onJobEnded()` (single stop entrypoint) | cancelDeterrence, clear flags, `expertShieldStopped{job_ended}`, stopShield, `onJobEnded()`, setInitialized(false) | 439-466 |

**Precondition gate chain (exact order) — `startShield`:**

| Order | Gate | Line | On fail |
|---|---|---|---|
| — | reentrance `_startShieldInProgress` | 120 | return, **no analytics** |
| 0 | jobId null | 128 | **silent return, no analytics** |
| — | native state restore + desync reconcile | 131-160 | non-blocking |
| 0 | init plugin `_ensureInitialized` | 164 | `init_failed` + return |
| 1 | consent `ensureConsent` | 200 | `consent_denied` + return |
| 1b | mic → monitoringOnly (requests only if trigger≠auto) | 216-246 | non-blocking skip |
| 2 | battery | 248 | `battery_too_low` + return |
| 3 | storage | 263 | `storage_insufficient`+`StorageFull` + return |
| 5 | encryptor null | 280 | `encryptor_failed` + return (no lazy re-init) |
| 6 | upload queue null → lazy init | 290-314 | `upload_queue_null` + return |
| — | start recording+monitoring (serviceNotRunning recovery) | 318-394 | reinit retries; `start_failed` variants |

`expertShieldStarted{recording}` is deferred to the event handler on native `RecordingState.recording` (`:395-397`). `activeTrigger` persisted only on success (`:390`) except the desync fall-through which sets it early (`:157`).

### 4b. Event-handler decisions & source mapping

`_mapSoSSourceToApi` (`shield_event_handler.dart:453-466`): ml/accelerometer/volumeButton/notificationButton/manual → `SosSource.*.apiValue` (exhaustive, no default). Recording duration `_getRecordingDuration()` (`:439-450`): SOS 10s > manual 5s > default 5s (RC keys below).

---

## 5. Client crypto touchpoint (honest "double encryption")

**"Double encryption on client" = two on-device layers; only the second is Dart:**

| Layer | Algorithm | Where | Evidence |
|---|---|---|---|
| 1. Audio bytes | AES-256-GCM | **native plugin** (on-device, NOT Dart) | bytes arrive already-encrypted `shield_event_handler.dart:169` |
| 2. AES key wrap | RSA-2048 OAEP/SHA-256 | **Dart (this repo)** `ShieldEncryptor.wrapAesKey` | `snabbit_shield_encryptor.dart:21-27` |

**Sequence (event handler, per clip):** receive `EncryptedAudioEvent{filePath, aesSecretKey, iv, authTag}` → snapshot jobId `:144` → read encrypted bytes `:169` → **RSA-wrap AES key** `:178` → build `ShieldEncryptionMetadata{encryptedKey, iv, authTag, isCompressed}` `:181` → `enqueue` `:192` → **`_shield.discardAESKey()`** `:202` → delete source file `:205`. RSA public key = bundled asset `assets/keys/shield_public_key.pem`, loaded at `adapter:196` (non-fatal on fail). Envelope upload/DB detail → companion doc. **The Dart app never performs AES and never decrypts.**

---

## 6. SOS flow (client state machine) — `sos_flow_coordinator.dart`

No enum state var; machine is implicit across id fields + `isSOSMode` + booleans + sheet/screen flags.

**State fields:** `_pendingSosId`(56), `_confirmedSosId`(60), `_sosInProgress`(63), `_sosScreenPushed`(66), `_sosResolvedExternally`(69), `_appWasBackgrounded`(73), `_isSyncingActiveSos`(76), `_pendingSosMissedForBackground`(81), `_pendingManualSosCompleter`(84), `_activeSosSource`(88), `lastContext`(91), `sosProvider`(51).

**Transition table (condensed):**

| From | Trigger | Guard | To | Line |
|---|---|---|---|---|
| IDLE | `initiateSosAndShowSheet` | `!_sosInProgress` | INITIATING | 127-161 |
| IDLE | concurrent trigger | `_sosInProgress` | drop 2nd (`ConcurrentOverridden`) | 130-136 |
| INITIATING | initiate 200 | sosId≠null | pre-show checks | 171-204 |
| INITIATING | initiate fail/null | — | **sheet still shows w/ null sosId** | 175-211 |
| INITIATING | ctx null / bg / resolved-externally | resp. | SKIPPED variants | 214-247 |
| INITIATING | else | clear | ALERT_SHEET_SHOWN | 250 |
| ALERT | primary tap | — | confirm path | 644-651 |
| ALERT | secondary tap | — | deny path | 655-662 |
| ALERT | RC timer | `!handled&&!resolved&&!bg` | deny(timeout) | 624-635 |
| ALERT | sheet closed | same | deny(dismissed) | 669-690 |
| ALERT | notif confirm/auto | — | CONFIRMED (callApi:false) | 319-327 |
| ALERT | notif deny/expired | — | deny (callApi:false) | 328-336 |
| ALERT | FGS confirm/deny | — | confirm/deny (callApi:true) | 696-745 |
| any | stale push (id mismatch) | — | ignored | 302-306 |
| CONFIRMED | `onFalseAlarm` | recording/mon && isSOSMode | RESOLVED (deny) | 372-408 |
| CONFIRMED | `deescalateSos` ("I am safe") | — | RESOLVED (dismiss) | 412-464 |
| CONFIRMED | FGS end_sos / escalate | — | deescalate / dial | 274-287 |
| reconcile | `/sos/active` initiated/pending/denied/none | see below | re-show / active / deny / force-idle | 526-556,946-1022 |

Reconcile guards asymmetric: initiated (`:947`) + confirmed (`:977`) early-return if `isSOSMode`; **denied (`:1006`) has no isSOSMode guard** (can yank an active screen).

**Timers/RC:** alert auto-deny `shieldSosAlertDisplaySecs` default 20 (`:621`); manual-SOS completer 10s hardcoded (`:488`); deterrence delay `shieldSosDeterrenceDelaySecs` default 3 (`:934`); fallback dial `shieldSosFallbackPhone` (`:1027`). Analytics: 20 `expertShieldSos*` events (initiated/failed/confirmed/denied/deescalated/synced/desync/deterrence/…). Orchestration: initiate=E1, confirm/deny/dismiss=E2, reconcile=E3, dial=E4 (companion doc); plugin `triggerManualSoS/confirmSoS/denySoS/deescalateSoS`; single `Navigator.push(SOSActiveScreen)` guarded by `_sosScreenPushed` (`:872`).

**Legacy SOS (`lib/widgets/sos.dart`, 457) = DEAD UI** — confirmed severed at `partner_home.dart:280,283` (`onSOSTriggered=null`). `SOSProvider` still provider-registered (`main.dart:1660`), `triggerSOS()` posts E2 with empty body (`sos.dart:76`), reads `allowed`/`ph_no` — not reachable from any mounted widget. Only `onFalseAlarm` bridged to adapter (`:284-286`); `shield.sosProvider=sosProvider` (`:287`).

---

## 7. Preconditions & peripherals

| Helper | Rule | Source | Line |
|---|---|---|---|
| Battery (`shield_battery_check.dart`) | block <15%, warn <20% (both RC); `<=0` disables; sheet cooldown 2h; **parse fallback 100%** (never blocks on bad read); returns result, caller enforces | `getBatteryLevel()` (no plugin here) | 37-68,119-126 |
| Storage (`shield_storage_check.dart`) | low if free < 500MB (RC); `<=0` disables; fail-open on null/exception (silent) | `disk_space_2` | 9-27 |
| Permissions (`snabbit_shield_permission_handler.dart`) | **mic + location(WIU) + locationAlways only**; check-then-request; permanently-denied→settings redirect; hard-gate `PopScope(canPop:false)`; resume re-check | `permission_handler` | 18-191 |
| Deterrence (`shield_deterrence_audio.dart`) | plays asset `audio/shield_deterrence.mp3` at forced volume 1.0 (not restored), alarm usage; Timer(delay); `catch(_){}` swallows failures | `audioplayers` | 16-50 |
| YAMNet (`yamnet_classes.dart`) | `enum YamnetClass`, **62** distress-relevant labels (scream/gunshot/glass/siren/…); validated against RC target list in adapter | — | 5-91 |

Not handled anywhere in-scope: notification permission (elsewhere), battery-optimization, accessibility permission (only a status stream, log-only).

---

## 8. UI implementations

DS adoption is **minimal** across all shield UI — only `CommonBottomSheetSetup` + `PulseDot` + some `AppColors`; the rest is raw Flutter Material with hardcoded hex colors and `flutter_screenutil` sizing.

### 8a. `SnabbitShieldCard` (356) — embedded StatefulWidget

Param `onStartMonitoring` (`:20`). Watches whole `SnabbitShieldProvider` (`context.watch`, `:34` — rebuilds on every notify incl. amplitude). Fires only `onStartMonitoring?.call()` (`:142`) — no direct coordinator call. **State→visual:**

| Provider state | Visual | Line |
|---|---|---|
| recording+acknowledged (`isActive`) | pulse dot + expanding waveform | 131-136,196-202 |
| not active + `onStartMonitoring≠null` | Activate button | 137-184 |
| not active + low storage | Activate disabled + red storage banner (→ openAppSettings) | 140-147,303-356 |
| not active + null callback | `SizedBox.shrink` | 185-187 |

**SOS mode not reflected; recording vs monitoring-only collapsed into one `isActive` bool** (`:36`). `_WaveformWidget` (50 bars, 80ms timer, disposed correctly `:255-258`). Card `initState` empty/dead (`:27-30`).

### 8b. `ShieldActivationBottomSheet` (205) — static `show()→Future<bool?>`

Modal via `showModalBottomSheet` (`:21-45`), `CommonBottomSheetSetup`. Presentational; "Got it"→`pop(true)` (`:137`). Cap/persistence handled by caller (`shield_ui_prompts`). No state reads beyond `LanguageProvider`.

### 8c. `ShieldConsentBottomSheet` (466) — static `show(context,{consentProvider})→Future<bool>`

Injects provider via `.value` (`:34`). 3 feature rows (Protect/Monitoring/SOS), T&C block resolving `{{tnc}}` (`_buildTncText:209-302`), Agree button with loading spinner (`Consumer`, `:306-335`). `_onActivate` (`:337`): Mixpanel → `consentProvider.activateConsent(userProfileProvider)` (`:345`) → success `pop(true)` / failure snackbar. T&C link `_openTnc` fire-and-forget to hardcoded S3 PDF (`:367-373`). `context.mounted` guarded (`:347`).

### 8d. `ShieldAlertBottomSheet` (344) — static `show()` / `hide()` / `isShowing`

Fully parameterized modal (`:45-119`): imageUrl/title/accentColor/primary+secondary buttons/onShown. Injected callbacks are what the coordinator wires as confirm/deny. `_isShowing` static flag (`:24`). No countdown timer here (the auto-deny timer lives in the coordinator).

### 8e. `SOSActiveScreen` (345) — full-screen StatefulWidget

Pushed by coordinator (no `show()`). Reads passed `sosProvider` (raw, **not** watched), `phoneNumber`, RC fallback phone, `GlobalState().shieldAdapter`. Actions: "Call SOS Team"→`_launchDialer`→`CallUtils.handleCallInitiation` (E4); "I am safe, end SOS"→`shieldAdapter.deescalateSos()`→`Navigator.pop` (`:259-269`). Static (no timers/animation; circles painter `shouldRepaint=>false`). **No `PopScope`/`WillPopScope`** → system back pops without `deescalateSos` (state desync — see gaps).

### 8f. `shield_background_circles_painter.dart` (44) — static `CustomPainter`, no animation.

### 8g. `shield_ui_prompts.dart` (157) — decision helpers (not widgets)

| Fn | Rule | Line |
|---|---|---|
| `maybeShowActivationSheet` | skip if shown ≥ `shieldActivationSheetMaxShowCount`(10); else show + increment | 25-52 |
| `maybeShowAccessibilityDialog` | granted→true; ≥`shieldAccessibilityDialogMaxShowCount`(3)→true; else dialog; "Open Settings"→request+pendingManualStart | 59-117 |
| `isAccessibilityEnabledForCluster` | RC `shieldAccessibilityEnabledClusterIds` contains user clusterId | 120-127 |
| `pollForMicPermission` | poll 500ms up to 15s | 131-157 |

Counters persisted in SharedPreferences. Does **not** orchestrate the alert sheet / SOS screen (that's the coordinator).

---

## 9. App wiring & boot

**Boot `main()` (`main.dart`):** binding(:444) → KMP crash bridge(:449) → orientation/splash(:453) → Firebase(:470) → deviceId(:476) → RemoteConfig init(:488) → BcpGate(:490) → **Shield DB+queue(:604-622)**: `ShieldDatabase.initialize()`(:606)→`ShieldUploadQueue`(:607)→`.start()`(:610)→`GlobalState().shieldUploadQueue`(:611), try/catch **non-fatal** → splash remove(:624) → `runApp`(:625). **Adapter is NOT created at boot** — only in `partner_home`.

**GlobalState handles (`globals.dart`):** `shieldUploadQueue`(203), `shieldAdapter`(204), `isBackgroundIsolate`(211), `navigatorKey`(218), `currentEnv`/`remoteUrl`(135/144), `serverPath`(228), `currentVersionCode`(289), `kavachTestEnv`(126). No token getter (uses `SecureStorageUtils`).

**partner_home wiring (`partner_home.dart`):** create adapter(:267-270) → publish global(:271) → warm `initialize()`(:273) → grab SOSProvider(:275) → cut legacy `onSOSTriggered=null`(:283) → bridge `onFalseAlarm`(:284-286) → `shield.sosProvider`(:287) → inject prefs(:289) → `onWidgetChanged` every didChangeDependencies(:334) → `onAppResumed`(:406) / `onAppPaused`(:652) → expose providers `.value`(:1046-1047) → mount card gated on `isCardVisible`(:1473) → dispose nulls callbacks then `dispose()`(:1713-1732).

**job_accepted (`job_accepted.dart`):** no shield start; only a mic hard-gate `_checkShieldMicBeforeCheckIn` (`:881-898`) when consent+auto enabled, before check-in (`:974,1109`). Recording starts later via adapter `onWidgetChanged`.

**Push routing:** foreground tap `notification_service.dart` `'safety_shield_sos'` (`:210-230`): keys `action`,`sos_id` → `adapter.handleSOSNotification` if ready, else `ShieldSosPushStore.persist` (`:221`). Foreground data-push handled in `main.dart:407-426` (adapter-or-persist). **Background/killed handler `main.dart:301-354` has NO `safety_shield_sos` branch** — killed-state data pushes rely on a user tap to route.

---

## 10. RemoteConfig keys (full)

| Key const | Default | Purpose |
|---|---|---|
| shieldMlDetectionEnabled | false | ML trigger master switch |
| shieldDurationSecs / shieldPauseSecs | 5 / 5 | auto recording chunk/pause |
| shieldManualDurationSecs / shieldManualPauseSecs | 5 / 5 | manual chunk/pause |
| shieldSosDurationSecs / shieldSosPauseSecs | 10 / 1 | SOS chunk/pause |
| shieldSosPendingDurationSecs / …IntervalSecs | 5 / 5 | SOS pending total/poll |
| shieldSosAlertDisplaySecs | 20 | alert sheet auto-deny (fg) |
| shieldSosDeterrenceDelaySecs | 3 | deterrence delay |
| shieldSosFallbackPhone | "" | fallback support number |
| expertSosContactNumber | "" | **legacy** SOS number (dead path) |
| shieldBatteryBlockThreshold / WarnThreshold | 15 / 20 | battery % block/warn |
| shieldBatterySheetCooldownSecs | 7200 | battery sheet cooldown |
| shieldStorageBlockThresholdMb | 500 | storage MB block |
| shieldActivationSheetMaxShowCount | 10 | activation sheet cap |
| shieldAccessibilityEnabledClusterIds | [] | accessibility cluster allow-list |
| shieldAccessibilityDialogMaxShowCount | 3 | a11y dialog cap |
| shieldDbSpikeThreshold | 15.0 | dB spike threshold |
| shieldAccelerometerMagnitudeG | 2.7 | shake G |
| shieldAccelerometerWindowSec / CooldownSec | 1.5 / 5 | shake window/cooldown |
| shieldAccelerometerLpfAlpha | 0.888 | low-pass alpha |
| shieldAccelerometerFreefallThresholdG / MinMs | 0.4 / 30 | freefall G/ms |
| shieldAccelerometerDropSuppressMs | 500 | post-drop suppress |
| shieldYamnetConfidenceThreshold / TopK | 0.5 / 3 | YAMNet conf/topK |
| shieldYamnetTargetClasses | [] → safe set | distress classes |
| shieldVadConfidenceThreshold | 0.8 | voice gate |
| shieldVolumeClickCount / WindowSec | 3 / 1.5 | volume-button trigger |
| shieldDiagnosticsEnabled | false | high-volume ML telemetry |
| shieldStartDelayMins | — | **DEAD — no reader in lib/** |

Defaults resolved inline at call-sites (no central shield default map) → a mistyped key silently yields the caller's default.

---

## 11. Consolidated gaps / risks (deduped, honest)

| # | Area | Gap | Evidence |
|---|---|---|---|
| C1 | SOS UI | **`SOSActiveScreen` has no `PopScope`** — system back pops without `deescalateSos()`; state desync + missed analytics on a safety screen | sos_active_screen.dart:99 |
| C2 | SOS logic | **Alert sheet proceeds with null sos_id** when initiate fails; subsequent confirm/deny E2 omit `sos_id` → backend must infer by identity | coordinator:175-263,759,810 |
| C3 | SOS logic | reconcile `denied` has no `isSOSMode` guard — a post-confirm backend flip to denied tears down the active screen | coordinator:1006 |
| C4 | SOS logic | `onFalseAlarm` guard silently no-ops if state unexpected (no API/analytics/state change) | coordinator:377 |
| C5 | Push | **killed-state SOS data-push not persisted on receipt** — bg handler has no `safety_shield_sos` branch; relies on user tap | main.dart:301-354 |
| C6 | Audio | two clip-drop paths with **no analytics** (file-missing, encryptor-null); only queue/jobId-null emits a drop event | event_handler:164-177 vs 156 |
| C7 | Lifecycle | jobId-null + reentrance starts return **silently, no analytics** (funnel blind spots) | controller:120-129 |
| C8 | State | **triplicated ownership** (providers ⊂ adapter ⊂ partner_home + GlobalState); `GlobalState().shieldAdapter` not shown cleared on dispose → possible dangling global | provider analysis §3; globals:204 |
| C9 | State | 3 silent mutators (accel-only, monitoring-only, pre-SOS) never notify → UI can't react | provider:143-165 |
| C10 | Consent | no consent version + no revoke path; cross-provider write-back; consent truth not in consent provider | consent_provider:124 |
| C11 | UI | shield card doesn't reflect SOS; recording vs monitoring-only collapsed to one bool; watches whole provider (rebuild cost) | card:34,36 |
| C12 | Peripherals | battery parse fallback = 100% (never blocks on bad read); storage + deterrence swallow errors silently (no analytics) | battery:58; storage:25-27; audio:41 |
| C13 | Peripherals | deterrence forces volume to 1.0 and never restores it | audio:25 |
| C14 | Encryption | RSA public key bundled asset, no rotation; encryptor-load failure non-fatal → clips silently dropped downstream (fail-closed, data-loss) | adapter:196-208 |
| C15 | Config | `snabbit_shield_config.dart` holds only DTOs (misnamed); `toJson`/`toApiJson` asymmetric; `key_version:'v1'` hardcoded | config:94-110 |
| C16 | Legacy | dead `SOSProvider`/`SOS`/`SOSPopup` still registered + reachable via a distinct E2 empty-body path; two SOS-number RC keys coexist | sos.dart; partner_home:280 |
| C17 | RC | `shieldStartDelayMins` dead key; inline defaults risk drift (duplicated literals) | remote_config_keys.dart |
| C18 | Adapter | init-failure silent no-op (no retry/user surface); `notifyStreamsReady` failure swallowed; dispose flush capped at 3s | adapter:274-288,798-810 |

No `TODO`/`FIXME`/`UnimplementedError`/hardcoded-symmetric-key markers found in any analyzed file — the integration is fully wired. All gaps are design/wiring observations.

## 12. File index (module + wiring)

| Group | Files |
|---|---|
| Bridge/orchestration | `safety_shield_adapter.dart` |
| Business logic | `sos_flow_coordinator.dart`, `shield_start_stop_controller.dart`, `shield_event_handler.dart` |
| State | `snabbit_shield_provider.dart`, `shield_consent_provider.dart` |
| Data/DTO (see companion) | `snabbit_shield_config.dart`, `shield_http.dart`, `snabbit_shield_upload_queue.dart`, `snabbit_shield_database.dart`, `snabbit_shield_encryptor.dart`, `shield_sos_push_store.dart` |
| Preconditions/peripherals | `shield_battery_check.dart`, `shield_storage_check.dart`, `snabbit_shield_permission_handler.dart`, `shield_deterrence_audio.dart`, `yamnet_classes.dart` |
| UI | `ui/snabbit_shield_card.dart`, `ui/shield_activation_bottom_sheet.dart`, `ui/shield_consent_bottom_sheet.dart`, `ui/shield_alert_bottom_sheet.dart`, `ui/sos_active_screen.dart`, `ui/shield_background_circles_painter.dart`, `shield_ui_prompts.dart` |
| Legacy SOS (dead) | `widgets/sos.dart` |
| Wiring | `main.dart`, `services/globals.dart`, `pages/partner_home.dart`, `widgets/job_start_flow/job_accepted.dart`, `services/notification_service.dart`, `services/remote_config/remote_config_keys.dart` |
