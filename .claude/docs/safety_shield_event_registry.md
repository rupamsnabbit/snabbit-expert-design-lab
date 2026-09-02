# Safety Shield — Final Event Registry

> **Last updated:** 2026-06-17
> **Branch:** `feat/shield-ml-signal-validation`
> **Total product analytics events:** 48 (all prefixed `expert_shield_`)
> **Analytics planes:** CT = CleverTap · MP = Mixpanel · CX = Coralogix

---

## How events are emitted

| Path | Planes | Used by |
|---|---|---|
| `_trackShieldEvent(name, props)` in `safety_shield_adapter.dart:823` | CX + CT + MP | Adapter, coordinators, event handler |
| `ClevertapSetup.logEvent` + `MixpanelSetup.logEvent` (paired) | CT + MP | UI widgets that can't access the adapter |
| `MonitoringServiceHelper.logInfo('shield_<key>', ...)` in `shield_event_handler.dart:368` | CX only | Native instrumentation forwarding |

> **Rule:** UI widgets must never fire analytics directly for events the adapter already owns.
> The adapter is the canonical owner for all non-UI-widget events.

---

## 1 — Banner / Card

**Source:** `snabbit_shield_card.dart` (visibility/CTA) · `safety_shield_adapter.dart` (state transitions)

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_banner_visible` | CX+CT+MP | Shield card transitions from hidden → visible on the home screen (adapter: visibility state change, not widget mount) |
| `expert_shield_banner_hidden` | CX+CT+MP | Shield card transitions from visible → hidden (cluster disabled or runner becomes ineligible mid-session) |
| `expert_shield_banner_cta` | CX+CT+MP | Runner taps "Activate Shield" CTA; fires inside `onStartMonitoringTapped` before any async work |

---

## 2 — Lifecycle

**Source:** `shield_event_handler.dart` · `shield_start_stop_controller.dart` · `safety_shield_adapter.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_started` | CX+CT+MP | Native confirms `RecordingState.recording` and prior state was NOT paused — fresh start |
| `expert_shield_resumed` | CX+CT+MP | Native confirms `RecordingState.recording` after a `paused` state — audio interruption cleared |
| `expert_shield_paused` | CX+CT+MP | Native sends `RecordingState.paused` — audio focus lost (incoming call, media playback) |
| `expert_shield_stopped` | CX+CT+MP | Runner manually stops shield, or job ends and shield auto-stops |
| `expert_shield_rc_fallback` | CX+CT+MP | Remote Config key fetch fails; shield falls back to hardcoded defaults |
| `expert_shield_permission_changed` | CX+CT+MP | Native reports any permission status change (microphone, notification) |
| `expert_shield_storage_warning` | CX+CT+MP | Available storage is low but shield is allowed to start; state transitions low → not-low only |
| `expert_shield_storage_full` | CX+CT+MP | Gate 3 blocks shield start — storage insufficient for a new recording session |

---

## 3 — Error

**Source:** `shield_start_stop_controller.dart` · `shield_event_handler.dart` · `safety_shield_adapter.dart` · `snabbit_shield_permission_handler.dart`

All route through `expert_shield_error`. The `error` property identifies the specific failure.

| `error` value | Trigger scenario |
|---|---|
| `job_started_failed` | `onJobStartedAndAutoStart` fires but shield fails pre-init check |
| `init_failed` | Gate 0 — `ensureInitialized()` returns false |
| `consent_denied` | Gate 1 — runner has not given consent |
| `battery_too_low` | Gate 2 — battery level below threshold RC key |
| `storage_insufficient` | Gate 3 — storage cap exceeded (also fires `expert_shield_storage_full`) |
| `encryptor_failed` | Gate 5 — RSA encryptor null after init |
| `upload_queue_null` | Gate 6 — upload queue not initialised |
| `reinit_failed` | Service not running; reinit attempt returned false |
| `reinit_retry_failed` | Reinit succeeded but second start attempt also failed |
| `start_failed` / `platform_exception` | Platform channel threw `PlatformException` on `start()` |
| `start_failed` / `generic_exception` | Unhandled exception during `start()` |
| `mic_permission_revoked` | Mic permission revoked while shield is active (detected on `resume`) |
| `native_error` | Native plugin sent an error event via `onError` stream |
| `mic_permission_denied` | Permission request completed with denied status |
| `mic_permission_permanently_denied` | Permission permanently denied; opens app settings |

---

## 4 — Consent Bottom Sheet

**Source:** `shield_consent_provider.dart` · `ui/shield_consent_bottom_sheet.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_consent_bs` | CT+MP | Consent bottom sheet presented to runner (first activation after cluster enables shield) |
| `expert_shield_consent_cta` | CT+MP | Runner taps "I Agree" / accept CTA |
| `expert_shield_consent_success` | CT+MP | Consent API call returns success |
| `expert_shield_consent_given` | CT+MP | Consent confirmed and persisted to provider — shield is unblocked |
| `expert_shield_consent_error` | CT+MP | Consent API call fails, or persistence throws |
| `expert_shield_consent_dismiss` | CT+MP | Runner swipes down or taps backdrop without agreeing |

---

## 5 — Activation Info Sheet

**Source:** `shield_ui_prompts.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_info_bs` | CX+CT+MP | Info / explainer bottom sheet shown (first-time flow or runner taps info icon) |
| `expert_shield_info_cta` | CX+CT+MP | Runner taps the primary CTA ("Got it" / "Activate") on the info sheet |
| `expert_shield_info_dismiss` | CX+CT+MP | Runner swipes down or taps backdrop to dismiss info sheet |

---

## 6 — SOS Alert Sheet

**Source:** `sos_flow_coordinator.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_sos_alert_bs` | CX+CT+MP | SOS alert bottom sheet shown to runner after a native trigger is received |
| `expert_shield_sos_alert_confirm_click` | CX+CT+MP | Runner taps "Yes, I need help" on the alert sheet |
| `expert_shield_sos_alert_deny_click` | CX+CT+MP | Runner taps "No, I'm fine" / false alarm on the alert sheet |

---

## 7 — SOS Active Screen

**Source:** `ui/sos_active_screen.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_sos_active_load` | CT+MP | SOS active screen mounted — SOS is confirmed and live |
| `expert_shield_sos_active_call_team_cta` | CT+MP | Runner taps "Call Safety Team" on the active SOS screen |
| `expert_shield_sos_active_end_sos_cta` | CT+MP | Runner taps "End SOS" on the active SOS screen |

---

## 8 — SOS Flow

**Source:** `sos_flow_coordinator.dart` · `safety_shield_adapter.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_sos_initiated` | CX+CT+MP | SOS initiation API call made — alert sheet is being shown |
| `expert_shield_sos_initiate_failed` | CX+CT+MP | SOS initiation API returns an error |
| `expert_shield_sos_sheet_skipped` | CX+CT+MP | Backend sync returns a confirmed SOS before the sheet is shown — auto-confirmed without runner interaction |
| `expert_shield_sos_concurrent_overridden` | CX+CT+MP | A second native SOS trigger arrives while one is already in progress — suppressed |
| `expert_shield_sos_push_drained` | CX+CT+MP | FCM SOS push action was buffered while app was backgrounded — drained and forwarded on foreground |
| `expert_shield_sos_notification_confirm_tap` | CX+CT+MP | Runner taps "Confirm SOS" on the foreground service notification |
| `expert_shield_sos_confirmed` | CX+CT+MP | Runner confirms SOS on the alert sheet and confirm API succeeds |
| `expert_shield_sos_sync_confirmed` | CX+CT+MP | Sync/reconciliation call returns a confirmed SOS state — no runner action needed |
| `expert_shield_sos_denied` | CX+CT+MP | Runner denies SOS (false alarm, timeout, or OS backgrounding dismissal path) |
| `expert_shield_sos_sync_denied` | CX+CT+MP | Sync call returns a denied SOS state |
| `expert_shield_sos_deny_api_failed` | CX+CT+MP | Deny API call returns an error |
| `expert_shield_sos_deescalated` | CX+CT+MP | SOS de-escalated via the active screen ("situation resolved") |
| `expert_shield_sos_deescalate_error` | CX+CT+MP | De-escalation API call fails |
| `expert_shield_sos_synced` | CX+CT+MP | Sync call completes successfully and state is reconciled |
| `expert_shield_sos_state_desync` | CX+CT+MP | Local SOS state does not match server state after sync — drift detected |
| `expert_shield_deterrence_played` | CX+CT+MP | Deterrence audio clip played as part of SOS response flow |

---

## 9 — Upload

**Source:** `snabbit_shield_upload_queue.dart`

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_upload_success` | CT+MP | All 3 upload steps succeed (presigned URL → S3 PUT → confirm) — clip removed from queue |
| `expert_shield_upload_dropped` | CT+MP | Clip exhausts 5 retries across any step — permanently dropped, `reason: clip_max_retries_exceeded` |

---

## 10 — Native Milestones (Kotlin → CT+MP)

**Source:** `SafetyMonitoringService.kt` → EventChannel `/instrumentation` → `shield_event_handler.dart`

Debounced 1 000 ms per event name. Mapped via `ShieldEventHandler._nativeToProductEvent` (constants in `TrackingEvents`).

| Event | Planes | Trigger scenario |
|---|---|---|
| `expert_shield_native_plugin_lifecycle` | CX+CT+MP | Plugin initialised, shutdown, or fatal init failure |
| `expert_shield_native_session_lifecycle` | CX+CT+MP | Job started or job ended in the native foreground service |
| `expert_shield_native_recording_state` | CX+CT+MP | Native recording started or stopped (reason included in properties) |
| `expert_shield_native_monitoring_state` | CX+CT+MP | Native monitoring active or idle (reason included in properties) |
| `expert_shield_native_burst_recording` | CX+CT+MP | Burst recording started at SOS trigger point |
| `expert_shield_native_sos_triggered` | CX+CT+MP | Native SOS trigger fired — source: `ml` / `accelerometer` / `volumeButton` / `manual` |
| `expert_shield_native_sos_resolved` | CX+CT+MP | Native SOS state machine resolved — confirm / deny / timeout |
| `expert_shield_native_permission_changed` | CX+CT+MP | Native permission status changed (microphone, notification) |

---

## 11 — Coralogix-only (Native Observability)

**Source:** `SafetyMonitoringService.kt` → `shield_event_handler.dart:368`

Prefix: `shield_<native_key>`. **Not forwarded to CT or MP.**
`detection_evaluated` throttled to 1 000 ms; all others full-fidelity.

| Coralogix event name | Native key constant | Trigger scenario |
|---|---|---|
| `shield_clip_encrypted` | `nativeKeyClipEncrypted` | Per-clip AES encryption success or failure |
| `shield_audio_capture_stopped` | `nativeKeyAudioCaptureStopped` | `AudioRecord` stopped — reason included |
| `shield_detection_evaluated` | `nativeKeyDetectionEvaluated` | Per-frame ML pipeline result (throttled 1 000 ms) |
| `shield_detection_signal` | `nativeKeyDetectionSignal` | Full detection match — all 3 ML gates passed |
| `shield_shake_motion_detected` | `nativeKeyShakeMotionDetected` | Accelerometer shake event — magnitude and reversal count included |
| `shield_service_state_changed` | `nativeKeyServiceStateChanged` | FGS created, destroyed, or `onTaskRemoved` |
| `shield_notification_display_failed` | `nativeKeyNotificationDisplayFailed` | FGS notification failed to post |
| `shield_notification_action_null_callback` | `nativeKeyNotificationActionNullCallback` | Notification button tapped but Flutter callback was null |
| `shield_model_load_partial_failure` | `nativeKeyModelLoadPartialFailure` | One ML model failed to load (Silero or YAMNet) |

> The 8 native milestone events (section 10) also flow to Coralogix as `shield_<key>` in addition to CT+MP.

---

## Constants reference

All event name strings are defined as compile-time constants in
[`lib/utils/tracking_events.dart`](../lib/utils/tracking_events.dart).

| Constant group | Prefix | Count |
|---|---|---|
| `expertShield*` | `expert_shield_` | 40 |
| `expertShieldNative*` | `expert_shield_native_` | 8 |
| `nativeKey*` (milestone) | raw Kotlin key | 8 |
| `nativeKey*` (observability-only) | raw Kotlin key | 9 |

---

## Event count summary

| Section | Events | Planes |
|---|---|---|
| Banner | 3 | CX+CT+MP |
| Lifecycle | 8 | CX+CT+MP |
| Error (sub-types of `expert_shield_error`) | 15 `error` values | CX+CT+MP |
| Consent | 6 | CT+MP |
| Info sheet | 3 | CX+CT+MP |
| SOS alert sheet | 3 | CX+CT+MP |
| SOS active screen | 3 | CT+MP |
| SOS flow | 16 | CX+CT+MP |
| Upload | 2 | CT+MP |
| Native milestones | 8 | CX+CT+MP |
| **Total product analytics (CT+MP)** | **48** | |
| Coralogix-only native | 9 (+8 shared) | CX only |

---

## Remote Config — Complete Recording Configuration

All keys use the `expert_shield_` prefix. All are read via `RemoteConfigService.instance` with inline defaults.

### Recording Intervals — Normal Monitoring

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_duration_secs` | `shieldDurationSecs` | **5 s** | `recordingDurationSec` | Clip length during passive monitoring |
| `expert_shield_pause_secs` | `shieldPauseSecs` | **5 s** | `recordingIntervalSec` | Gap between clips during passive monitoring |

### Recording Intervals — Manual Trigger

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_manual_duration_secs` | `shieldManualDurationSecs` | **5 s** | `monitoringDurationSec` | Clip length when runner manually activates |
| `expert_shield_manual_pause_secs` | `shieldManualPauseSecs` | **5 s** | `monitoringIntervalSec` | Gap between clips in manual mode |

### Recording Intervals — SOS Confirmed

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_sos_duration_secs` | `shieldSosDurationSecs` | **10 s** | `sosRecordingDurationSec` | Clip length during active SOS — longer for evidence capture |
| `expert_shield_sos_pause_secs` | `shieldSosPauseSecs` | **1 s** | `sosRecordingIntervalSec` | Near-continuous; 1 s gap only |

### Recording Intervals — SOS Pending (Alert Phase)

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_sos_pending_duration_secs` | `shieldSosPendingDurationSecs` | **5 s** | `sosPendingDurationSec` | Clip length while alert sheet is on screen (pre-confirm) |
| `expert_shield_sos_pending_interval_secs` | `shieldSosPendingIntervalSecs` | **5 s** | `sosPendingIntervalSec` | Gap between clips during alert display window |

### ML Detection

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_ml_detection_enabled` | `shieldMlDetectionEnabled` | **false** | `mlDetectionEnabled` | Master toggle; emulator safety check applied on top |
| `expert_shield_yamnet_confidence_threshold` | `shieldYamnetConfidenceThreshold` | **0.60** | `yamnetConfidenceThreshold` | Min YAMNet class score to count as a signal (conservative vs 0.50 doc default) |
| `expert_shield_yamnet_top_k` | `shieldYamnetTopK` | **10** | `yamnetTopK` | Top-K classes evaluated per inference frame |
| `expert_shield_vad_confidence_threshold` | `shieldVadConfidenceThreshold` | **0.50** | `vadConfidenceThreshold` | Silero VAD gate (official default) |
| `expert_shield_db_spike_threshold` | `shieldDbSpikeThreshold` | **15.0 dB** | `dbSpikeThreshold` | dB spike gate; ML pipeline only runs above this |
| `expert_shield_diagnostics_enabled` | `shieldDiagnosticsEnabled` | **false** | `diagnosticsMode` | Per-frame ML telemetry to Coralogix; high-volume — pilot cohort only |

### Accelerometer — Shake Detection

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_accelerometer_magnitude_g` | `shieldAccelerometerMagnitudeG` | **2.7 G** | `accelerometerMagnitudeG` | Total magnitude incl. gravity; experimentally optimal shake threshold |
| `expert_shield_accelerometer_window_sec` | `shieldAccelerometerWindowSec` | **5.0 s** | `accelerometerWindowSec` | Window within which reversals must occur |
| `expert_shield_accelerometer_cooldown_sec` | `shieldAccelerometerCooldownSec` | **5 s** | `accelerometerCooldownSec` | Lock-out after shake detected — prevents rapid-fire triggers |

### Volume Button SOS

| RC Key | Dart Constant | Default | Plugin Field | Description |
|---|---|---|---|---|
| `expert_shield_volume_click_count` | `shieldVolumeClickCount` | **3** | `volumeClickCount` | Number of volume button presses to trigger SOS |
| `expert_shield_volume_click_window_sec` | `shieldVolumeClickWindowSec` | **1.5 s** | `volumeClickWindowSec` | Window within which all presses must fall |

### SOS Flow

| RC Key | Dart Constant | Default | Consumed in | Description |
|---|---|---|---|---|
| `expert_shield_sos_alert_display_secs` | `shieldSosAlertDisplaySecs` | **20 s** | `sos_flow_coordinator` | Duration alert sheet stays on screen before auto-denying |
| `expert_shield_sos_deterrence_delay_secs` | `shieldSosDeterrenceDelaySecs` | **3 s** | `sos_flow_coordinator._startDeterrence` | Delay after SOS confirmation before deterrence audio plays |
| `expert_shield_sos_fallback_phone` | `shieldSosFallbackPhone` | **`+918697894665`** | `ui/sos_active_screen` | Phone dialled if safety team call fails ⚠️ placeholder — confirm correct number |

### Battery & Storage Gates

| RC Key | Dart Constant | Default | Consumed in | Description |
|---|---|---|---|---|
| `expert_shield_battery_block_threshold` | `shieldBatteryBlockThreshold` | **15%** | `shield_battery_check` | Battery below this → shield blocked from starting |
| `expert_shield_battery_warn_threshold` | `shieldBatteryWarnThreshold` | **20%** | `shield_battery_check` | Battery below this → warning shown, start still allowed |
| `expert_shield_battery_sheet_cooldown_secs` | `shieldBatterySheetCooldownSecs` | **7 200 s (2 h)** | `shield_battery_check` | Min interval between low-battery warning sheets |
| `expert_shield_storage_block_threshold_mb` | `shieldStorageBlockThresholdMb` | **500 MB** | `shield_storage_check` | Free storage below this → shield blocked (Gate 3) |

### UI / Prompts

| RC Key | Dart Constant | Default | Consumed in | Description |
|---|---|---|---|---|
| `expert_shield_activation_sheet_max_show_count` | `shieldActivationSheetMaxShowCount` | **10** | `shield_ui_prompts` | Max times the activation info sheet is shown before suppressed |
| `expert_shield_accessibility_enabled_cluster_ids` | `shieldAccessibilityEnabledClusterIds` | `[]` | `shield_ui_prompts` | Cluster IDs for which the accessibility permission dialog is shown |
| `expert_shield_accessibility_dialog_max_show_count` | `shieldAccessibilityDialogMaxShowCount` | **3** | `shield_ui_prompts` | Max times the accessibility dialog is shown per runner |

### Misc / Reserved

| RC Key | Dart Constant | Default | Consumed in | Description |
|---|---|---|---|---|
| `expert_shield_start_delay_mins` | `shieldStartDelayMins` | — | Not consumed in Flutter | Defined in `remote_config_keys.dart` only; likely a native-plugin or reserved key |

---

### Config flow

All recording interval and ML keys flow through `_buildConfig()` in [`safety_shield_adapter.dart:671`](../lib/modules/snabbit_shield/safety_shield_adapter.dart) into a single `SafetyShieldConfig` passed to the native plugin on every start. Battery, storage, and UI keys are consumed inline in their respective gate files at job-start time. SOS flow keys are read on-demand inside `sos_flow_coordinator.dart`.
