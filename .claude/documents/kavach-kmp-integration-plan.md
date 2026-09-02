---
title: Kavach KMP — Pending Work Plan (UI parity + safety-kavach plugin integration)
purpose: Single source for everything NOT YET done to take the Kavach KMP feature from UI-skeleton to full parity with the Flutter shield. Fast-track any future session.
baseline: UI skeleton + no-op KavachDataSourceImpl (see kavach-kmp-current-state memory). Repo 2-snabbit-runner-app, branch feat/kavach-kmp-with-ai-skills.
spec_docs: shield-backend-integration-analysis.md (backend APIs/DB/crypto) · shield-plugin-integration-client-analysis.md (client behaviour/state/UI/wiring). Gap IDs G#/C# below refer to those.
produced: 2026-07-10
status: PLAN — items marked [OPEN] need an explicit decision before building (R4).
---

# Kavach KMP Integration — Pending Plan

**Baseline (done):** screens, nav (KavachHome/SosActive Destinations), MVI contracts, 2 ViewModels (D1/D2), Koin wiring, host `nativeScreen`, tests, strings fallback, DS components (PR #108). `shieldAndroidModules()` DI already loaded in `KmpBootstrap`. **Everything below is pending.**

**How to use:** pick a phase → resolve its `[OPEN]` decisions with the engineer → build per the acceptance rows → verify. Do not self-decide `[OPEN]` items.

---

## 0. Decisions — RESOLVED (2026-07-10)

All nine resolved. D-1/D-2/D-3 settled by evidence; D-4/D-6/D-7 by engineer sign-off; D-5/D-8/D-9 by grounded recommendation.

| # | Decision | Resolution | Basis |
|---|---|---|---|
| D-1 | Plugin vs app division of labour | **Plugin owns** recording, AES, detection, monitoring, SOS lifecycle, permissions, foreground, notifications, state machine. **App owns** RSA key-wrap, upload queue+DB+S3, SOS backend APIs (E1-E4), consent API, push routing, analytics routing (Instrumentation), RemoteConfig→ShieldConfig. | Plugin contract: `ShieldController.kt:22-24` — *"boundary ends at `ShieldEvent.EncryptedAudio`: the client owns RSA key-wrap + upload."* |
| D-2 | `safety-kavach` engine API | **`ShieldController`** (Koin `single`, already DI-loaded via `shieldAndroidModules()`/`shieldIosModules()`). `KavachDataSourceImpl` injects it and calls: `initialize/onJobStarted/onJobEnded/shutdown`, `updateAudioConfig/updateDetectionThresholds`, `startRecording/stopRecording/discardCurrentRecording`, `startMonitoring(Only)/startAccelerometerOnly/downgradeToAccelerometer/stopMonitoring`, `confirmSoS/denySoS/deescalateSoS/triggerManualSoS`, `discardAESKey`, `checkPermissions/requestPermissions`. Observes `shieldState/recordingState/monitoringState: StateFlow` + `events: SharedFlow<ShieldEvent>` (6: `EncryptedAudio`, `SoSTriggered`, `PermissionStatus`, `Error`, `Instrumentation`, `NotificationAction`). | `ShieldController.kt:26-77`, `ShieldEvent.kt:18-62` (safety-kavach) |
| D-3 | KMP HTTP layer | **Reuse Ktor 3.4.0** already in `:shared` (`KtorClient.android/ios` + `NetworkExceptionMapper`); build SOS + audio endpoints on it. | `shared/build.gradle.kts:80-82` |
| D-4 | Client outbox persistence | **SQLDelight** (KMP-native, typed; matches the sqflite outbox). Add the pinned dep + plugin to `shared/build.gradle.kts`. | engineer sign-off |
| D-5 | Consent authoritative source + version/revoke | **RESOLVED against the live Flutter contract** (see `shield-enablement-consent-autorecord-contract.md`). Source = backend `/runners/me` → `safety_shield.{enabled, consent_given, consent_at}`, mirrored via a `ProfileGateway`-style seam. Activate = `POST /safety-shield/consent {consent:true, consent_version:'1.0'}` — **version IS sent (hardcoded), but never validated → no re-prompt on drift** (E1); **no in-app revoke** — write-once-true, backend un-sets via profile (E2). `consent_at` is dead (E3). KMP: send `consent_version`; re-prompt-on-drift is an OPTIONAL improvement (flag). | contract doc; shield_http.dart:191; user_profile.dart:1008-1010 |
| D-6 | RemoteConfig seam | **Build a `RemoteConfigGateway` seam** in `:shared` (mirror ProfileGateway/LanguageDataSource); platform impl injects Firebase RC; feed the 30+ keys into `ShieldConfig`/`DetectionThresholds`. | engineer sign-off |
| D-7 | iOS scope | **Full Android + iOS parity this pass.** iOS targets (iosArm64 + iosSimulatorArm64) already configured; plugin has `iosMain` seams (`shieldIosModules()`). Thread `expect/actual` through **every** phase (not a deferred Phase H). | engineer sign-off |
| D-8 | State model | **Add fields** to `KavachHomeUiState` (`recording`, `monitoringOnly`, `sosMode`, `lowStorage`); keep `KavachState` for the card headline. Avoids a combinatorial enum. | recommendation |
| D-9 | SOS alert sheet placement | **D2 state overlay** (like the other sheets, `SnabbitBottomSheet(visible=...)`), not a nav destination. | recommendation; `KavachHomeScreen.kt:79` |

**Consequences for the plan below:**
- D-1/D-2 ⇒ Phase B is a THIN binding to `ShieldController` (no recording/detection re-impl); map `ShieldEvent.*` → DataSource/coordinator; SOS-machine (§2) consumes `SoSTriggered` + `NotificationAction`; analytics (§P-9) consumes `Instrumentation`.
- D-7 ⇒ every phase carries iOS `expect/actual` + `iosSimulatorArm64` test compile; Phase H folds into A–G.
- D-4/D-6 ⇒ two new pinned deps/seams (SQLDelight, RemoteConfigGateway) land in Phase E and Phase F respectively.
- D-5 fully resolved ⇒ CN-* items concretized against `shield-enablement-consent-autorecord-contract.md`; enablement signals (partner/customer/auto) added to §3.

### Backend contract — verified in `snabbit-tech/maestro-core` (deltas that touch this plan)

Full detail in `shield-enablement-consent-autorecord-contract.md §9`. KMP-relevant facts:

| Finding (verified) | Plan impact |
|---|---|
| The 3 flags are **backend-computed** — KMP consumes them, never derives: `consent_enabled` = persisted `Job.shield_consent_enabled` snapshot (set at booking from customer TnC acceptance); `auto_enabled` = live `tnc/snabbit_shield` config; `enabled` = runner cluster ∈ **`safety_shield_config.enabled_cluster_ids`** (a *different* config). | CN-1/CN-6: consume as-is from `/current_state` + `/runners/me`; **do not reproduce the rules**. |
| Runner `consent_version` is **persisted but never reconciled** server-side (no runner "latest-version-accepted" check). | CN-3: still send `consent_version:'1.0'`; **re-prompt-on-drift would be NEW behaviour, not parity** — confirm before building. |
| Backend decrypt = **RSA-OAEP-SHA256 unwrap + AES-GCM**; backend is **key-rotation-ready** (`SAFETY_SHIELD_RSA_CURRENT_VERSION` + `SAFETY_SHIELD_RSA_OLD_KEYS`, per-recording `key_version`). | R-2/R-4: send correct envelope + `key_version`; **G5 (no rotation) is client-side only** — prefer a server-driven/rotatable public key over the bundled asset. |
| Backend runs **server-side distress analysis on uploaded clips (Gemini) and can auto-`initiate_sos`** — independent of on-device ML. | S-5/P-1: the app must handle a **backend-originated SOS push** (and E3 reconcile) even when on-device ML is off. |
| `upload-complete` creates a `SafetyShieldRecording` (status VERIFIED); duplicate = 409 by `s3_key`. | Q-1: 409-as-success handling confirmed. |

---

## 1. Pending UI work (parity to Flutter shield UI)

Current KMP UI is skeletal; Flutter reference behaviour is in the client doc §8.

| # | Item | Current KMP | Target (parity) | Depends |
|---|---|---|---|---|
| U-1 | **SOS alert bottom sheet** ("are you in danger?") | **MISSING entirely** | Sheet with primary/secondary CTAs + **auto-deny countdown timer** (RC `shieldSosAlertDisplaySecs`=20); shown on SOS trigger; state-driven | D-9, §2 SOS machine |
| U-2 | **Kavach card full states** | IDLE/ACTIVE only | recording / monitoring-only / SOS / low-storage / idle visuals; waveform (SnabbitLottie), pulse dot, storage banner→settings (C11) | D-8 |
| U-3 | **Consent sheet parity** | static `ConsentSheetContent`, plain-text T&C | 3 feature rows (Protect/Monitoring/SOS) + **T&C via SnabbitRichText link** to privacy PDF + loading state + real activate flow | §3 consent |
| U-4 | **Activation sheet + show-cap** | generic InfoSheet only | dedicated activation sheet shown on start, capped by RC `shieldActivationSheetMaxShowCount`=10 (persisted count) | §2 |
| U-5 | **SOS active screen finish** | siren placeholder, no back guard | real siren illustration/animation; **back-intercept → endSos (C1)**; call-team + end wired to real API | §2, A-* assets |
| U-6 | **No-storage pill** | banner present | tie to real `conditions()` NO_STORAGE; retry re-checks | §5 preconditions |
| U-7 | **Assets** | ColorPainter placeholders | export siren, shield icons, feature icons, low-battery, storage-warning, background circles, waveform lottie → `composeResources/drawable` | — |
| U-8 | **Localization** | fallback `strings_kavach.xml` | server-driven Strings seam parity; no hardcoded copy | — |
| U-9 | **Accessibility** (build-feature Gate 5) | not audited | content descriptions on icon-only controls, ≥48dp targets, semantics for state changes | — |
| U-10 | **Res package cleanup** | `android.shared.generated.resources` (ugly) | set `packageOfResClass` | — |

---

## 2. Pending: SOS flow + APIs (DataSourceImpl + state machine)

Backend spec = backend doc §2A (E1-E4). Behaviour spec = client doc §6 (coordinator state machine).

| # | Item | Target | Gap ref |
|---|---|---|---|
| S-1 | SOS endpoints in KMP | E1 `POST /sos/initiate`, E2 `POST /sos` (confirm/deny/dismiss), E3 `GET /sos/active`, E4 `POST /phone_call/{n}` via Ktor; request/response per backend doc | — |
| S-2 | `sos_id` propagation | thread id from initiate through resolve; don't drop it (C2) | C2, G3 |
| S-3 | Retry/backoff on SOS calls | at least initiate; recover if backend never registered SOS | G2 |
| S-4 | Idempotency | idempotency key on E1/E2 (server dedup, not only local guards) | G4 |
| S-5 | Port SOS state machine | idle→initiating→alert→confirm/deny→active→resolve; reentrancy guards; auto-deny timer; push-driven transitions (callApi:false); resume reconcile via E3; guard the reconcile-denied asymmetry. **Also handle backend-originated SOS** (server distress analysis can `initiate_sos` with no local trigger) — arrives as a push/reconcile | C3 |
| S-6 | SOS active back-handling | back/predictive-back must end SOS or be blocked (C1) | C1 |
| S-7 | Call-team fallback | RC fallback phone when `ph_no` absent; dialer fallback | — |
| S-8 | Analytics parity | `expertShieldSos*` events (initiate/confirm/deny/deescalate/sync/desync/…) | — |

Current: `raiseSos()` = `triggerSos()` (no-op) + `nav.navigate(SosActive)`; `markSafe()`/`callSosTeam()` call no-op stubs. All of S-* replaces the stub.

---

## 3. Pending: enablement + consent

Full verified contract = **`shield-enablement-consent-autorecord-contract.md`**. Two "consent" concepts (keep distinct): **customer** (per-job `widget_data.snabbit_shield_consent_enabled`) gates `_isShieldEnabled`; **runner** (`/runners/me` → `consent_given`) gates SOS + shield-start.

| # | Item | Target | Ref |
|---|---|---|---|
| CN-1 | Enablement signals | mirror `safety_shield.enabled` (partner) + `widget_data.snabbit_shield_consent_enabled` (customer) + `snabbit_shield_auto_enabled` (auto) + `consent_given` (runner); combine `_isShieldEnabled = partner && customer`, `autoStart = enabled && auto && jobId` | contract §1-2 |
| CN-2 | Runner-consent activate API | `POST /runners/me/safety-shield/consent` body `{consent:true, consent_version:'1.0'}`; success=200→set consent locally; response not parsed | contract §3 |
| CN-3 | Consent **version** | **send `consent_version`** (contract requires it). Re-prompt-on-drift is NOT in the live contract (E1) — OPTIONAL KMP improvement; flag before adding | contract E1 |
| CN-4 | Consent **revoke** | **none to build** — write-once-true; re-read `consent_given` from profile refetch (backend un-sets) | contract E2 |
| CN-5 | Gating + prompt | runner-consent gates SOS + start (`ensureConsent`); null→needs-consent; widget blocklist `[RUNNER_JOB_POST_ACCEPT, RUNNER_JOB_CHECK_IN, RUNNER_NEW_JOB, RUNNER_SUSPENDED]` | contract §4 |
| CN-6 | Authoritative source | backend `/runners/me` via ProfileGateway seam + `/current_state` seam for widget flags; no local persistence, re-hydrate each fetch | contract §5, D-5 |
| CN-7 | Auto-record trigger | trigger enum auto/manual/sos; **auto never prompts mic** (silent degrade), manual persists a breadcrumb, pre-check-in mic hard-gate when consent+auto; feed cadence via RC | contract §6, E5-E7 |

Current: `ConfirmConsent` → `dataSource.activate()` (no-op) → `KavachState.ACTIVE`. No API/enablement/version/persistence.

---

## 4. Pending: recording + encryption pipeline

Spec = backend doc §2B/§2C, client doc §5.

| # | Item | Target | Gap ref |
|---|---|---|---|
| R-1 | Receive encrypted-audio events | subscribe to engine's encrypted-audio stream (jobId snapshot, bytes, aesKey, iv, authTag) | D-2 |
| R-2 | RSA-wrap AES key | RSA-OAEP-256 wrap in app (Tink is already a KMP dep per KmpBootstrap) using bundled/rotatable public key; then **discardAESKey** | C14, G5 |
| R-3 | Envelope metadata | build `{encrypted_key, iv, auth_tag, algorithm, key_wrap_algorithm, key_version, is_compressed}` for upload-confirm | G9, C15 |
| R-4 | Key rotation | **Backend is rotation-ready** (`SAFETY_SHIELD_RSA_OLD_KEYS` + per-recording `key_version`) — G5 is client-side only. KMP: send `key_version`; prefer a server-driven/rotatable public key over Flutter's bundled `v1` asset | G5, C14 |
| R-5 | Fail-closed handling | if encryptor unavailable, decide drop-vs-defer explicitly (Flutter silently drops) | C14, C6 |

---

## 5. Pending: upload queue, local DB, backend sync

Spec = backend doc §2B/§2D.

| # | Item | Target | Gap ref |
|---|---|---|---|
| Q-1 | 3-step upload | GET presigned-url → PUT bytes→S3 (no auth headers) → POST upload-complete; 409=success | — |
| Q-2 | Durable outbox | KMP DB (D-4): encrypted bytes + metadata + retry state; survive restart; flush on boot | — |
| Q-3 | Ordering/sequencing | oldest-first; `next_attempt_at` gate; single-flight | — |
| Q-4 | Retry/backoff + cap | 5 retries, exp backoff 30-min cap; 7-day/20-item cap (SOS protected) | — |
| Q-5 | Memory safety | LIMIT the dequeue (Flutter loads all BLOBs at once) | G12 |
| Q-6 | Concurrency/isolate safety | avoid cross-isolate double-process; transactions/WAL | G13, G14 |
| Q-7 | Retention runs off enqueue-only | run purge on a timer/boot too | G15 |
| Q-8 | DB-at-rest | decide SQLCipher-equivalent vs rely on envelope | G8 |
| Q-9 | Logout teardown | clear queue on 401/logout (anti cross-user) | — |

---

## 6. Pending: push routing, RemoteConfig, preconditions, lifecycle, peripherals

| # | Item | Target | Gap ref |
|---|---|---|---|
| P-1 | FCM SOS push routing | foreground + **killed-state persistence** (ShieldSosPushStore equivalent) → drain on resume. Note pushes may be **backend-originated** (server distress auto-SOS), not just echoes of local triggers (see S-5) | C5 |
| P-2 | RemoteConfig seam | wire all 30+ shield keys (client doc §10); push config to engine at init; drop dead `shieldStartDelayMins`; central defaults (no inline drift) | C17, D-6 |
| P-3 | Precondition gate chain | consent → mic → battery → storage → encryptor → queue, in order; analytics on every gate (Flutter has silent returns) | C7 |
| P-4 | Battery/storage checks | real signals into `conditions()`; fix 100%-fallback + silent-swallow | C12 |
| P-5 | Permissions | mic + location (+ any bg needs); check/request/settings-redirect; hard-gate parity | — |
| P-6 | Deterrence audio | play + **restore volume** after (Flutter leaves it at 1.0) | C13 |
| P-7 | Lifecycle | start on job-start/auto/resume; stop on job-end/logout; app resume/pause reconcile; dispose flushes last clip | C18 |
| P-8 | `conditions()` source | battery/storage/keep-phone monitors → `KavachCondition` flow (currently `emptyFlow`) | — |
| P-9 | Engine event streams | recording/monitoring/error/permission/instrumentation → state + analytics; handle accessibility-status (Flutter log-only) | — |

---

## 7. Suggested phasing (confirm before starting each)

1. **Phase A — decisions:** resolve D-1…D-9.
2. **Phase B — engine binding:** `KavachDataSourceImpl` → real `safety-kavach` engine (activate/SOS/events). [D-1,D-2]
3. **Phase C — SOS flow:** S-1…S-8 + U-1 alert sheet + U-5 SOS screen. [D-3,D-9]
4. **Phase D — consent:** CN-1…CN-5 + U-3. [D-5]
5. **Phase E — recording/crypto/upload/DB:** R-1…R-5, Q-1…Q-9. [D-1,D-4]
6. **Phase F — config/push/preconditions/lifecycle:** P-1…P-9. [D-6]
7. **Phase G — UI polish + a11y + assets + i18n:** U-2,U-4,U-6…U-10.

iOS parity is **not a separate phase** (D-7 = full parity): every phase above lands its `expect/actual` + keeps `iosSimulatorArm64` compiling.

Each phase ends at build-feature Gate 6/7: `:shared:testDebugUnitTest` + `:shared:compileTestKotlinIosArm64` (+`iosSimulatorArm64`) green; DS-only UI; D1/D2 held; errors→AppErrorType.

---

## 8. Acceptance (definition of done)

- `KavachDataSourceImpl` no-op removed; every method backed by real engine/API/DB.
- SOS parity: initiate→alert→confirm/deny→active→resolve + push + reconcile, with retry + `sos_id` + back-handling.
- Recording→RSA-wrap→discard→queue→3-step upload→confirm, durable across restart.
- Consent (version+revoke), preconditions, RC, deterrence, lifecycle all wired.
- Card reflects all real states; alert/consent/activation/SOS UIs at parity; assets in; a11y + i18n done.
- All 34 flagged gaps (G1-G16, C1-C18) either implemented-correctly or explicitly N/A with reason.
- Tests: happy + failure + each intent path; Gate 6 green on **both** Android + iOS (D-7 full parity).

## 9. Explicit non-gaps (already handled by KMP design — do NOT re-solve)
C8 (no state triplication), C9 (no silent mutators), G1/C16 (no legacy parallel SOS), C4 (no false-alarm cruft) — the KMP MVI/nav architecture already avoids these. Keep them avoided.
