import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/models/delayed_checkin/delayed_checkin_models.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/models/gamification/sheet_warning.dart';
import 'package:snabbit_runner/models/tiering/tier_nudge.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/models/sos_visibility.dart';
import 'package:snabbit_runner/models/today_shift_performance_model.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/services/auto_ot_orchestrator.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/awol_alarm_service.dart';
import 'package:snabbit_runner/services/awol_overlay_channel.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/services/realtime/realtime_channel.dart';
import 'package:snabbit_runner/services/profile_sync_channel.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/runner_state_channel.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/widgets_util.dart';

import '../services/remote_config/remote_config_keys.dart';

class WidgetInfo {
  String name;
  Map<String, dynamic>? data;

  WidgetInfo({
    required this.name,
    this.data,
  });

  factory WidgetInfo.fromMap(Map<String, dynamic> map) {
    return WidgetInfo(name: map['widget_name'], data: map['widget_data']);
  }
}

Map<String, dynamic>? _runnerStateEnvelopeAsMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

class RunnerRtDataProvider with ChangeNotifier {
  RunnerRtDataProvider({
    required this.periodLeave,
    required this.userProfile,
  }) {
    // WS5: only the refresh handler is bound — the reverse applyState bridge into
    // PartnerHome is retired; the mqtt_config cohort renders from the KMP stack
    // reading RunnerStateStore directly.
    RunnerStateChannel.bindRefreshHandler(_handleKmpRefreshRequest);
    // KMP Profile pull-to-refresh / retry → re-fetch runners/me + period-leave and
    // re-push both to the native stores (Dart owns these fetches; KMP never calls them).
    ProfileSyncChannel.bindRefreshHandler(_handleProfileRefreshRequest);
    _pushAwolOverlayFlag();
  }

  /// Pushes the AWOL v2 overlay kill-switch ([RemoteConfigKeys.enableAwolV2Overlay],
  /// default-OFF) to the native launcher, and re-pushes on Remote Config
  /// live-updates (the legacy partner_home re-initialise-on-RC-flip behaviour).
  /// Best-effort — [AwolOverlayChannel] swallows every failure.
  void _pushAwolOverlayFlag() {
    AwolOverlayChannel.sync();
    AwolOverlayChannel.listenForUpdates();
  }

  final PeriodLeaveProvider periodLeave;
  final UserProfileProvider userProfile;

  /// This param [widgetInfo] became public (from private) because it was needed for lunch functionality.
  /// BE AWARE while using this data anywhere else.
  /// IDEALLY, it shouldn't be used in [mainWidget] and only in [partner_home.dart] (and widgets required in this page NOT [mainWidget])
  WidgetInfo? widgetInfo;

  /// The full raw `current_state` envelope backing [widgetInfo] — kept so the
  /// KMP push ([_publishRunnerState]) can forward top-level siblings
  /// (`sheet_warnings`, `gold_coins_total`, `red_cards_total`) that
  /// [WidgetInfo] drops. Set in lockstep with [widgetInfo].
  Map<String, dynamic>? _lastRunnerStateEnvelope;

  /// The `tier_nudge` object — a TOP-LEVEL sibling of `widget_data` on the
  /// `current_state` envelope (NOT inside `widget_data`), so it's parsed from the
  /// whole envelope and exposed here for the applicable-tiering-nudge widget.
  /// Null when the response carries no nudge. Set in lockstep with [widgetInfo]
  /// across every cohort (poll / MQTT bridge / bg-cache).
  TierNudge? tierNudge;

  List<PreActionNudge> preActionNudges = [];
  Map<String, CtaOverride> ctaOverrideMap = {};

  /// From `GET …/emergency_logout/availability`, refreshed by
  /// [refreshLifecycleAvailability].
  Map<String, dynamic>? emergencyLogoutAvailability;
  bool emergencyLogoutAvailabilityReady = false;

  /// True when the most recent emergency-logout availability fetch failed AND
  /// the BCP gate is blocking that endpoint. The drawer uses this to render a
  /// tappable tile that routes to [BcpDegradedPage] instead of silently
  /// hiding the option.
  bool emergencyLogoutDegradedFromBcp = false;

  static const String _emergencyLogoutAvailabilityPath =
      'api/v1/runners/me/emergency_logout/availability';

  /// Bottom-sheet rows from top-level **`sheet_warnings`** (canonical; `sheetWarnings` alias) — same shape as `pre_action_nudges[]` (LLD §9.1.1).
  List<SheetWarning> sheetWarnings = [];

  bool _showLunchSelection = false;

  /// Lunch-slots banner flag from the top-level **`show_lunch_selection`**
  /// sibling of `widget_name` (same fold sites as [sheetWarnings]). Absent or
  /// non-boolean → `false`, so an older backend never flashes the banner.
  bool get showLunchSelection => _showLunchSelection;

  /// Writing this owns the `lunch_banner_shown` impression: it fires on the
  /// hidden→shown edge only. Deliberately here rather than in the banner widget
  /// — a widget-held guard resets on dispose, so leaving and returning to the
  /// home would re-count. This provider is app-lifetime, so the impression is
  /// reported once per server flip.
  set showLunchSelection(bool value) {
    final wasVisible = _showLunchSelection;
    _showLunchSelection = value;
    if (value && !wasVisible) {
      unawaited(
        ClevertapSetup.logEvent(TrackingEvents.lunchBannerShown, const {}),
      );
    }
  }

  /// Temporary override for the provisional-attendance status sent via
  /// Bifrost init data. Set right after a successful `markAttendance` API
  /// call so that webview pages opened before the next [_fetchData] cycle
  /// see the correct status. Cleared automatically in [_fetchData] once
  /// [widgetInfo] carries the canonical server state.
  String? provisionalAttendanceOverride;

  // ── Gamification balance ──
  int gamificationCoins = 0;
  int gamificationRedCards = 0;

  /// Updates the header pill counts after a post-action animation.
  /// Uses [coinsTotal]/[redCardsTotal] (authoritative from BE) when available;
  /// falls back to applying the delta when totals aren't provided.
  void applyPostActionBalance({
    int coinsDelta = 0,
    int redCardsDelta = 0,
    int? coinsTotal,
    int? redCardsTotal,
  }) {
    gamificationCoins = coinsTotal ?? (gamificationCoins + coinsDelta);
    gamificationRedCards =
        redCardsTotal ?? (gamificationRedCards + redCardsDelta);
    notifyListeners();
  }

  Timer? _timer;

  /// WS5 realtime-cohort lifecycle. Two flags so polling can be suppressed
  /// SYNCHRONOUSLY at login (no race window) while the async confirmation
  /// (native enable + KMP home open) is still in flight:
  ///  - [_mqttCohortPending]: an attempt is in flight — suppress polling, but it
  ///    may still roll back to the Flutter cohort.
  ///  - [_mqttCohort]: confirmed — the MQTT engine is the sole writer of
  ///    RunnerStateStore for the rest of the session.
  /// Both reset on a new session.
  bool _mqttCohort = false;
  bool _mqttCohortPending = false;

  /// Whether polling / the Dart→KMP writer must stand down right now (an attempt
  /// is pending OR confirmed). The three poll/writer gates check this.
  bool get _mqttCohortActive => _mqttCohort || _mqttCohortPending;

  /// True only once the realtime cohort is CONFIRMED — the wake signals
  /// (FCM-foreground, app-resume) gate on this.
  bool get isMqttCohort => _mqttCohort;

  /// True while a cohort open attempt is in flight (pending — not yet confirmed
  /// or aborted). The PartnerHome interim watchdog checks this so its reopen
  /// never races an open already standing up (e.g. navigateAfterRunnersMe's).
  bool get isMqttCohortAttemptInFlight => _mqttCohortPending;

  /// Called SYNCHRONOUSLY at login by [RegistrationNavigation] the moment the
  /// runner MIGHT be in the realtime cohort. Suppresses polling immediately so
  /// PartnerHome (which mounts next) never arms a poll — closing the
  /// check-await-arm race — until the attempt resolves via [confirmMqttCohort]
  /// or [abortMqttCohort].
  ///
  /// Returns false (a no-op) if an attempt is ALREADY pending or confirmed, so a
  /// re-fired login route (city-close / refresh / re-login) can't stand up a
  /// second engine + KMP host. Returns true only when it started a fresh attempt.
  bool beginMqttCohortAttempt() {
    if (_mqttCohortActive) return false; // already pending/confirmed → no-op
    _mqttCohortPending = true;
    stopPolling();
    return true;
  }

  /// Attempt CONFIRMED (native realtime enabled + KMP home opened) — the MQTT
  /// engine is the sole writer of RunnerStateStore from here.
  void confirmMqttCohort() {
    _mqttCohort = true;
    _mqttCohortPending = false;
    stopPolling();
  }

  /// Attempt FAILED (realtime not enabled, or the KMP home didn't open) — fall
  /// back to the Flutter polling cohort so the runner is never stranded.
  void abortMqttCohort() {
    _mqttCohort = false;
    _mqttCohortPending = false;
    resumePolling();
  }

  bool _isPolling = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFetching = false;
  // Edge detection + rate limit for the connectivity-reconnect poll. Instance
  // fields persist across the ~55 startPolling() re-subscriptions because this
  // provider is app-lifetime (single ChangeNotifierProvider in main.dart).
  DateTime? _lastReconnectPoll;
  bool _lastConnectivityWasOffline = false;
  WidgetUtil? widgetUtil;
  bool waitForFetchData = false;
  int? jobId;

  /// Default-ON kill switch for the connectivity-reconnect poll path.
  bool get _connectivityReconnectPollEnabled =>
      RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enableConnectivityReconnectPoll,
        defaultValue: true,
      );

  /// Default-ON kill switch for mirroring runner state to the KMP `shared`
  /// module (Expert App 2.0 Compose surfaces). Disable via Remote Config to
  /// silence the bridge without a binary push.
  bool get _publishRunnerStateToKmpEnabled =>
      RemoteConfigService.instance.getBool(
        RemoteConfigKeys.enablePublishRunnerStateToKmp,
        defaultValue: true,
      );

  /// How long [refreshCurrentStateAfterWebview] waits for an in-flight poll to
  /// land before issuing its own fetch. Bounded so a hung request can't pin the
  /// refresh indefinitely; the 60s poll self-heals past that.
  static const Duration _postWebviewFetchWait = Duration(seconds: 6);

  /// Cohort-aware `current_state` refresh for a webview that may have mutated
  /// server state, called when that webview closes (see
  /// [WebViewArgs.refreshCurrentStateOnClose]).
  ///
  /// Mirrors [_handleKmpRefreshRequest]'s cohort split — realtime cohort WAKEs
  /// the MQTT engine (never re-introduces a Dart poll), everyone else fetches —
  /// but deliberately skips that method's `_publishRunnerStateToKmpEnabled`
  /// gate: that flag governs the Dart↔KMP bridge, and a Flutter-cohort runner
  /// must still refresh when the bridge is switched off.
  ///
  /// Callers fire this from `dispose()` and cannot await it; [_fetchData] has
  /// no catch of its own, so failures are logged and swallowed here rather than
  /// escaping as an unhandled async error.
  ///
  /// Unlike [_handleKmpRefreshRequest] this does NOT skip when a fetch is already
  /// in flight. PartnerHome keeps polling while a webview sits on top, so a 60s
  /// tick can be mid-flight when the runner closes the page — and that request
  /// was issued BEFORE the slot selection, so its response still carries the old
  /// `show_lunch_selection`. Skipping would leave the runner staring at the
  /// banner they just acted on until the next tick. Wait for the stale one to
  /// land, then fetch; bounded so a hung request can't pin this forever (the
  /// poll self-heals within 60s anyway).
  Future<void> refreshCurrentStateAfterWebview() async {
    try {
      if (_mqttCohortActive) {
        unawaited(RealtimeChannel.wake());
        return;
      }
      final waitUntil = DateTime.now().add(_postWebviewFetchWait);
      while (_isFetching && DateTime.now().isBefore(waitUntil)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await fetchCurrentState();
    } catch (e, stack) {
      await MonitoringServiceHelper.reportError(
        'refresh_current_state_after_webview_failed',
        {'error': e.toString()},
        stack.toString(),
      );
    }
  }

  /// Reverse direction of [_publishRunnerState]: KMP (Compose VM) asked for a
  /// fresh `current_state`. Gated by the same RC kill switch — if the forward
  /// push is silenced, refresh requests are silenced too. Single-flight: skip
  /// if a fetch is already in flight ([_fetchData] has no internal guard, so
  /// two near-simultaneous requests would otherwise hit the API twice). The
  /// refreshed envelope is published back to KMP by [_publishRunnerState] at
  /// the end of [_fetchData].
  Future<void> _handleKmpRefreshRequest() async {
    if (!_publishRunnerStateToKmpEnabled) return;
    // WS5: the realtime cohort must NOT re-introduce a Dart current_state poll.
    // Instead, WAKE the MQTT engine to reconcile (HTTP current_state → DB →
    // RunnerStateProjector → RunnerStateStore → KMP screen), so pull-to-refresh
    // fetches fresh state for the cohort without any Dart polling.
    if (_mqttCohortActive) {
      unawaited(RealtimeChannel.wake());
      return;
    }
    if (_isFetching) return;
    await fetchCurrentState();
  }

  /// Mirrors the canonical [widgetInfo] envelope to the KMP `shared` module
  /// over [RunnerStateChannel] so Compose Multiplatform surfaces observe the
  /// same `current_state` the Dart UI renders.
  ///
  /// Dart stays the single source of truth — this is a one-way push.
  /// Best-effort and deduped: an unchanged envelope skips the hop, and
  /// [RunnerStateChannel.pushState] swallows+logs any failure so a bridge
  /// hiccup never disturbs polling.
  void _publishRunnerState() {
    if (!_publishRunnerStateToKmpEnabled) return;
    // WS5: the mqtt_config cohort renders from MQTT→DB→RunnerStateProjector (the
    // sole writer of RunnerStateStore for the cohort), so the Dart poll must NOT
    // also forward-push — it would fight the projector. Non-cohort KMP surfaces
    // still get the full envelope from here.
    if (_mqttCohortActive) return;
    final envelope = _lastRunnerStateEnvelope;
    if (envelope == null) return;
    // Push the whole envelope, not just {widget_name, widget_data}: KMP read
    // models fold top-level siblings (sheet_warnings, gold_coins_total,
    // red_cards_total) that WidgetInfo drops.
    RunnerStateChannel.pushState(jsonEncode(envelope));
  }

  Future<void> startPolling() async {
    // WS5: the realtime cohort never polls — the MQTT engine drives state.
    // Gated at the top (not just stopPolling) because PartnerHome re-arms via
    // resumePolling()→startPolling() while it stays mounted under the KMP stack.
    // Checks _mqttCohortActive so a pending (not-yet-confirmed) attempt also
    // suppresses the poll — no race between mount and confirmation.
    if (_mqttCohortActive) return;
    if (_isPolling) {
      _timer?.cancel();
      _connectivitySub?.cancel();
      _timer = null;
      await _fetchData();

      _timer = Timer.periodic(
        const Duration(seconds: 60),
        (timer) async {
          // WS5: any timer that outlives the cohort flip self-cancels here, so a
          // stray re-arm can't keep polling once MQTT is the source of truth.
          if (_isPolling && !_mqttCohortActive) {
            await _fetchData();
          } else {
            timer.cancel();
          }
        },
      );

      // Immediate poll on a *genuine* network reconnection. connectivity_plus on
      // Android emits frequently (onCapabilitiesChanged spam, plus a synthetic
      // current-state emit on every fresh listen) — without edge detection this
      // floods /current_state. We only poll on a real offline->online edge, and
      // rate-limit to once per 30s to cap reconnect flaps.
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        // Kill switch: Ops can disable this path via Remote Config without a
        // binary push.
        if (!_connectivityReconnectPollEnabled) return;

        final isOnline = results.any((r) => r != ConnectivityResult.none);

        // Remember an offline observation so we can detect a true offline->online
        // edge. connectivity_plus emits [none] when truly offline; sub-500ms
        // flaps may not register an edge, which is acceptable — the 60s timer is
        // the backstop.
        if (!isOnline) {
          _lastConnectivityWasOffline = true;
          return;
        }

        // Online from here. Commit edge/timestamp state only AFTER passing all
        // guards, so a reconnect landing mid-fetch isn't lost (it is handled on
        // the next event/tick instead of being silently consumed).
        if (!_isPolling || _isFetching) return;
        if (!_lastConnectivityWasOffline)
          return; // require offline->online edge

        final prev = _lastReconnectPoll;
        final now = DateTime.now();
        if (prev != null &&
            now.difference(prev) < const Duration(seconds: 30)) {
          return; // rate-limit: cap polls during a true reconnect flap
        }

        _lastConnectivityWasOffline = false; // edge consumed
        _lastReconnectPoll = now;
        try {
          MonitoringServiceHelper.logInfo('expert_state_sync', {
            'step': 'connectivity_reconnect_poll',
            'gap_since_last_ms':
                prev == null ? null : now.difference(prev).inMilliseconds,
          });
        } catch (_) {}
        _fetchData();
      });
    }
  }

  void setWaitForFetchData(bool value) {
    waitForFetchData = value;
    notifyListeners();
  }

  /// For immediate server call, call 'stopPolling()' and then 'resumePolling()'

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _connectivitySub?.cancel();
    _isPolling = false;
  }

  void resetForNewSession() {
    stopPolling();
    _mqttCohort = false;
    _mqttCohortPending = false;
    widgetInfo = null;
    _lastRunnerStateEnvelope = null;
    tierNudge = null;
    widgetUtil = null;
    _showLunchSelection = false;
    notifyListeners();
  }

  Future<void> fetchDataNow() async {
    // WS5: MQTT drives the cohort — a manual refresh must not restart the poll.
    if (_mqttCohortActive) return;
    waitForFetchData = true;
    notifyListeners();
    stopPolling();
    await resumePolling();
  }

  /// Fetch fresh data from the current_state API without disturbing the
  /// polling timer. Use this before displaying AWOL UI to ensure the
  /// countdown values are up-to-date.
  Future<void> fetchCurrentState() async {
    await _fetchData();
  }

  /// Set from selfie flow before navigating home; [PartnerHome] runs
  /// [runPendingPostLoginPollIfAny] after [resumePolling] so we poll *after*
  /// the first fetch, avoiding races with BE lag after `POST …/shift/login`.
  bool _pendingPostLoginStatePoll = false;

  void markPendingPostLoginStatePoll() {
    _pendingPostLoginStatePoll = true;
  }

  /// Re-fetch [current_state] until we leave login-style widgets or attempts
  /// are exhausted. Safe to no-op if [markPendingPostLoginStatePoll] was not set.
  Future<void> runPendingPostLoginPollIfAny() async {
    if (!_pendingPostLoginStatePoll) return;
    _pendingPostLoginStatePoll = false;
    await pollCurrentStateUntilPastLoginUi();
  }

  static const _loginSurfaceWidgetNames = <String>{
    'RUNNER_LOGIN_HOTSPOT',
    'RUNNER_LOGIN_LOCATION',
    'SELFIE_CHECK',
  };

  /// After shift login, `current_state` may still return login surfaces briefly.
  /// Uses [widgetInfo] from the fetch that just finished in [resumePolling] before
  /// issuing another GET (avoids a redundant immediate duplicate request).
  Future<void> pollCurrentStateUntilPastLoginUi({
    int maxAttempts = 15,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final name = widgetInfo?.name;
      if (name == null || !_loginSurfaceWidgetNames.contains(name)) {
        return;
      }
      await Future.delayed(interval);
      await fetchCurrentState();
    }
  }

  Future<void> resumePolling() async {
    // WS5: the realtime cohort never polls — MQTT is the sole writer. Gate here
    // too (not just startPolling), because PartnerHome re-arms via resumePolling()
    // and would otherwise set _isPolling=true and restart the timer.
    if (_mqttCohortActive) return;
    // if (_isPolling == false) {
    _isPolling = true;
    await startPolling();
    // }
  }

  void updateBgColor(Color color) {
    widgetUtil?.bgColor = color;
    notifyListeners();
  }

  void updateOnTheJobPage() {
    widgetUtil?.mainWidget =
        OnTheJob(widgetData: widgetInfo?.data); //  test this code path. VV IMP
    notifyListeners();
  }

  void updateRunnerStatus(Widget status) {
    widgetUtil?.status = status;
    notifyListeners();
  }

  void updateBottomButtonJobProgress(Widget? button) {
    widgetUtil?.bottomButton = button;
    notifyListeners();
  }

  void updateMainMessage(String msg) {
    widgetUtil?.mainMessage = msg;
    notifyListeners();
  }

  void updateMainWidget(Widget widget) {
    widgetUtil?.mainWidget = widget;
    notifyListeners();
  }

  /// Getter to access SOS visibility configuration from widget_data
  SOSVisibility? get sosVisibility {
    if (widgetInfo?.data?['sos_visibility'] != null) {
      return SOSVisibility.fromJson(widgetInfo?.data?['sos_visibility']);
    }
    return null;
  }

  /// Parses the top-level `tier_nudge` sibling from the `current_state`
  /// envelope (it is NOT inside `widget_data`). Never throws — a malformed
  /// nudge is ignored so polling is unaffected.
  TierNudge? _parseTierNudge(Map<String, dynamic>? envelope) {
    try {
      final raw = envelope?['tier_nudge'];
      if (raw is Map) {
        return TierNudge.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      // Malformed nudge — ignore so polling/state is unaffected, but log it
      // (repo rule: no silent swallow) so a persistently-bad payload is visible.
      MonitoringServiceHelper.logError('tier_nudge_parse_failed', {
        'error': e.runtimeType.toString(),
      });
    }
    return null;
  }

  /// Parsed AWOL data from the current state API response.
  AwolData? get awolData {
    final raw = widgetInfo?.data?['awol'];
    if (raw is Map<String, dynamic>) {
      return AwolData.fromJson(raw);
    }
    return null;
  }

  /// True once we've dispatched the alarm for the currently-active breach, so
  /// the alarm fires ONCE per breach — not on every 60s poll that keeps
  /// returning the same `awol` block. Reset when the breach resolves.
  bool _awolAlarmDispatched = false;

  /// Ties the AWOL alarm to AWOL-STATE detection instead of the FCM push name.
  ///
  /// The v2 AWOL path is store/poll-driven: the backend publishes a fresh
  /// `current_state` snapshot (MQTT retained, or a nameless data-only FCM wake
  /// push on fallback), so [loopSound] never reaches its AWOL branch. Here we
  /// watch the observed `awol` block and, on a NONE→breach transition, dispatch
  /// the same alarm [loopSound] plays for a named push. Called after every
  /// `widgetInfo` update ([_fetchData], [applyBridgeSnapshot],
  /// [applyCachedStateIfFresh]) so every cohort (poll / MQTT / bg-cache) is
  /// covered.
  ///
  /// De-dupe is layered: [_awolAlarmDispatched] fires the alarm once per breach
  /// episode across repeated polls, and [AwolAlarmService.playAlarm] additionally
  /// guards against a double-play if a genuine named AWOL push arrives too
  /// (event_id match + short cooldown). On resolve (RE_ENTERED) or clear, the
  /// looped audio is stopped and the guard reset so a later breach alarms again.
  void _evaluateAwolAlarm() {
    final awol = awolData;
    final isActive = awol != null && (awol.isBreach || awol.isJob);
    if (!isActive) {
      if (_awolAlarmDispatched) {
        _awolAlarmDispatched = false;
        unawaited(AwolAlarmService.stop());
      }
      return;
    }
    final eventId = awol.eventId;
    // Same active breach we already alarmed for — nothing new (a null event_id
    // keeps the whole continuous episode as one until it resolves).
    if (_awolAlarmDispatched &&
        (eventId == null || eventId == _lastAwolAlarmEventId)) {
      return;
    }
    _awolAlarmDispatched = true;
    _lastAwolAlarmEventId = eventId;
    unawaited(AwolAlarmService.playAlarm(
      awol.isJob ? AwolState.job : AwolState.breach,
      eventId: eventId,
    ));
  }

  /// The `event_id` of the breach [_evaluateAwolAlarm] last alarmed for — lets a
  /// NEW breach event (different id, no intervening resolve) re-alarm.
  String? _lastAwolAlarmEventId;

  /// Parsed delayed check-in penalty data from the current state API response.
  DelayedCheckinData? get delayedCheckinData {
    final raw = widgetInfo?.data?['delayed_checkin_penalty'];
    if (raw is Map<String, dynamic>) {
      return DelayedCheckinData.fromJson(raw);
    }
    return null;
  }

  /// Refresh period leave availability only.
  /// Handles a KMP Profile refresh request (pull-to-refresh / retry): re-fetch the
  /// runner profile + period-leave **in parallel** (independent calls); both push their
  /// fresh bodies to the native stores so the Compose Profile updates. Dart owns these
  /// fetches (KMP does not call them). Completes when both finish, so the native
  /// suspending request resolves and the refresh spinner clears.
  Future<void> _handleProfileRefreshRequest() async {
    await Future.wait(<Future<void>>[
      userProfile.runnersMeSetup(),
      refreshPeriodLeaveAvailability(notify: false),
    ]);
  }

  Future<void> refreshPeriodLeaveAvailability({bool notify = true}) async {
    await periodLeave.fetchAvailability();

    if (notify) {
      notifyListeners();
    }
  }

  /// Refresh emergency logout availability only.
  Future<void> refreshEmergencyLogoutAvailability({bool notify = true}) async {
    final emergencyRaw = await JobHttp.getEmergencyLogoutData();
    emergencyLogoutAvailability =
        emergencyRaw is Map<String, dynamic> ? emergencyRaw : null;
    emergencyLogoutDegradedFromBcp = emergencyLogoutAvailability == null
        ? BcpGate.instance.isBlocked(_emergencyLogoutAvailabilityPath)
        : false;

    emergencyLogoutAvailabilityReady = true;

    if (notify) {
      notifyListeners();
    }
  }

  /// Refresh both period leave and emergency logout availability.
  ///
  /// This is intentionally decoupled from [_fetchData] so periodic
  /// [current_state] polling does not over-fetch availability endpoints.
  Future<void> refreshLifecycleAvailability({bool notify = true}) async {
    await refreshPeriodLeaveAvailability(notify: false);
    await refreshEmergencyLogoutAvailability(notify: false);

    if (notify) {
      notifyListeners();
    }
  }

  /// Reads cached current_state from SharedPreferences (written by background
  /// FCM handler) and applies it if fresh enough. Cache is consumed after use.
  @visibleForTesting

  /// WS5 reverse bridge: the MQTT engine applied a snapshot (KMP → Dart via
  /// [RunnerStateChannel]'s `applyState`). Render it on the Flutter surface,
  /// reusing the same widget-build path as a cached/polled state so `widgetUtil`
  /// — and its bottomButton — is rebuilt in lockstep with `widgetInfo` (the
  /// ECPO-173 fix). Only the realtime cohort renders from MQTT; a non-cohort
  /// echo (Dart's own `pushState` round-tripping through the KMP store) is
  /// ignored. Does NOT re-publish to KMP — the engine is the writer here.
  void applyBridgeSnapshot(String json) {
    dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (e) {
      MonitoringServiceHelper.logError('realtime_bridge_apply_failed', {
        'error': e.runtimeType.toString(),
      });
      return;
    }
    final map = _runnerStateEnvelopeAsMap(decoded);
    // SHADOW: the poll owns PartnerHome until the cohort is committed.
    if (!_mqttCohortActive || map == null) return;

    // A null-widget snapshot (backend heartbeat/clear) carries no renderable
    // state — keep the current widget rather than blanking the screen. Also
    // guards WidgetInfo.name (non-nullable) from a null assignment.
    if (map['widget_name'] == null) return;

    // Mirror _fetchData's render processing so an MQTT-driven state renders the
    // same as a polled one. KEEP IN LOCKSTEP WITH _fetchData: gamification
    // balance, sheet warnings, attendance-override clear, pre-action nudges,
    // and the RUNNER_NEW_JOB bottom-button preservation. Not mirrored (side
    // effects, follow-up): auto-login API + Auto-OT orchestration.
    final oldWidgetName = widgetInfo?.name;
    final oldBottomButton = widgetUtil?.bottomButton;

    sheetWarnings = GamificationManager.instance.parseSheetWarnings(
      map['sheet_warnings'] ?? map['sheetWarnings'],
    );
    gamificationCoins = anyValueToInt(
          map['gold_coins_total'] ?? map['goldCoinsTotal'],
        ) ??
        gamificationCoins;
    gamificationRedCards = anyValueToInt(
          map['red_cards_total'] ?? map['redCardsTotal'],
        ) ??
        gamificationRedCards;
    showLunchSelection =
        (map['show_lunch_selection'] ?? map['showLunchSelection']) == true;

    widgetInfo = WidgetInfo.fromMap(map);
    tierNudge = _parseTierNudge(map);
    jobId = widgetInfo?.data?['job_id'];

    if (provisionalAttendanceOverride != null) {
      final name = widgetInfo?.name;
      if (name != 'PA_BEFORE_LOGOUT' && name != 'RUNNER_ATTENDANCE_TOMORROW') {
        provisionalAttendanceOverride = null;
      }
    }

    preActionNudges =
        GamificationManager.instance.parseNudges(widgetInfo?.data, map);
    ctaOverrideMap = GamificationManager.instance
        .resolveCtaOverridesFromNudges(preActionNudges);

    widgetUtil = getRunnerStateWidgetUtil(widgetInfo);
    if (widgetInfo?.name == 'RUNNER_NEW_JOB' &&
        widgetInfo?.name == oldWidgetName &&
        oldBottomButton != null) {
      widgetUtil?.bottomButton = oldBottomButton;
    }

    // Alarm on a NONE→breach transition delivered via the MQTT bridge snapshot.
    _evaluateAwolAlarm();

    waitForFetchData = false;
    notifyListeners();
  }

  Future<void> applyCachedStateIfFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTs = prefs.getInt('cached_current_state_ts') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = RemoteConfigService.instance.getInt(
        'expert_bg_cache_max_age_ms',
        defaultValue: 30000,
      );
      if (now - cachedTs < (maxAgeMs > 0 ? maxAgeMs : 30000)) {
        final cachedJson = prefs.getString('cached_current_state');
        if (cachedJson != null) {
          final data = jsonDecode(cachedJson);
          widgetInfo = WidgetInfo.fromMap(data);
          _lastRunnerStateEnvelope = _runnerStateEnvelopeAsMap(data);
          // Re-parse the top-level siblings (sheet_warnings, gamification totals,
          // pre_action_nudges) from the SAME cached envelope — otherwise a resume
          // via bg-cache paints the new widget but leaves sheetWarnings/nudges
          // stale until the follow-up _fetchData lands, so the Change-Attendance
          // sheet opens without its warning until pull-to-refresh.
          final envelopeMap = _lastRunnerStateEnvelope;
          sheetWarnings = GamificationManager.instance.parseSheetWarnings(
            envelopeMap?['sheet_warnings'] ?? envelopeMap?['sheetWarnings'],
          );
          gamificationCoins = anyValueToInt(
                envelopeMap?['gold_coins_total'] ??
                    envelopeMap?['goldCoinsTotal'],
              ) ??
              gamificationCoins;
          gamificationRedCards = anyValueToInt(
                envelopeMap?['red_cards_total'] ??
                    envelopeMap?['redCardsTotal'],
              ) ??
              gamificationRedCards;
          showLunchSelection =
              (envelopeMap?['show_lunch_selection'] ??
                  envelopeMap?['showLunchSelection']) ==
              true;
          preActionNudges = GamificationManager.instance
              .parseNudges(widgetInfo?.data, envelopeMap);
          ctaOverrideMap = GamificationManager.instance
              .resolveCtaOverridesFromNudges(preActionNudges);
          // Rebuild widgetUtil in lockstep with widgetInfo. Without this, a
          // cache-applied state change (e.g. RUNNER_LOGIN_HOTSPOT -> RUNNER_NEW_JOB
          // from an FCM job push) updates widgetInfo but leaves widgetUtil — and
          // its bottomButton — stale. _fetchData then captures oldWidgetName from
          // the (updated) widgetInfo but oldBottomButton from the (stale)
          // widgetUtil, so the RUNNER_NEW_JOB bottom-button preservation re-applies
          // the old "Login" button instead of letting NewJobAssigned install
          // "Accept". (ECPO-173 follow-up: runner saw Login on a new-job screen.)
          widgetUtil = getRunnerStateWidgetUtil(widgetInfo);
          jobId = widgetInfo?.data?['job_id'];
          tierNudge = _parseTierNudge(envelopeMap);
          waitForFetchData = false;
          _publishRunnerState();
          // Alarm on a NONE→breach transition carried by the bg-FCM state cache.
          _evaluateAwolAlarm();
          notifyListeners();
          prefs.remove('cached_current_state');
          prefs.remove('cached_current_state_ts');
          try {
            MonitoringServiceHelper.logInfo('expert_state_sync',
                {'step': 'bg_cache_applied', 'cache_age_ms': now - cachedTs});
          } catch (_) {}
        }
      } else {
        try {
          MonitoringServiceHelper.logInfo('expert_state_sync',
              {'step': 'bg_cache_skipped', 'cache_age_ms': now - cachedTs});
        } catch (_) {}
      }
    } catch (e, stackTrace) {
      // Parse failed — remove corrupted cache so it doesn't fail again
      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.remove('cached_current_state');
        prefs.remove('cached_current_state_ts');
      } catch (_) {}
      FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'Background FCM state cache read failed', fatal: false);
    }
  }

  Future<void> _fetchData() async {
    _isFetching = true;
    final fetchStartMs = DateTime.now().millisecondsSinceEpoch;
    try {
      try {
        MonitoringServiceHelper.logInfo('expert_state_sync',
            {'step': 'fetch_data_start', 'is_polling': _isPolling});
      } catch (_) {}
      await applyCachedStateIfFresh();

      final response = await RunnerHttp.runnerAppCurrentState();

      if (!_isPolling || (response != null && response.statusCode == 401)) {
        return;
      }

      waitForFetchData = false;
      final oldWidgetName = widgetInfo?.name;
      final oldBottomButton = widgetUtil?.bottomButton;
      if (response != null && response.statusCode == 200) {
        final data = response.data;

        final envelopeMap = _runnerStateEnvelopeAsMap(data);
        sheetWarnings = GamificationManager.instance.parseSheetWarnings(
          envelopeMap?['sheet_warnings'] ?? envelopeMap?['sheetWarnings'],
        );

        // Gamification balance from current state (authoritative source).
        gamificationCoins = anyValueToInt(
              envelopeMap?['gold_coins_total'] ??
                  envelopeMap?['goldCoinsTotal'],
            ) ??
            gamificationCoins;
        gamificationRedCards = anyValueToInt(
              envelopeMap?['red_cards_total'] ?? envelopeMap?['redCardsTotal'],
            ) ??
            gamificationRedCards;
        showLunchSelection =
            (envelopeMap?['show_lunch_selection'] ??
                envelopeMap?['showLunchSelection']) ==
            true;

        widgetInfo = data != null ? WidgetInfo.fromMap(data) : null;
        _lastRunnerStateEnvelope = envelopeMap;
        tierNudge = _parseTierNudge(envelopeMap);
        // debugPrint("*********${response}");
        jobId = widgetInfo?.data?['job_id'];

        // Clear the attendance override only when the server state has moved
        // past the attendance-pending states, confirming the mark was processed.
        if (provisionalAttendanceOverride != null) {
          final name = widgetInfo?.name;
          if (name != 'PA_BEFORE_LOGOUT' &&
              name != 'RUNNER_ATTENDANCE_TOMORROW') {
            provisionalAttendanceOverride = null;
          }
        }

        // Handle auto-login API call
        // Only call when:
        // 1. Widget is login-related (RUNNER_LOGIN_HOTSPOT)
        // 2. Auto-login is required but not yet acknowledged
        if (widgetInfo?.name == "RUNNER_LOGIN_HOTSPOT" &&
            widgetInfo?.data?['auto_login_acknowledged_at'] == null &&
            widgetInfo?.data?['auto_login_enabled'] == true) {
          await _callAutoLoginAPI();
        }

        // final data = {
        //   "widget_name": AppStrings.lunchWidgetName,
        //   "widget_data": {
        //     "start_time": "2025-02-10T23:36:00.568938+05:30",
        //     "duration": 1,
        //   }
        // };
        // final data = {
        //   "widget_name": AppStrings.lunchCoolDownWidgetName,
        //   "widget_data": {
        //     "cool_down_start": "2025-02-10T21:27:00.568938+05:30",
        //     "cool_down_duration": 1,
        //     "break_start": "2025-02-10T17:22:00.568938+05:30",
        //     "break_duration": 20,
        //   }
        // };
        // final data = {
        //   "widget_name": "RUNNER_JOB_POST_ACCEPT",
        //   "widget_data": {
        //     "start_time": "10:00 am",
        //     "end_time": "11:00 am",
        //     "lat": 19.091447499999997,
        //     "lng": 72.8956343,
        //     "mark_arrival_radius": 500,
        //     "address": "c2-204 Krishna avenue",
        //     "geo_address": "Krishna Avenue, Kalikund, Dholka, Gujarat, India",
        //     "customer_name": "Sagar",
        //     "customer_ph_no": "+916354574481",
        //     "payment": "Pending",
        //     "job_id": 739,
        //     "duration": 30,
        //     "lunch_state": "SCHEDULE",
        //   },
        //   "start_time": "10:00 am",
        //   "end_time": "10:30 am",
        //   "lat": 19.091447499999997,
        //   "lng": 72.8956343,
        //   "address": "c2-204 Krishna avenue",
        //   "job_id": 739,
        //   "geo_address": "Krishna Avenue, Kalikund, Dholka, Gujarat, India",
        //   "duration": 30,
        //   "customer_ph_no": "+916354574481",
        //   "customer_name": "Sagar",
        //   "payment": "Pending",
        //   "mark_arrival_radius": 500
        // };

        // _widgetInfo = {
        //   "widget_name": "LUNCH",
        //   "widget_data": {
        //     "start_time": "2024-12-02T20:30:00.568938+05:30",
        //     "duration": 30,
        //   }
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_POST_ACCEPT",
        //   "widget_data": {
        //     "start_time": "10:00 am",
        //     "end_time": "11:00 am",
        //     "lat": 19.091447499999997,
        //     "lng": 72.8956343,
        //     "mark_arrival_radius": 500,
        //     "address": "c2-204 Krishna avenue",
        //     "geo_address": "Krishna Avenue, Kalikund, Dholka, Gujarat, India",
        //     "customer_name": "Sagar",
        //     "customer_ph_no": "+916354574481",
        //     "payment": "Pending",
        //     "job_id": 739,
        //     "duration": 30
        //   },
        //   "start_time": "10:00 am",
        //   "end_time": "10:30 am",
        //   "lat": 19.091447499999997,
        //   "lng": 72.8956343,
        //   "address": "c2-204 Krishna avenue",
        //   "job_id": 739,
        //   "geo_address": "Krishna Avenue, Kalikund, Dholka, Gujarat, India",
        //   "duration": 30,
        //   "customer_ph_no": "+916354574481",
        //   "customer_name": "Sagar",
        //   "payment": "Pending",
        //   "mark_arrival_radius": 500
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_IN_PROGRESS",
        //   "widget_data": {
        //     "end_time": "2024-09-17T23:29:46.568938+05:30",
        //     "payment": "Paid",
        //     "payment_method": "COD",
        //     "cash_to_be_collected": false,
        //     "cash_amount": 118,
        //     "job_id": 461,
        //     "duration": 30,
        //     "lat": 19.1154632,
        //     "lng": 72.91804929999999,
        //     "address": "111A B wing",
        //     "geo_address":
        //         "Kailash Complex, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //     "customer_name": "Hello",
        //     "customer_ph_no": "+917259573760",
        //     "show_checkout_otp": true
        //   },
        //   "end_time": "2024-09-17T23:29:46Z",
        //   "payment": "Paid",
        //   "payment_method": "COD",
        //   "cash_to_be_collected": true,
        //   "cash_amount": 118,
        //   "job_id": 461,
        //   "lat": 19.1154632,
        //   "lng": 72.91804929999999,
        //   "address": "111A B wing",
        //   "geo_address":
        //       "Kailash Complex, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //   "duration": 30,
        //   "customer_ph_no": "+917259573760",
        //   "customer_name": "Hello",
        //   "show_checkout_otp": false
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_IN_PROGRESS",
        //   "widget_data": {
        //     "end_time": "2024-07-23T19:37:00+05:30",
        //     "payment": "Paid",
        //     "cash_to_be_collected": true,
        //     "cash_amount": 189,
        //     "job_id": 7,
        //     "duration": 90,
        //     "lat": 19.106601205399027,
        //     "lng": 72.89626980780312,
        //     "address": "regent hill string",
        //     "geo_address": "r city",
        //     "customer_name": "hello world",
        //     "customer_ph_no": "+9191874672"
        //   },
        //   "end_time": "2024-06-26T17:35:00Z",
        //   "payment": "Paid",
        //   "payment_method": "COD",
        //   "cash_to_be_collected": true,
        //   "cash_amount": 189,
        //   "job_id": 7,
        //   "lat": 19.106601205399027,
        //   "lng": 72.89626980780312,
        //   "address": "regent hill string",
        //   "geo_address": "r city",
        //   "duration": 60,
        //   "customer_ph_no": "+9191874672",
        //   "customer_name": "hello world"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_SEE_YOU_TOMORROW",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_LOGOUT",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_LOGIN_HOTSPOT",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "lat":1.0,
        //     "lng":0.7,
        //     "address":"address",
        //     "geo_address":"geo address",
        //     "enable_login":true,
        //     "start_time":"01:00 pm",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_TOMORROW",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_ABSENT",
        //   "widget_data": {
        //     "date": "Monday 24th June",
        //     "type": "TOMORROW",
        //     // "type": "TODAY",
        //     "shift_time": "10:46 am - 06:46 pm",
        //   },
        //   "date": "Monday 24th June",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_CONFIRMED",
        //   "widget_data": {
        //     "date": "Monday 24th June",
        //     "type": "TOMORROW",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "change_atn": true,
        //   },
        //   "date": "Monday 24th June",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_CHECK_IN",
        //   "widget_data": {
        //     "start_time": "07:30 pm",
        //     "end_time": "11:30 pm",
        //     "customer_ph_no": "9382883992",
        //     "duration": "60 Minutes",
        //     "Payment": "Pending",
        //     "customer_name": "Anagha S",
        //     "lat": 0.5,
        //     "lng": 0.5,
        //     "address": "Regent Hill",
        //     "geo_address": "Purva Fountain Sq"
        //   },
        //   "start_time": "10:00 am",
        //   "end_time": "11:00 am",
        //   "customer_ph_no": "9382883992",
        //   "duration": "60 Minutes",
        //   "Payment": "Pending",
        //   "lat": 0.5,
        //   "lng": 0.5,
        //   "address": "Regent Hill",
        //   "geo_address": "Purva Fountain Sq"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_POST_ACCEPT",
        //   "widget_data": {
        //     "start_time": "04:02 am",
        //     "end_time": "6:00 am",
        //     "customer_ph_no": "9382883992",
        //     "duration": "120 Minutes",
        //     "Payment": "Pending",
        //     "customer_name": "Anagha S",
        //     "lat": 0.5,
        //     "lng": 0.5,
        //     "address": "Regent Hill",
        //     "mark_arrival_radius": 8148831,
        //     "enable_arrival": true,
        //     "geo_address": "Purva Fountain Sq",
        //     "job_id": 2012,
        //   },
        //   "start_time": "10:00 am",
        //   "end_time": "11:00 am",
        //   "customer_ph_no": "9382883992",
        //   "duration": "60 Minutes",
        //   "Payment": "Pending",
        //   "lat": 0.5,
        //   "lng": 0.5,
        //   "address": "Regent Hill",
        //   "geo_address": "Purva Fountain Sq"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_NEW_JOB",
        //   "widget_data": {
        //     "start_time": "10:00 am",
        //     "lat": 0.5,
        //     "lng": 0.5,
        //     "address": "Regent Hill",
        //     "geo_address": "Purva Fountain Sq"
        //   },
        //   "start_time": "10:00 am",
        //   "lat": 0.5,
        //   "lng": 0.5,
        //   "address": "102, tower 2, Regent Hill",
        //   "geo_address": "Purva Fountain Sq"
        // };

        // _widgetInfo = {
        //   "widget_name": "ERROR_WIDGET",
        //   "widget_data": {
        //     "message": (response.data ?? "Something went wrong").toString(),
        //   }
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_TODAY",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TODAY"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TODAY"
        // };
        // LATEST_RUNNER_JOB_IN_PROGRESS
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_IN_PROGRESS",
        //   "widget_data": {
        //     "end_time": "2024-11-29T10:50:58.329788+05:30",
        //     "payment": "Paid",
        //     "payment_method": "COD",
        //     "cash_to_be_collected": true,
        //     "cash_amount": 18,
        //     "job_id": 650,
        //     "booking_id": 585,
        //     "customer_id": 2199,
        //     "duration": 15,
        //     "lat": 22.7460558,
        //     "lng": 72.4465261,
        //     "address": "78 89",
        //     "geo_address": "Kalikund, Dholka, Gujarat, India",
        //     "customer_name": "reg",
        //     "customer_ph_no": "+918007977201",
        //     "show_checkout_otp": true,
        //     "checkout_before_mins": 15
        //   },
        //   "end_time": "2024-11-29T10:50:58Z",
        //   "payment": "Paid",
        //   "payment_method": "COD",
        //   "cash_to_be_collected": true,
        //   "cash_amount": 18,
        //   "job_id": 650,
        //   "booking_id": 585,
        //   "customer_id": 2199,
        //   "lat": 22.7460558,
        //   "lng": 72.4465261,
        //   "address": "78 89",
        //   "geo_address": "Kalikund, Dholka, Gujarat, India",
        //   "duration": 15,
        //   "customer_ph_no": "+918007977201",
        //   "customer_name": "reg",
        //   "show_checkout_otp": true,
        //   "checkout_before_mins": 15
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_IN_PROGRESS",
        //   "widget_data": {
        //     "end_time": "2024-11-28T06:02:29.107097+05:30",
        //     "payment": "Paid",
        //     "payment_method": "COD",
        //     "cash_to_be_collected": true,
        //     "cash_amount": 118,
        //     "job_id": 630,
        //     "duration": 30,
        //     "lat": 19.113904299999998,
        //     "lng": 72.9181878,
        //     "address": "dd dd",
        //     "geo_address":
        //         "KAILASH BUSINESS PARK, Park Site Road, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //     "customer_name": "vinit",
        //     "customer_ph_no": "+917259573760",
        //     "customer_id": 11,
        //     "booking_id": "323",
        //     "show_checkout_otp": true,
        //     "checkout_before_mins": 15
        //   },
        //   "end_time": "2024-11-26T22:15:29Z",
        //   "payment": "Paid",
        //   "payment_method": "COD",
        //   "cash_to_be_collected": true,
        //   "cash_amount": 118,
        //   "job_id": 630,
        //   "lat": 19.113904299999998,
        //   "lng": 72.9181878,
        //   "address": "dd dd",
        //   "geo_address":
        //       "KAILASH BUSINESS PARK, Park Site Road, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //   "duration": 30,
        //   "customer_ph_no": "+917259573760",
        //   "customer_name": "vinit",
        //   "show_checkout_otp": true,
        //   "checkout_before_mins": 15
        // };
      } else {
        sheetWarnings = [];
        tierNudge = null;
        widgetInfo = WidgetInfo(name: "ERROR_WIDGET", data: {
          "message": (response?.data ?? "Something went wrong").toString(),
        });
        // _widgetInfo = {
        //   "widget_name": "LUNCH",
        //   "widget_data": {
        //     "start_time": "01:00 pm",
        //     "duration": 30,
        //   }
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_NEW_JOB",
        //   "widget_data": {
        //     "start_time": "10:00 am",
        //     "lat": 0.5,
        //     "lng": 0.5,
        //     "address": "Regent Hill",
        //     "geo_address": "Purva Fountain Sq"
        //   },
        //   "start_time": "10:00 am",
        //   "lat": 0.5,
        //   "lng": 0.5,
        //   "address": "102, tower 2, Regent Hill",
        //   "geo_address": "Purva Fountain Sq"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_TOMORROW",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_ABSENT",
        //   "widget_data": {
        //     "date": "Monday 24th June",
        //     "type": "TOMORROW",
        //     "change_atn": true,
        //     // "type": "TODAY",
        //     "shift_time": "10:46 am - 06:46 pm",
        //   },
        //   "date": "Monday 24th June",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_CONFIRMED",
        //   "widget_data": {
        //     "date": "Monday 24th June",
        //     "type": "TOMORROW",
        //     "change_atn": true,
        //     "shift_time": "10:46 am - 06:46 pm",
        //   },
        //   "date": "Monday 24th June",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_LOGOUT",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TOMORROW"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TOMORROW"
        // };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_ATTENDANCE_TODAY",
        //   "widget_data": {
        //     "date": "Sunday 23rd June",
        //     "shift_time": "10:46 am - 06:46 pm",
        //     "type": "TODAY"
        //   },
        //   "date": "Sunday 23rd June",
        //   "shift_time": "10:46 am - 06:46 pm",
        //   "type": "TODAY"
        // };
        //  _widgetInfo = {
        //     "widget_name": "RUNNER_JOB_IN_PROGRESS",
        //     "widget_data": {
        //       "end_time": "2024-09-17T23:29:46.568938+05:30",
        //       "payment": "Paid",
        //       "payment_method": "COD",
        //       "cash_to_be_collected": true,
        //       "cash_amount": 118,
        //       "job_id": 461,
        //       "duration": 30,
        //       "lat": 19.1154632,
        //       "lng": 72.91804929999999,
        //       "address": "111A B wing",
        //       "geo_address":
        //           "Kailash Complex, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //       "customer_name": "Hello",
        //       "customer_ph_no": "+917259573760",
        //       "customer_id":11,
        //       "show_checkout_otp": true
        //     },
        //     "end_time": "2024-09-17T23:29:46Z",
        //     "payment": "Paid",
        //     "payment_method": "COD",
        //     "cash_to_be_collected": true,
        //     "cash_amount": 118,
        //     "job_id": 461,
        //     "lat": 19.1154632,
        //     "lng": 72.91804929999999,
        //     "address": "111A B wing",
        //     "geo_address":
        //         "Kailash Complex, HMPL Surya Nagar, Vikhroli West, Mumbai, Maharashtra, India",
        //     "duration": 30,
        //     "customer_ph_no": "+917259573760",
        //     "customer_name": "Hello",
        //     "show_checkout_otp": false
        //   };
        // _widgetInfo = {
        //   "widget_name": "RUNNER_JOB_POST_ACCEPT",
        //   "widget_data": {
        //     "start_time": "10:00 am",
        //     "end_time": "11:00 am",
        //     "customer_ph_no": "9382883992",
        //     "duration": "60 Minutes",
        //     "Payment": "Pending",
        //     "lat": 0.5,
        //     "lng": 0.5,
        //     "address": "Regent Hill",
        //     "geo_address":
        //         "Purva Fountain Sq, this is a big complicated address for testing, 204 C-2, Abracadabra society Krishna Avenue, Kalikund, Dholka Bypass Road, Kalikund circle, Ahmedabad, 382225"
        //   },
        //   "start_time": "10:00 am",
        //   "end_time": "11:00 am",
        //   "customer_ph_no": "9382883992",
        //   "duration": "60 Minutes",
        //   "Payment": "Pending",
        //   "lat": 0.5,
        //   "lng": 0.5,
        //   "address": "Regent Hill",
        //   "geo_address": "Purva Fountain Sq"
        // };
      }

      preActionNudges = GamificationManager.instance.parseNudges(
        widgetInfo?.data,
        _runnerStateEnvelopeAsMap(response?.data),
      );
      ctaOverrideMap = GamificationManager.instance
          .resolveCtaOverridesFromNudges(preActionNudges);

      widgetUtil = getRunnerStateWidgetUtil(widgetInfo);
      if (widgetInfo?.name == 'RUNNER_NEW_JOB' &&
          widgetInfo?.name == oldWidgetName &&
          oldBottomButton != null) {
        widgetUtil?.bottomButton = oldBottomButton;
      }

      // Coordinate global Auto-OT behavior after widgetInfo/widgetUtil updates.
      if (enableAutoOt) {
        try {
          await AutoOtOrchestrator.onRunnerStateUpdated();
        } catch (_) {
          // Orchestration must never break polling.
        }
      }
    } finally {
      waitForFetchData = false;
      _isFetching = false;
      try {
        MonitoringServiceHelper.logInfo('expert_state_sync', {
          'step': 'fetch_data_complete',
          'widget_name': widgetInfo?.name,
          'duration_ms': DateTime.now().millisecondsSinceEpoch - fetchStartMs
        });
      } catch (_) {}
      _publishRunnerState();
      // Alarm on a NONE→breach transition in the freshly-polled state (the v2
      // AWOL wake push is nameless, so loopSound never plays it).
      _evaluateAwolAlarm();
      // Re-mirror the RC-driven overlay + Ameyo flags every poll. The constructor push runs
      // before the post-login Remote Config fetchAndActivate, so a value that flips after
      // startup (or activates late) would otherwise leave the KMP RunnerSessionStore stale —
      // the disposition submit reads it live, so a frozen mirror routes support the wrong way.
      // Idempotent (thin bool channel writes), so re-pushing an unchanged value is a no-op.
      notifyListeners();
    }
  }

  bool todayShiftPerformanceLoading = false;
  TodayShiftPerformance? todayShiftPerformance;

  Future<void> getTodayShiftPerformance() async {
    if (todayShiftPerformanceLoading) return;

    todayShiftPerformanceLoading = true;

    notifyListeners();

    try {
      final response = await RunnerHttp.todayShiftPerformance();

      if (response != null && response.statusCode == 200) {
        final todayShiftData = TodayShiftPerformance.fromMap(response.data);

        todayShiftPerformance = todayShiftData;
      }
    } catch (e, stackTrace) {
      print("getTodayShiftPerformance     error: " + e.toString());
      print("getTodayShiftPerformance    stackTrace: " + stackTrace.toString());
      throw Exception(e);
    }

    todayShiftPerformanceLoading = false;
    notifyListeners();
  }

  // Check if the shift performance bottom sheet was already shown today
  bool shouldShowShiftPerformanceBottomSheet() {
    final prefs = GlobalState().prefs;
    if (prefs == null) return true;

    final lastShownDate = prefs.getString('shift_performance_last_shown_date');
    final todayDate =
        DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format

    return lastShownDate != todayDate;
  }

  // Mark the shift performance bottom sheet as shown today
  Future<void> markShiftPerformanceBottomSheetAsShown() async {
    final prefs = GlobalState().prefs;
    if (prefs == null) return;

    final todayDate =
        DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
    await prefs.setString('shift_performance_last_shown_date', todayDate);

    notifyListeners();
  }

  Future<void> _callAutoLoginAPI() async {
    try {
      final response = await RunnerHttp.acknowledgeAutoLogin();
      if (response != null && response.statusCode == 200) {
        await PostActionOverlayController.instance
            .showFromResponse(response.data, LifecycleActionType.earlyLogin);
      }
    } catch (e) {
      // Handle any errors silently
    }
  }

  bool get enableAutoOt {
    return RemoteConfigService.instance.getBool(
      RemoteConfigKeys.enableAutoOt,
      defaultValue: false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
