class RemoteConfigKeys {
  RemoteConfigKeys._();

  static const String forcedShorebirdReleaseConfig =
      'expert_shorebird_force_release_config';
  static const String shorebirdPatchRolloutFactor =
      'expert_shorebird_patch_rollout_factor';
  static const String shorebirdPatchCheckInterval =
      'expert_shorebird_patch_check_interval';
  static const String showPatchCodeAsLegacy =
      'expert_show_patch_code_as_legacy';
  static const String shorebirdForLoggedOutUsers =
      'expert_shorebird_for_logged_out_users';
  static const String expertAppShutdownOnNotificationError =
      'expert_app_shutdown_on_notification_error';
  static const String showEarnings = 'expert_show_earnings';
  // Block list "n/max" header cap (mirrored to KMP via KmpRemoteConfigMirror). Empty ⇒ unknown.
  static const String expertMaxBlockedCustomers =
      'expert_max_blocked_customers';
  static const String webviewBaseUrl = 'webview_base_url';

  /// String — path appended to [webviewBaseUrl] to reach the weekly lunch-slot
  /// selection page opened from the Home lunch banner. The first route to be
  /// Remote-Config-driven (every other entry lives only in `WebviewRoutes`), so
  /// the banner's destination can be re-pointed without an app release.
  /// Empty/absent ⇒ the baked-in `WebviewRoutes.lunchSlots` default.
  static const String lunchWebviewPath = 'expert_lunch_webview_path';
  static const String enableGoLiveV2 = 'enable_golive_v2';
  static const String goLiveV2ShiftHours = 'golive_v2_shift_hours';
  static const String goLiveV2RecommendedShiftsLimit =
      'golive_v2_recommended_shifts_limit';
  static const String goLiveV2ShiftTime = 'golive_v2_shift_time';
  static const String currentStatePollInterval =
      'expert_current_state_poll_interval';
  static const String enableAutoOt = 'expert_enable_auto_ot';

  /// Bool kill switch for the connectivity-reconnect `current_state` poll in
  /// [RunnerRtDataProvider]. Default-ON; set to false in Remote Config to fully
  /// disable the reconnect-poll path without a binary push.
  static const String enableConnectivityReconnectPoll =
      'expert_enable_connectivity_reconnect_poll';

  /// Global app-side kill-switch for MQTT realtime (feature #1). False ⇒ the
  /// mqtt_config cohort runs the KMP engine in poll-only mode (polls
  /// `current_state` every [currentStatePollInterval]s) instead of MQTT — the KMP
  /// screens stay, just HTTP-fed. Default true (fail-open); set false when the
  /// broker is known down. Distinct from the backend per-runner
  /// `mqtt_kmp_enabled` carried inside `mqtt_config`.
  static const String mqttEnabled = 'expert_mqtt_enabled';

  /// Kill-switch for the PartnerHome cohort shell recovery. This is a *disable*
  /// flag: RC bools read false when absent, so an absent key ⇒ recovery ON (the
  /// safe default, even if RC is unavailable). Set true to fall back to
  /// pre-recovery behaviour (loader only). A positive "_enabled" key would
  /// default the fix OFF for every cohort runner — hence the inverted semantics.
  static const String kmpCohortShellWatchdogDisabled =
      'expert_kmp_cohort_shell_watchdog_disabled';

  /// Connect-timeout (seconds) for MQTT realtime (feature #2): if the socket
  /// doesn't reach Connected within this window of engine start, the KMP cohort
  /// falls back to current_state polling — or, when the device is offline, an
  /// offline banner over the last-known state. Default 25 (native clamps to a
  /// sane minimum).
  static const String mqttConnectTimeout =
      'expert_mqtt_connect_timeout_seconds';

  /// Post-action fallback deadline (seconds) for MQTT realtime (feature #4):
  /// after a runner action, if no newer MQTT snapshot lands within this window,
  /// the KMP engine fetches current_state once as a safety net (and reports the
  /// miss). Default 5 (native clamps to a sane minimum).
  static const String mqttPostActionTimeout =
      'expert_mqtt_post_action_timeout_seconds';

  /// Bool kill switch (default-ON) for the force-update gate on the KMP (MQTT)
  /// cohort login handoff. When ON, a runner who owes a mandatory Android update
  /// ([GlobalState.isAndroidUpdateRequired]) is kept on the Flutter surface at
  /// login instead of being switched to the native KMP shell — the "Update
  /// Required" popup is a Flutter dialog the native shell would cover, which
  /// otherwise lets the cohort skip a PAN-India force update. Read Dart-side only
  /// in [RegistrationNavigation.openKMPStackForMqttCohort] /
  /// [RegistrationNavigation.openKMPStackForOfflineCohort]; not mirrored to KMP.
  /// Default-ON (fail-open to blocking, incl. when RC is unavailable): set to
  /// false in Remote Config to disable the gate — KMP opens regardless of update
  /// state — as the rollback lever if it ever misfires. NOTE: the un-block is
  /// **restart-bound**, not live — the gate is read at the cohort handoff, so
  /// flipping this to false frees a runner only on their NEXT app launch; one
  /// already parked on the non-dismissible popup stays blocked until they
  /// relaunch. Self-heals: once the runner is on a build at/above the floor the
  /// gate is inert and the handoff runs as normal.
  static const String kmpForceUpdateGateEnabled =
      'expert_kmp_force_update_gate_enabled';

  /// Bool kill switch for the KMP realtime connection-health analytics
  /// (`mqtt_recovered` / `mqtt_degraded` / `mqtt_offline` / `mqtt_stopped`).
  /// Default true (fail-open — collect by default); set false to silence the
  /// stream without a build if it proves too chatty on flaky networks.
  static const String mqttHealthAnalytics =
      'expert_mqtt_health_analytics_enabled';

  /// Bool kill switch for the native Compose (CMP) Language screen. Default-OFF
  /// — the drawer routes to the Flutter `LanguageHome` until this is enabled.
  /// The CMP screen is native (not Shorebird-patchable), so this RC flag is the
  /// rollback + staged-rollout lever.
  static const String cmpLanguageScreenEnabled =
      'expert_cmp_language_screen_enabled';

  /// Bool kill switch (default-OFF) for the native New Job **overlay** — the
  /// `RUNNER_NEW_JOB` card drawn over other apps when Snabbit isn't foreground
  /// (see `NewJobOverlayService` natively). Read here and pushed to the native
  /// launcher via `JobOverlayChannel`; the overlay (and its `SYSTEM_ALERT_WINDOW`
  /// use) stays off until this is enabled, so it's the rollout + kill lever.
  static const String expertEnableNewJobOverlay =
      'expert_enable_new_job_overlay';

  /// Bool kill switch (default-OFF) gating whether the New Job overlay is drawn
  /// **over other apps** (draw-over-apps / `SYSTEM_ALERT_WINDOW`) when Snabbit
  /// isn't foreground. Mirrored to KMP via [KmpRemoteConfigMirror]; the native
  /// overlay triggers (`JobScreenLauncherPlugin`, `SnabbitPushService`) read it
  /// through the KMP `RemoteConfigGateway` and skip starting the over-other-apps
  /// overlay unless it is true. Default false, so the overlay stays off (incl.
  /// on a cold FCM wake before the mirror is populated) until deliberately enabled.
  static const String showNewJobOverlayOnOtherApps =
      'expert_show_new_job_overlay_on_other_apps';

  /// Bool kill-switch for the KMP home top-nav red card pill (mirrored to KMP
  /// via [KmpRemoteConfigMirror]). Default OFF — the pill ships dark.
  static const String showRedCardPill = 'expert_show_red_card_pill';

  static const String enableSaathiTicketing = 'expert_enable_saathi_ticketing';

  /// Minutes-of-job-time-remaining threshold (as a numeric string) above which
  /// completing a job opens the job-end campaign step; at/below it, checkout goes
  /// straight to OTP. Default "5". Mirrored to KMP via [KmpRemoteConfigMirror]'s
  /// string snapshot; the native job screen reads it through the KMP
  /// `RemoteConfigGateway.getString(..., "5")` and compares it to the live
  /// in-progress countdown at the moment Complete Job is pressed.
  static const String jobEndCampaignMinRemainingMins =
      'expert_job_end_campaign_min_remaining_mins';

  /// Job-in-progress audio cues (ECPO-982) — per-cue **exclusion lists**: a JSON
  /// array of job durations (in minutes) for which that cue is **suppressed**. A
  /// cue plays only when the current job's duration is NOT in its list; an empty
  /// list `[]` (the default) plays for all durations. These are the sole control
  /// for each cue (no separate on/off flag).
  ///
  /// Half-time (50%) and T-minus-10 are timed + played natively in KMP, so their
  /// lists are mirrored to KMP via [KmpRemoteConfigMirror]'s string snapshot and
  /// read through `RemoteConfigGateway.getString(..., "[]")` (parsed tolerantly).
  /// Auto-checkout is push-driven + played Dart-side, so its list is read here
  /// directly (via `RemoteConfigService.getString(..., '[]')` + the same tolerant
  /// bracket/CSV parse in `_autoCheckoutAudioSuppressed`, not `getList`) and is
  /// NOT mirrored.
  static const String jobAudioHalfTimeExcludedDurations =
      'expert_job_audio_half_time_excluded_durations';
  static const String jobAudioTenMinExcludedDurations =
      'expert_job_audio_ten_min_excluded_durations';
  static const String jobAudioAutoCheckoutExcludedDurations =
      'expert_job_audio_auto_checkout_excluded_durations';

  /// Max time (ms, as a numeric string) the native KMP job actions wait for a
  /// location fix before sending the action without one. Default "500". Mirrored
  /// to KMP via [KmpRemoteConfigMirror]'s string snapshot; `CoreJobLocationProvider`
  /// reads it through `RemoteConfigGateway.getString(..., "500")`. Lower it (or set
  /// "0") to skip job-action location faster / entirely without a release.
  static const String jobLocationTimeoutMs = 'expert_job_location_timeout_ms';

  /// Bool kill switch for the native Compose (CMP) Home screen. Default-ON —
  /// `_PartnerHomeState` opens the native home shell via the KMP nav bridge
  /// on initState when this is true. The CMP screen is native (not
  /// Shorebird-patchable), so flipping this off in Remote Config is the
  /// rollback lever: PartnerHome stays the visible home until the next cold
  /// start re-evaluates the flag.
  static const String cmpHomeScreenEnabled = 'expert_cmp_home_screen_enabled';

  /// Bool kill switch (default-ON) for mirroring the runner `current_state`
  /// envelope to the KMP `shared` module (Expert App 2.0 Compose surfaces) via
  /// `RunnerStateChannel`. The push is best-effort + deduped; flip to false in
  /// Remote Config to silence the bridge without a binary push.
  static const String enablePublishRunnerStateToKmp =
      'expert_enable_publish_runner_state_to_kmp';

  /// Bool kill switch for skipping the background location isolate's redundant
  /// `current_state` poll for the `mqtt_config` cohort. Default-ON: the cohort's
  /// `current_state` is owned by the KMP `/realtime` engine (MQTT + its own poll
  /// fallback → Room), so the Dart background poll is a duplicate. Set to false in
  /// Remote Config to revert to the legacy always-poll behaviour (cohort included)
  /// without a binary push. IoT location jobs are unaffected either way.
  static const String enableMqttCohortBgCurrentStateSkip =
      'expert_enable_mqtt_cohort_bg_current_state_skip';
  static const String genericExpertAppBanner = 'generic_expert_app_banner';

  /// Bool — routes the drawer "Refer & earn" entry to the webview
  /// (`v1/referrals/home`) instead of the native `ReferralsHome`. Default OFF:
  /// the rollback + staged-rollout lever for the referrals webview migration.
  static const String isReferralsV2Enabled = 'expert_is_referrals_v2_enabled';

  /// Bool — shows the KMP bottom-nav "Notifications" tab (opens the
  /// `v1/notification-centre` webview). Default OFF: the staged-rollout lever.
  static const String isNotificationsTabEnabled =
      'expert_is_notifications_tab_enabled';

  /// String (JSON) — unified Vishwaas (`VishwaasBannerRemoteConfig` in
  /// `vishwaas_banner_remote_config.dart`).
  static const String expertVishwaasBanner = 'expert_vishwaas_banner';

  /// Legacy fallback for unified Vishwaas config when [expertVishwaasBanner] is empty.
  static const String expertVishwaasDrawerBanner =
      'expert_vishwaas_drawer_banner';

  /// Bool — top-level on/off switch for the Vishwaas rate-card banner
  /// (drawer banner + provisional-attendance bottom sheet). AND-ed with
  /// the existing `rateCardVersion == v1` check, so v2 runners never see
  /// the banner regardless of this flag. Defaults to `false` — flip to
  /// `true` in Firebase Remote Config to enable the banner for v1
  /// runners.
  static const String enableVishwaasRateCardBanner =
      'expert_enable_vishwaas_rate_card_banner';

  /// Int — max times the Vishwaas provisional rate-card bottom sheet may
  /// surface per install across all entry points (direct logout +
  /// mark-attendance-and-logout). Defaults to 3 if missing/invalid.
  static const String vishwaasProvisionalSheetMaxShowCount =
      'expert_vishwaas_provisional_sheet_max_show_count';
  static const String shieldStartDelayMins = 'expert_shield_start_delay_mins';
  static const String shieldDurationSecs = 'expert_shield_duration_secs';
  static const String shieldPauseSecs = 'expert_shield_pause_secs';
  static const String shieldActivationSheetMaxShowCount =
      'expert_shield_activation_sheet_max_show_count';
  static const String shieldBatteryBlockThreshold =
      'expert_shield_battery_block_threshold';
  static const String shieldBatteryWarnThreshold =
      'expert_shield_battery_warn_threshold';
  static const String shieldBatterySheetCooldownSecs =
      'expert_shield_battery_sheet_cooldown_secs';
  static const String shieldStorageBlockThresholdMb =
      'expert_shield_storage_block_threshold_mb';
  static const String shieldManualDurationSecs =
      'expert_shield_manual_duration_secs';
  static const String shieldManualPauseSecs = 'expert_shield_manual_pause_secs';
  static const String shieldSosDurationSecs = 'expert_shield_sos_duration_secs';
  static const String shieldSosPauseSecs = 'expert_shield_sos_pause_secs';
  static const String shieldSosDeterrenceDelaySecs =
      'expert_shield_sos_deterrence_delay_secs';
  static const String shieldMlDetectionEnabled =
      'expert_shield_ml_detection_enabled';
  // Cohort kill-switches (default OFF). Gate the two capability tiers:
  //   monitoringOnly = Layer 1b mic + ML (no clips); recording = clips + full monitoring.
  static const String shieldMonitoringOnlyEnabled =
      'expert_shield_monitoring_only_enabled';
  static const String shieldRecordingEnabled =
      'expert_shield_recording_enabled';
  static const String shieldDbSpikeThreshold =
      'expert_shield_db_spike_threshold';
  static const String shieldAccelerometerMagnitudeG =
      'expert_shield_accelerometer_magnitude_g';
  static const String shieldAccelerometerWindowSec =
      'expert_shield_accelerometer_window_sec';
  static const String shieldAccelerometerCooldownSec =
      'expert_shield_accelerometer_cooldown_sec';
  static const String shieldAccelerometerLpfAlpha =
      'expert_shield_accelerometer_lpf_alpha';
  static const String shieldAccelerometerFreefallThresholdG =
      'expert_shield_accelerometer_freefall_threshold_g';
  static const String shieldAccelerometerFreefallMinMs =
      'expert_shield_accelerometer_freefall_min_ms';
  static const String shieldAccelerometerDropSuppressMs =
      'expert_shield_accelerometer_drop_suppress_ms';
  static const String shieldYamnetConfidenceThreshold =
      'expert_shield_yamnet_confidence_threshold';
  static const String shieldYamnetTopK = 'expert_shield_yamnet_top_k';
  static const String shieldYamnetTargetClasses =
      'expert_shield_yamnet_target_classes';
  static const String shieldVadConfidenceThreshold =
      'expert_shield_vad_confidence_threshold';
  static const String shieldVolumeClickCount =
      'expert_shield_volume_click_count';
  static const String shieldVolumeClickWindowSec =
      'expert_shield_volume_click_window_sec';
  static const String shieldSosPendingDurationSecs =
      'expert_shield_sos_pending_duration_secs';
  static const String shieldSosPendingIntervalSecs =
      'expert_shield_sos_pending_interval_secs';

  /// Seconds the SOS alert bottom sheet stays open before auto-safe (deny) fires.
  /// Applies only when the app is in the foreground; backgrounding suppresses auto-deny.
  static const String shieldSosAlertDisplaySecs =
      'expert_shield_sos_alert_display_secs';
  static const String shieldAccessibilityEnabledClusterIds =
      'expert_shield_accessibility_enabled_cluster_ids';
  static const String shieldAccessibilityDialogMaxShowCount =
      'expert_shield_accessibility_dialog_max_show_count';
  // Gates the high-volume per-evaluation ML signal telemetry (`detection_signal`).
  // Enable only for the pilot cohort during threshold validation.
  static const String shieldDiagnosticsEnabled =
      'expert_shield_diagnostics_enabled';
  // Fallback SOS support number used only when the API didn't return one.
  static const String shieldSosFallbackPhone =
      'expert_shield_sos_fallback_phone';
  static const String enableAwolOverlay = 'expert_enable_awol_overlay';
  static const String enableAwolV2 = 'expert_enable_awol_v2';
  static const String awolOverlayPermissionMandatory =
      'expert_awol_overlay_permission_mandatory';

  /// Bool kill switch (default-OFF) for the **AWOL v2** (KMP) over-other-apps
  /// alert — a fresh v2 key, deliberately separate from [enableAwolOverlay] so
  /// flipping the v2 rollout never affects the legacy hybrid AWOL still running
  /// in the old app. Read here and pushed to the native launcher via
  /// `AwolOverlayChannel`; the v2 overlay stays dark until this is enabled.
  static const String enableAwolV2Overlay = 'expert_enable_awol_v2_overlay';

  /// Bool kill switch (default-OFF) for the **AWOL v2** (KMP) home card
  /// embedded in partner_home via a platform view. ON: the native card+tile
  /// render in the home column and ALL legacy in-app AWOL UI (breach home
  /// card + breach/re-entered dialogs) is suppressed. OFF: legacy behaves
  /// exactly as today. Independent of [enableAwolOverlay] (legacy overlay
  /// untouched) and [enableAwolV2Overlay] (the background surface).
  static const String enableAwolV2HomeCard = 'expert_enable_awol_v2_home_card';
  static const String expertCommonMethodsContactNumber =
      'expert_common_methods_contact_number';
  static const String expertCheckinWithoutOtpLocationAccuracyBuffer =
      'expert_checkin_without_otp_location_accuracy_buffer';
  static const String expertSosContactNumber = 'expert_sos_contact_number';

  /// Saathi helpline number dialled by the KMP home Saathi pill (mirrored to KMP
  /// via [KmpRemoteConfigMirror]). Default: app-webview's "Call Saathi" number.
  static const String expertSaathiHelplineNumber =
      'expert_saathi_helpline_number';
  static const String expertProvisionalAttendanceBottomsheetCloseTime =
      'expert_provisional_attendance_bottomsheet_close_time';
  static const String expertEnableSundayAttendanceNudge =
      'expert_enable_sunday_attendance_nudge';
  static const String expertRootDetectionEnabled =
      'expert_root_detection_enabled';

  // BCP (Business Continuity Plan) — see lib/services/bcp/
  static const String expertBcpEnabled = 'expert_bcp_enabled';
  static const String expertBcpPersistAcrossSessions =
      'expert_bcp_persist_across_sessions';
  static const String expertBcpTriggerStatus = 'expert_bcp_trigger_status';
  static const String expertBcpDefaultWindowSec =
      'expert_bcp_default_window_sec';
  static const String expertBcpEndpoints = 'expert_bcp_endpoints';

  /// Int (seconds) — how long the camera-permission bottom sheet waits
  /// after the user taps "Open Settings" before auto-dismissing. Prevents
  /// the `captureImage` RPC from being blocked indefinitely if the user
  /// never returns from settings. Defaults to 120 s (2 min).
  static const String capturePermissionSheetTimeoutSecs =
      'expert_capture_permission_sheet_timeout_secs';
  static const String isTrainingV2Enabled = 'expert_is_training_v2_enabled';

  /// Bool — when true, job-support flow routes through Ameyo instead of
  /// fetching a helpline number. Default false (existing dialler flow).
  static const String ameyoSupport = 'expert_ameyo_support';

  /// Gates the onboarding "Go live" button to the webview go-live flow
  /// (`WebviewRoutes.goLiveSelectDate`). When false/absent, the existing
  /// native flow (TrainingDetails) is used — backward compatible.
  ///
  /// Distinct from [enableGoLiveV2] (`enable_golive_v2`), which is a JSON
  /// config gating the native v2 go-live screens — this is the webview ("v3")
  /// variant and is a plain bool.
  static const String isGoLiveV3Enabled = 'expert_is_golive_v3_enabled';

  /// Bool kill-switch for the unified deeplink router (FCM `deeplink` /
  /// CleverTap `wzrk_dl` / AppsFlyer OneLink). Default-ON: enabled unless this
  /// key is explicitly set to `false` in Remote Config, in which case the router
  /// no-ops and notification handling reverts to the legacy `type`-switch
  /// behaviour. See `lib/services/deeplink/deeplink_router.dart`.
  static const String enableDeeplinks = 'expert_enable_deeplinks';

  /// Bool kill-switch for the Coralogix RUM monitoring pipeline. Defaults to
  /// `true` (ON) so behaviour is unchanged when the key is absent. Set to
  /// `false` in Firebase Remote Config to skip Coralogix SDK init entirely and
  /// no-op every log call — cheap escape hatch as we transition to Base14, and
  /// spares low-end devices the perf cost of a sink that's on its way out.
  static const String enableCoralogixMonitoring =
      'expert_enable_coralogix_monitoring';

  // Base14 (Scout) monitoring — see lib/services/monitoring/base14_monitoring_service.dart

  /// **LEGACY kill-switch — read only by builds shipped *before* the RC-config
  /// migration.** Those older builds are frozen on this key; the current build
  /// (and all future ones) read [enableBase14MonitoringV2] instead. Keep this
  /// key so you can still turn Base14 off on already-shipped older builds
  /// independently: set `expert_enable_base14_monitoring = false` to disable
  /// them without affecting the new build.
  ///
  /// Do NOT read this key in new code — use [enableBase14MonitoringV2].
  static const String enableBase14Monitoring =
      'expert_enable_base14_monitoring';

  /// Bool kill-switch for the Base14 (Scout) pipeline, **scoped to this build
  /// and every build after it**. Introduced with the Remote-Config-driven
  /// config migration so enabling/tuning the new Base14 integration never
  /// touches older builds (which can't read this key and stay on the legacy
  /// [enableBase14Monitoring] flag).
  ///
  /// Defaults to `true` (ON) — Base14 runs unless this key is explicitly
  /// `false`. When absent / RC unavailable, the default keeps it enabled;
  /// init still no-ops gracefully if the endpoint is unconfigured or
  /// `ScoutFlutter.initialize` throws.
  ///
  /// Endpoint + ingest token are Remote-Config-driven ([base14Endpoint],
  /// [base14IngestToken] below) with compile-time fallbacks. Prod vs staging
  /// is signalled by the `serviceName` / `environment` labels on the OTLP
  /// payload rather than by a separate endpoint.
  ///
  /// All Base14 config is read **once at init** (cold-start semantics, like
  /// the rest of these keys): flipping this or any base14 key in Firebase
  /// takes effect on the next app launch, not the running session.
  static const String enableBase14MonitoringV2 =
      'expert_enable_base14_monitoring_v2';

  /// Double — Scout session sampling rate (0-100, percent). Applied to
  /// `ScoutFlutterConfig.sessionSampleRate` at init. Defaults to `100.0`
  /// (all sessions) during rollout so telemetry actually populates. Dial
  /// this down in Firebase Remote Config once ingest volume matters —
  /// e.g. set to `25.0` for a 25% sample. Values outside 0-100 are clamped
  /// by the SDK.
  ///
  /// Note: Base14MonitoringService sets `alwaysCaptureErrors: false` so this
  /// dial genuinely governs ALL Scout output — spans, logs, and error-class
  /// spans alike. Crashes stay authoritative in Firebase Crashlytics
  /// independent of this dial.
  static const String base14SessionSampleRate =
      'expert_base14_session_sample_rate';

  /// String — Base14 (Scout) OTLP collector endpoint. Overrides the
  /// compile-time [base14Endpoint] fallback so the URL is swappable without a
  /// binary push. Empty/absent → falls back to the code constant.
  static const String base14Endpoint = 'expert_base14_endpoint';

  /// String — Base14 (Scout) RUM ingest token (sent as `Bearer`). Overrides
  /// the compile-time fallback so the key is rotatable via Remote Config.
  /// Publishable client-side RUM key (same class as the Coralogix `publicKey`);
  /// empty/absent → code fallback. Empty resolved value → no Authorization
  /// header at all.
  static const String base14IngestToken = 'expert_base14_ingest_token';

  /// JSON blob — every Base14 (Scout) behavioural dial (metrics switches,
  /// auto-instrumentation toggles, thresholds, session + offline tuning, and
  /// optional `serviceName` / `environment` / `firstPartyHosts` overrides).
  /// Parsed field-by-field in [Base14MonitoringService]: any missing or
  /// wrong-typed field falls back to its current default, and a malformed blob
  /// falls back to defaults wholesale (one non-fatal recorded to Crashlytics).
  /// The kill-switch, endpoint, token and sample-rate live in their own typed
  /// keys above — not in this blob.
  static const String base14Config = 'expert_base14_config';
}
