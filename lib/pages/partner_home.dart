// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:format/format.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:snabbit_runner/home/providers/info_banner_provider.dart';
import 'package:snabbit_runner/home/widgets/info_banner.dart';
import 'package:snabbit_runner/services/security/root_detection_service.dart';
import 'package:snabbit_runner/widgets/generic_banner_widget.dart';
import 'package:snabbit_runner/models/banner_config.dart';
import 'package:snabbit_runner/payout/bonus/widgets/home_festive_banner.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/referrals/widgets/referral_earn_banner.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/modules/snabbit_shield/safety_shield_adapter.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_permission_handler.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_provider.dart';
import 'package:snabbit_runner/modules/snabbit_shield/ui/snabbit_shield_card.dart';
import 'package:snabbit_runner/services/alarm_silencer.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/tracking/awol_tracking.dart';
import 'package:snabbit_runner/services/installed_apps_service.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/widgets/tiering/applicable_tiering_nudge.dart';
import 'package:snabbit_runner/widgets/tiering/snabbit_udaan_banner.dart';
import 'package:snabbit_runner/widgets/tiering/tier_badge_v2.dart';
import 'package:snabbit_runner/widgets/update_required_popup.dart';
import 'package:snabbit_runner/services/payout_http.dart';

import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/common_widget_carousal.dart'
    show CommonWidgetCarousel;
import 'package:snabbit_runner/widgets/drawer/drawer_menu.dart';
import 'package:snabbit_runner/widgets/job_start_flow/auto_mark_arrival.dart';
import 'package:snabbit_runner/widgets/missing_details_card.dart';
import 'package:snabbit_runner/widgets/partner_home/home_rewards_header_pill.dart';
import 'package:snabbit_runner/widgets/partner_home/lunch_slots_banner.dart';
import 'package:snabbit_runner/widgets/rainbow_anim_bg.dart';
import 'package:snabbit_runner/widgets/sos.dart';
import 'package:lottie/lottie.dart';
import 'package:snabbit_runner/widgets/delayed_checkin/job_support_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/elevated_button_with_loader.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';
import 'package:snabbit_runner/widgets/today_shift_performance_widget.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';
import '../providers/partner_home_init_provider.dart';
import '../providers/user_profile.dart';
import '../utils/app_strings.dart';
import '../utils/registration_navigation.dart';
import '../widgets/lunch_break.dart';
import 'package:dio/dio.dart';

import '../providers/pip_provider.dart';
import '../services/pip_service.dart';
import '../providers/overlay_provider.dart';
import '../services/overlay_service.dart';
import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/models/awol/awol_overlay_converter.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/widgets/awol/awol_breach_widget.dart';
import 'package:snabbit_runner/widgets/overlay_permission_dialog.dart';
import 'package:snabbit_runner/widgets/awol/awol_re_entered_widget.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/maps_navigation_service.dart';

class PartnerHome extends StatefulWidget {
  static const String routeName = "/partner-home";

  const PartnerHome({super.key});

  @override
  State<PartnerHome> createState() => _PartnerHomeState();
}

class _PartnerHomeState extends State<PartnerHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _foregroundChannel =
      MethodChannel('com.snabbit.runner/foreground');
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late UserProfile userProfile;
  late LanguageProvider languageProvider;

  /// Signature of the last label map pushed over [JobOverlayChannel.setJobStrings]
  /// — dedupes the didChangeDependencies re-runs to actual language changes.
  String? _lastPushedJobLabelsSignature;
  late RunnerRtDataProvider runnerRtDataProvider;
  bool isLunchBottomSheetVisible = false;
  bool isAppForeground = true;
  bool wasPreviouslyInPipMode = false;
  Size _lastPhysicalSize = Size.zero;
  // Debug: toggle between breach (dialog) and re-entered (banner) overlay
  // bool _debugShowReEntered = false;
  late PipProvider pipProvider;
  late OverlayProvider overlayProvider;
  late InfoBannerProvider infoBannerProvider;
  Trace? _screenTrace;
  //
  // to prevent showing online status on init if user has a connection,
  bool showInitOnlineConnectionStatus = false;
  SharedPreferences? prefs;

  SafetyShieldAdapter? _shield;
  SOSProvider? _sosProvider;
  StreamSubscription<Set<String>>? _remoteConfigSubscription;

  /// Debounce timer for [_onAwolDataChanged]. Prevents duplicate overlay
  /// creation when rapid-fire notifyListeners() calls arrive from polling.
  Timer? _awolDebounce;

  /// True only on the very first AWOL data callback after a cold/killed-state
  /// launch. When the app is opened fresh, [isAppForeground] is true but there
  /// may already be a JOB AWOL in the first payload — we want to treat that
  /// the same as a background arrival and show the native overlay instead of
  /// skipping it.
  bool _isFirstAwolCheck = true;

  bool get _isAwolOverlayEnabled => overlayProvider.isAwolOverlayEnabled;
  bool get _isAwolV2Enabled => overlayProvider.isAwolV2Enabled;
  bool get _isAwolV2OverlayEnabled => overlayProvider.isAwolV2OverlayEnabled;

  /// The mqtt_config (KMP) cohort — routed to the native KMP home, which owns the
  /// home UI + AWOL + Shield/Kavach (all self-fed from current_state, see
  /// `features/kavach`). This Flutter PartnerHome is only an interim host for the
  /// cohort: it renders a loader and starts the background work KMP does NOT own
  /// (IoT foreground service + deeplink drain) until the native Activity covers
  /// it. Its home UI + Shield/AWOL/UI-only init are skipped for cohort runners.
  bool get _isMqttCohort =>
      Provider.of<UserProfileProvider>(context, listen: false)
          .user
          ?.mqttConfig !=
      null;

  /// Returns true if awolData is a JOB state AND the v2 flag is enabled.
  bool _isJobAwol(AwolData? awolData) =>
      awolData != null && awolData.isJob && _isAwolV2Enabled;

  int? _jobStartEpochMillisForOverlay() {
    final raw =
        runnerRtDataProvider.widgetInfo?.data?['start_time']?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final parsed =
          DateFormat('h:mm a', 'en_US').parse(raw.trim().toUpperCase());
      var totalMinutes = parsed.hour * 60 +
          parsed.minute -
          DateTime.now().timeZoneOffset.inMinutes;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      final utcHour = totalMinutes ~/ 60;
      final utcMinute = totalMinutes % 60;
      final nowUtc = DateTime.now().toUtc();
      final target = DateTime.utc(
          nowUtc.year, nowUtc.month, nowUtc.day, utcHour, utcMinute);
      return target.millisecondsSinceEpoch;
    } catch (e) {
      try {
        MonitoringServiceHelper.logError(
          'JOB_START_EPOCH_PARSE_FAILED',
          {'raw': raw, 'error': e.toString()},
        );
      } catch (_) {}
      return null;
    }
  }

  /// Controls whether the overlay permission dialog blocks the app until
  /// the user grants "Display over other apps". When `true` (default), the
  /// dialog is mandatory. When `false`, the user can dismiss with "Not now"
  /// and the feature degrades gracefully (foreground-only, no background overlay).
  bool get _isAwolOverlayPermissionMandatory =>
      RemoteConfigService.instance.getBool(
        RemoteConfigKeys.awolOverlayPermissionMandatory,
        defaultValue: true,
      );

  Future<void> ignoreBatteryOptimization() async {
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }

  Future<void> initProcess() async {
    RootDetectionService.performRootCheck();
    // Check for installed apps
    InstalledAppService.checkAndLog();
  }

  /// Cohort-only interim init (see [_isMqttCohort]): start the background work the
  /// native KMP home does NOT own — the IoT foreground service (ConfigSync → FGS),
  /// the deeplink drain, and the localized job-label push. Shield + AWOL are
  /// KMP-owned (Kavach, self-fed from current_state) so they are deliberately NOT
  /// started here; the battery-optimisation exemption is already requested in
  /// [initState] (which runs for the cohort too).
  ///
  /// The FGS start is kicked off while this host is foregrounded; the KMP switch
  /// awaits [PartnerHomeInitProvider.servicesReady] before opening the native
  /// Activity, so `startService()` can't race the engine being backgrounded (the
  /// reason IoT often never started for the cohort). The screen renders a loader
  /// (see [build]) throughout.
  void _initCohortInterim() {
    // Phase 1: disable native PiP for the MQTT/KMP cohort. Entering PiP on the
    // Flutter MainActivity while the KMP host is alive fractures the task into two
    // surfaces (a stray PiP window beside the KMP host), so keep it off for this
    // cohort. Re-asserts `false` even if a prior Flutter session left it on in the
    // same process (re-login). Phase 2 unifies PiP across both hosts.
    unawaited(PipService.setPipEnabled(false));

    // Push job-surface labels now — the every-pass push below the init block is
    // skipped on this first pass by the cohort return above.
    _pushJobScreenLabels();
    initProcess().then((_) async {
      if (!mounted) return;
      final initProvider =
          Provider.of<PartnerHomeInitProvider>(context, listen: false);
      // IoT ConfigSync → foreground-service start (mic requested by the FGS itself).
      await initProvider.initializeServices(context);
    });
    // Cohort shell watchdog. navigateAfterRunnersMe opens the KMP shell on the
    // ACTIVE-login path, but PartnerHome is also reached WITHOUT that open (deeplink
    // _goHome, job-login selfie, go-live, SUSPENDED-resume), and the open itself can
    // abort — in every such case the cohort renders THIS loader indefinitely (build()
    // gates only on _isMqttCohort, with no Flutter home to fall back to). Make sure
    // the shell actually comes up; retry if it doesn't; surface a retry action if it
    // truly can't. See [_ensureCohortShellOpen].
    unawaited(_ensureCohortShellOpen());
    // NOTE: the deeplink drain is intentionally NOT here for the cohort. The native
    // shell launches asynchronously AFTER this frame (openKMPStackForMqttCohort), so
    // draining now would push the linked screen onto the Flutter surface the shell is
    // about to cover. The cohort drain runs once the shell state is settled — see
    // RegistrationNavigation.openKMPStackForMqttCohort. (Non-cohort drains below.)
  }

  // --- Cohort shell recovery (event-driven) ------------------------------------
  // The MQTT/KMP cohort's Flutter PartnerHome is only an interim loader; the native
  // KMP shell (NavigationHostActivity) is meant to cover it. Its single opener
  // (navigateAfterRunnersMe) doesn't fire on every PartnerHome entry, and the open
  // can abort, leaving a permanent loader (this cohort has no Flutter home to fall
  // back to). This ensures the shell comes up — waiting on the host's real resume
  // event rather than guessing a grace window — or the runner gets a retry action.

  /// How long to wait, per attempt, for the shell to reach the foreground (on the
  /// host's resume event) before re-checking / reopening / surfacing the retry UI.
  static const Duration _shellOpenTimeout = Duration(seconds: 10);

  /// Hard cap on wait cycles (× [_shellOpenTimeout]) — bounds total wall time to
  /// ~30s so a slow or absent launch can never loop indefinitely.
  static const int _maxShellWaits = 3;

  /// True once the shell couldn't be brought up — [build] then shows a retry
  /// action instead of an indefinite loader.
  bool _cohortShellFailed = false;

  /// Guards against overlapping recovery runs (e.g. a retry tap mid-run).
  bool _cohortShellChecking = false;

  /// Ensures the KMP shell actually covers the cohort interim. Waits for the host's
  /// resume event (the truthful "shell is up" signal) with a bounded timeout;
  /// reopens ONCE if the shell is genuinely down and nothing is bringing it up —
  /// but NEVER a *fresh* confirm (a launch that appeared this run is coming up on
  /// its own; reopening it only duplicates the native back stack). On terminal
  /// failure flips [_cohortShellFailed] so the runner can self-recover via retry.
  Future<void> _ensureCohortShellOpen() async {
    // Kill-switch. RC bools read false when absent, so this is a *disable* flag:
    // recovery is ON by default and ops can turn it off from Remote Config
    // without a build (and it stays on if RC is unavailable).
    if (RemoteConfigService.instance.getBool(
        RemoteConfigKeys.kmpCohortShellWatchdogDisabled,
        defaultValue: false)) {
      return;
    }
    if (_cohortShellChecking) return;
    _cohortShellChecking = true;
    try {
      final bridge = KmpNavigationBridge.instance;
      final poller = Provider.of<RunnerRtDataProvider>(context, listen: false);
      final user =
          Provider.of<UserProfileProvider>(context, listen: false).user;
      final initProvider =
          Provider.of<PartnerHomeInitProvider>(context, listen: false);
      // A confirm ALREADY present at entry (with the shell not up) is stale — the
      // KMP flag isn't reset on shell teardown — so it warrants a reopen. A confirm
      // that appears DURING this run (e.g. navigateAfterRunnersMe's) is a launch
      // coming up on its own and must NEVER be reopened.
      final hadConfirmAtStart = poller.isMqttCohort;
      var reorderTried = false;
      for (var wait = 0; wait < _maxShellWaits; wait++) {
        if (!mounted) return;
        final up = await bridge.isRootShellForegroundOrNull();
        if (!mounted) return;
        if (up == true) return; // shell is up → done
        // Bridge error (null) ⇒ can't determine shell state; don't thrash a reopen
        // on a broken channel — hand off to the retry action instead.
        if (up == null) break;
        // Only recover when PartnerHome is the VISIBLE surface. If a Flutter route is
        // deliberately on top (a keep-host excursion, or a native→Flutter handoff), a
        // resume must NOT yank the shell forward over it — bail, and let a later resume
        // with the loader actually showing do the recovery instead.
        if (ModalRoute.of(context)?.isCurrent != true) return;
        // Bring the shell forward when nobody else is (stranding entry, a reset, or a
        // resume that re-surfaced this loader). Never double-open: skip while an attempt
        // is in flight, and never disturb a FRESH confirm (one that appeared this run —
        // a launch coming up on its own).
        if (!poller.isMqttCohortAttemptInFlight) {
          if (!poller.isMqttCohort) {
            // No live confirm → the engine may be down → full bring-up.
            await RegistrationNavigation.openKMPStackForMqttCohort(
                user, poller, initProvider);
            if (!mounted) return;
          } else if (hadConfirmAtStart) {
            // Stale confirm: the shell was confirmed but isn't the foreground surface
            // now — its host was backgrounded (Flutter pulled in front of it) or
            // OS-reclaimed. Recover in two steps across iterations:
            MonitoringServiceHelper.logWarning('kmp_cohort_shell_reopen', {});
            if (!reorderTried) {
              // 1) Reorder the live host, or recreate it from the surviving process-
              //    scoped back stack — immediate and guard-safe (covers the common
              //    backgrounded / OS-reclaimed cases). NOT openNativeDestination here:
              //    while the stack is non-empty that trips the single-session guard.
              reorderTried = true;
              await bridge.returnToNativeHost();
            } else {
              // 2) Reorder couldn't bring it up ⇒ the back stack was terminally cleared
              //    (a prior terminal teardown). REBUILD the shell — openByKey on an
              //    EMPTY stack doesn't trip the guard, so this recovers where
              //    returnToNativeHost can't, keeping the Retry action functional.
              await bridge.openNativeDestination('bottom_nav_shell');
            }
            if (!mounted) return;
          }
          // else: a fresh confirm is coming up on its own → just wait for it below.
        }
        // Wait for the host's real resume event (or a bounded timeout) — no guess.
        if (await bridge.waitForRootShellForeground(_shellOpenTimeout)) return;
        if (!mounted) return;
        // Timed out. If an open is STILL standing up (e.g. a slow servicesReady on
        // navigateAfterRunnersMe's open), keep waiting — never abort a live open.
        if (poller.isMqttCohortAttemptInFlight) continue;
        // Not in flight and still down. A fresh confirm that never foregrounded is a
        // launch we must not disturb — give up to the retry UI. Otherwise clear an
        // aborted attempt so the next iteration re-runs the full bring-up.
        if (poller.isMqttCohort && !hadConfirmAtStart) break;
        if (!poller.isMqttCohort) poller.abortMqttCohort();
      }
      if (!mounted) return;
      if ((await bridge.isRootShellForegroundOrNull()) == true) return;
      MonitoringServiceHelper.logError('kmp_cohort_shell_stuck', {});
      if (mounted) setState(() => _cohortShellFailed = true);
    } catch (e, st) {
      // Runs fire-and-forget via unawaited(...), so an escaping throw would surface
      // as an unhandled zone error — a false-fatal, per this app's history. Log it
      // and fall back to the retry UI so the runner can still self-recover.
      MonitoringServiceHelper.reportError(
        'kmp_cohort_shell_ensure_failed',
        {'error': e.toString()},
        st.toString(),
      );
      if (mounted) setState(() => _cohortShellFailed = true);
    } finally {
      _cohortShellChecking = false;
    }
  }

  /// Retry UI shown when the cohort shell couldn't be brought up. Lets the runner
  /// re-trigger the open themselves rather than being stuck on a dead loader.
  Widget _cohortShellRetry() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.cohortShellRetryTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.n90,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            AppStrings.cohortShellRetryBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: AppColors.n60),
          ),
          SizedBox(height: 24.h),
          ElevatedButtonWithLoader(
            text: AppStrings.cohortShellRetryCta,
            bgColor: AppColors.brand,
            textColor: AppColors.n0,
            onPressed: () async {
              if (mounted) setState(() => _cohortShellFailed = false);
              MonitoringServiceHelper.logWarning(
                  'kmp_cohort_shell_retry_tapped', {});
              await _ensureCohortShellOpen();
            },
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: Brightness.light,
    ));

    if (init) {
      init = false;

      // Start screen trace
      try {
        _screenTrace =
            FirebasePerformance.instance.newTrace('screen_partner_home');
        _screenTrace?.start();
      } catch (_) {}

      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;

      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);

      // Read early — the setJobStrings label push (runs on every pass, below the
      // init block) needs it, and the cohort branch returns before its original read.
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

      // MQTT cohort: the native KMP home owns the UI + AWOL + Shield/Kavach (self-fed
      // from current_state). This host only starts the background work KMP doesn't own
      // (IoT FGS + deeplink), renders a loader (build()), and skips the home UI + the
      // Shield/AWOL/polling/PiP init — killing the flash and the FGS start-race.
      if (_isMqttCohort) {
        _initCohortInterim();
        return;
      }

      runnerRtDataProvider.waitForFetchData = true;
      pipProvider = Provider.of<PipProvider>(context, listen: false);
      // Phase 1: the Flutter cohort keeps PiP. Enable it explicitly (native default
      // is fail-closed off) — this also resets a stale `false` from a prior MQTT/KMP
      // session in the same process (re-login).
      unawaited(PipService.setPipEnabled(true));
      overlayProvider = Provider.of<OverlayProvider>(context, listen: false);
      // v2 needs SYSTEM_ALERT_WINDOW too, and the permission UX lives here —
      // the native launcher only degrades when it's missing (TR-06).
      if (_isAwolOverlayEnabled || _isAwolV2OverlayEnabled) {
        _initializeOverlayPermission();
        _requestMicAndLocationPermissions();
      }
      _listenForAwolOverlayToggle();
      overlayProvider.onShowDirections = (lat, lng, name) {
        Logger().i('AWOL: Show Directions — $name ($lat, $lng)');
        MapsNavigationService.launchNavigation(lat, lng);
      };
      overlayProvider.onCtaTracking = (actionId) {
        final awolData = runnerRtDataProvider.awolData;
        if (awolData == null) return;
        AwolTracking.trackCtaClicked(
          ctaType: actionId == 'understood' ? 'i_understood' : actionId,
          source: 'overlay',
          timerState:
              _isTimedOutForAwol(awolData) ? 'beyond_timer' : 'within_timer',
          awolData: awolData,
          timerCountAtAction: actionId == 'understood'
              ? awolData.countdown?.remainingSeconds
              : null,
        );
      };
      overlayProvider.onAwolStateTransitionTracking = (fromState, toState) {
        AwolTracking.trackStateTransition(
          fromState: fromState.name,
          toState: toState.name,
          awolData: runnerRtDataProvider.awolData,
        );
      };
      runnerRtDataProvider.addListener(_onAwolDataChanged);
      infoBannerProvider =
          Provider.of<InfoBannerProvider>(context, listen: true);

      // Track polling start
      Trace? pollingTrace;
      try {
        pollingTrace =
            FirebasePerformance.instance.newTrace('partner_home_start_polling');
        pollingTrace.start();
      } catch (_) {}

      Future.wait([
        // [resumePolling] sets [_isPolling] true; a route below us may have
        // called [stopPolling] in dispose (e.g. login → replace home stack).
        runnerRtDataProvider.resumePolling(),
      ]).then((_) async {
        try {
          await pollingTrace?.stop();
        } catch (_) {}
        _trackHomePageViewed();
        // Selfie login → home: first current_state can still be login; poll until BE catches up.
        await runnerRtDataProvider.runPendingPostLoginPollIfAny();
      });

      Future(() {
        infoBannerProvider.fetchBanners();
      });

      _shield = SafetyShieldAdapter(
        userProfile: userProfileProvider,
        uploadQueue: GlobalState().shieldUploadQueue,
      );
      GlobalState().shieldAdapter = _shield;
      // The Flutter kavach plugin is being deprecated — Kavach is owned by KMP
      // (shared/features/kavach). We keep the adapter only for the two providers
      // build() injects; nothing here drives it into the native plugin any more.

      _sosProvider = Provider.of<SOSProvider>(context, listen: false);
      final sosProvider = _sosProvider;
      final shield = _shield;
      if (sosProvider == null || shield == null) return;

      // Legacy slider widget (SOSPopup/SOS) is dead UI — not mounted anywhere.
      // Wiring to the adapter bypass path is removed to prevent accidental
      // protocol bypass if the widget is ever re-activated.
      sosProvider.onSOSTriggered = null;
      sosProvider.onFalseAlarm = () {
        _shield?.onFalseAlarm();
      };
      shield.sosProvider = sosProvider;

      Future.microtask(
        () async {
          prefs = await SharedPreferences.getInstance();
          _shield?.prefs = prefs;
        },
      );

      // Initial setup complete

      Trace? initProcessTrace;
      try {
        initProcessTrace =
            FirebasePerformance.instance.newTrace('partner_home_init_process');
        initProcessTrace.start();
      } catch (_) {}

      initProcess().then((_) async {
        try {
          await initProcessTrace?.stop();
        } catch (_) {}

        if (mounted) {
          final _partnerHomeInitProvider =
              Provider.of<PartnerHomeInitProvider>(context, listen: false);
          // Initialize services if not already done
          await _partnerHomeInitProvider.initializeServices(context);

          // Measure first frame render
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await _screenTrace?.stop();
            } catch (_) {}
          });
        }
      });

      // Drain any deeplink parked during cold start / login. PartnerHome is the
      // single drain point: only an active, fully-registered runner reaches it,
      // so a queued deeplink can never fire mid-registration.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeepLinkRouter.instance.drainPending();
      });
    }

    // Mirror the localized KMP job-surface labels to the native launcher so
    // JobActivity/the overlay render server-driven copy instead of English defaults.
    // Runs on every didChangeDependencies pass (this State depends on LanguageProvider
    // with listen: true), so a language settle after the first frame re-pushes instead of
    // being stranded on the initial English fallbacks; the push is deduped by signature
    // inside _pushJobScreenLabels, so redundant passes are cheap no-ops.
    _pushJobScreenLabels();

    // Shield lifecycle + consent used to arm the Flutter plugin from here. KMP
    // owns Kavach now and self-feeds off current_state, so this no longer runs.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Cohort: the native KMP home owns the lifecycle. PiP, the AWOL overlay, and the
    // current_state resume-fetch are Flutter-home concerns, and their handlers touch
    // `late` providers this interim host never initialises — so skip them (they would
    // otherwise LateInitializationError when the native Activity backgrounds Flutter).
    //
    // But DO re-run the shell recovery on resume: the native shell can be torn down or
    // uncovered while this interim host stays alive (OS reclaim of the backgrounded
    // shell Activity, or Flutter brought to the front over it). A resume then
    // re-surfaces THIS loader with nothing bringing the shell back — the single opener
    // (navigateAfterRunnersMe) and the first-mount watchdog don't re-fire, and a
    // job-assigned notification tap is a cohort no-op (fetchDataNow short-circuits).
    // _ensureCohortShellOpen is idempotent and early-exits when the shell is already
    // the foreground surface, so it's cheap to call on every resume.
    if (_isMqttCohort) {
      if (state == AppLifecycleState.resumed) {
        unawaited(_ensureCohortShellOpen());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      _checkPipExitAndTrack();
      _handleResumed();
    } else if (state == AppLifecycleState.paused) {
      if (mounted) setState(() {});
      _handleAppPaused();
    } else {
      isAppForeground = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final currentSize = WidgetsBinding.instance.window.physicalSize;
    if (_lastPhysicalSize != currentSize) {
      _lastPhysicalSize = currentSize;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleResumed() async {
    if (_isAwolOverlayEnabled) {
      // Query native overlay state — this is the authoritative source of truth.
      // Avoids race conditions with stale Flutter-side flags.
      final nativeOverlayActive = await OverlayService.isOverlayVisible();
      if (nativeOverlayActive) {
        // Stop the native overlay — the foreground Flutter UI will handle
        // AWOL display (dialog or home card). Avoids showing both at once.
        overlayProvider.stopOverlay();
      }

      // Sync: native overlay is gone, ensure Flutter-side flag agrees.
      // Handles edge case where onOverlayDismissed message was lost
      // (e.g., service stopped before method channel message was delivered).
      overlayProvider.onNativeOverlayGone();

      // If user acknowledged breach via native overlay, skip dialog and show home card
      if (overlayProvider.hasAcknowledged) {
        overlayProvider.markAwolDialogShown();
        overlayProvider.markAwolDialogDismissed();
      }
    }

    isAppForeground = true;

    // Rebuild after the current frame so viewport metrics are settled
    // (critical after PiP exit). Independent of the network call below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    // Fetch fresh data before resuming normal polling so the home card
    // timer immediately reflects the server's current countdown values.
    await runnerRtDataProvider.fetchCurrentState();

    runnerRtDataProvider.stopPolling();
    runnerRtDataProvider.resumePolling();
    ignoreBatteryOptimization();

    if (_isAwolOverlayEnabled || _isAwolV2OverlayEnabled) {
      overlayProvider.refreshPermission();
    }
  }

  /// Listener callback for [RunnerRtDataProvider]. Debounces by 300 ms to
  /// coalesce rapid-fire notifyListeners() calls from polling, preventing
  /// duplicate overlay creation on slow devices.
  void _onAwolDataChanged() {
    if (!_isAwolOverlayEnabled) return;
    _awolDebounce?.cancel();
    _awolDebounce = Timer(const Duration(milliseconds: 300), _processAwolData);
  }

  /// Core AWOL logic — called after debounce. Routes to either the foreground
  /// dialog flow or the background native overlay flow depending on app state.
  void _processAwolData() {
    var awolData = runnerRtDataProvider.awolData;

    // JOB state with v2 flag off — ignore completely
    if (awolData != null && awolData.isJob && !_isAwolV2Enabled) {
      awolData = null;
    }

    // On a killed-state launch the app opens with isAppForeground=true, but
    // the first data payload may already contain a JOB AWOL. Treat that first
    // check as a background event so the native overlay is shown rather than
    // silently skipped by the foreground guard below.
    final isKilledStateLaunch =
        isAppForeground && _isFirstAwolCheck && _isJobAwol(awolData);
    _isFirstAwolCheck = false;

    if (isAppForeground && !isKilledStateLaunch) {
      // Dismiss native overlay if still active from a previous background session
      if (overlayProvider.isOverlayActive) {
        overlayProvider.stopOverlay();
      }
      _handleForegroundAwolUpdate(awolData);
      return;
    }

    // --- Background overlay logic ---
    if (awolData == null) {
      if (overlayProvider.isOverlayActive) {
        overlayProvider.stopOverlay();
      }
      return;
    }

    // AWOL v2 (KMP) owns the background/lock-screen/killed-state surface when
    // its kill-switch is on — stand down (tearing down any legacy overlay a
    // mid-episode flag flip left behind) so both overlay systems never fire
    // for one breach. JOB-AWOL is carved out: its v2 surface ships dark
    // (AwolFlags.jobAwol), so legacy keeps owning it until job-AWOL v2 lands.
    if (_isAwolV2OverlayEnabled && !_isJobAwol(awolData)) {
      if (overlayProvider.isOverlayActive) {
        overlayProvider.stopOverlay();
      }
      return;
    }

    // If we're in PiP mode, exit PiP and let the resumed lifecycle
    // handle showing the FG dialog instead of a BG overlay.
    if (pipProvider.isInPipMode) {
      _foregroundChannel.invokeMethod('bringToForeground');
      return;
    }

    // JOB-AWOL renders a timer anchored to the absolute job-start timestamp;
    // without it the native side falls through to a frozen 00:00 traffic-light
    // countdown. Skip the overlay rather than ship that broken UX.
    final jobStartMs = _jobStartEpochMillisForOverlay();
    if (_isJobAwol(awolData) && jobStartMs == null) {
      return;
    }

    // Determine overlay type:
    //   breach + not yet acknowledged → full dialog with countdown
    //   breach + acknowledged         → mini draggable pill
    //   re-entered                    → top banner
    final overlayType = (awolData.isBreach || _isJobAwol(awolData))
        ? (overlayProvider.hasAcknowledged ? 'mini' : 'dialog')
        : 'banner';
    final config = awolData.toOverlayConfig(
      languageProvider,
      jobLat: anyValueToDouble(runnerRtDataProvider.widgetInfo?.data?['lat']),
      jobLng: anyValueToDouble(runnerRtDataProvider.widgetInfo?.data?['lng']),
      jobStartTimestampMs: jobStartMs,
      nudges: runnerRtDataProvider.preActionNudges,
    );
    overlayProvider.startOverlay(
      type: overlayType,
      config: config,
      replace: true,
    );
    AwolTracking.trackPopupViewed(
      overlayType: 'overlay',
      awolData: awolData,
      timerCountShown: awolData.countdown?.remainingSeconds,
    );
  }

  /// Handle AWOL data changes while the app is in the foreground.
  /// Shows a full-screen dialog on first detection, resets state when AWOL
  /// data is cleared (runner returned to hotspot), and detects state
  /// transitions (breach ↔ re-entered) to re-show the dialog.
  void _trackHomePageViewed() {
    AwolTracking.trackHomePageViewed(
      widgetName: runnerRtDataProvider.widgetInfo?.name,
      awolData: runnerRtDataProvider.awolData,
    );
  }

  void _handleForegroundAwolUpdate(AwolData? awolData) {
    if (awolData == null) {
      if (overlayProvider.lastAwolState != null) {
        AwolTracking.trackStateTransition(
          fromState: overlayProvider.lastAwolState!.name,
          toState: 'resolved',
        );
      }
      overlayProvider.resetAwolForegroundState();
      if (mounted) setState(() {});
      return;
    }

    // Detect state transitions (breach → re-entered or vice versa)
    overlayProvider.onAwolStateChanged(awolData.state);

    // Legacy foreground AWOL dialog — this path only runs while the Flutter
    // home is itself foreground. When the KMP native home is live
    // (expert_cmp_home_screen RC on), that home hosts the shared AwolHomeSection
    // and this Flutter host is backgrounded (the AWOL v2 background branch owns
    // routing then), so the two never surface together. JOB-AWOL still defers to
    // its v2 owner.
    if (!overlayProvider.awolDialogShown &&
        !overlayProvider.hasAcknowledged &&
        !_isJobAwol(awolData)) {
      overlayProvider.markAwolDialogShown();
      _showAwolDialog(awolData);
    }

    // Home card rebuild happens automatically via Provider
    if (mounted) setState(() {});
  }

  int? _remainingSecondsForAwol(AwolData awolData) {
    return awolData.countdown?.remainingSeconds;
  }

  bool _isTimedOutForAwol(AwolData awolData) {
    final remaining = _remainingSecondsForAwol(awolData);
    return remaining != null && remaining <= 0;
  }

  void _navigateToAwolDirection(AwolData? awolData) {
    if (awolData == null) return;
    final isJob = _isJobAwol(awolData);
    final lat = isJob
        ? anyValueToDouble(runnerRtDataProvider.widgetInfo?.data?['lat'])
        : awolData.hotspot?.latitude;
    final lng = isJob
        ? anyValueToDouble(runnerRtDataProvider.widgetInfo?.data?['lng'])
        : awolData.hotspot?.longitude;
    final name = isJob ? null : awolData.hotspot?.name;
    if (lat != null && lng != null) {
      overlayProvider.onShowDirections?.call(lat, lng, name);
    }
  }

  void _showAwolDialog(AwolData initialData) {
    if (!mounted) return;

    AwolTracking.trackPopupViewed(
      overlayType: 'in_app',
      awolData: initialData,
      timerCountShown: initialData.countdown?.remainingSeconds,
    );

    // Play an alert sound + vibration when the AWOL dialog first appears.
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        // Listen to provider changes so the dialog timer stays in sync with
        // the latest API data (prevents stale countdown when server decrements
        // remaining_seconds).
        return ListenableBuilder(
          listenable: runnerRtDataProvider,
          builder: (_, __) {
            final awolData = runnerRtDataProvider.awolData ?? initialData;
            final dialogBreachNudge = runnerRtDataProvider.preActionNudges
                .firstOfType(LifecycleActionType.awolBreachPenalty);
            if (awolData.isBreach || _isJobAwol(awolData)) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: AwolBreachWidget(
                  data: awolData,
                  languageProvider: languageProvider,
                  isDialog: true,
                  awolBreachNudge: dialogBreachNudge,
                  onShowDirections: () {
                    AwolTracking.trackCtaClicked(
                      ctaType: 'show_directions',
                      source: 'dialog',
                      timerState: _isTimedOutForAwol(awolData)
                          ? 'beyond_timer'
                          : 'within_timer',
                      awolData: awolData,
                    );
                    Navigator.of(dialogContext).pop();
                    overlayProvider.markAwolDialogDismissed();
                    runnerRtDataProvider.fetchCurrentState().then((_) {
                      if (mounted) setState(() {});
                    });
                    _navigateToAwolDirection(awolData);
                  },
                  onUnderstood: () {
                    AwolTracking.trackCtaClicked(
                      ctaType: 'i_understood',
                      source: 'dialog',
                      timerState: _isTimedOutForAwol(awolData)
                          ? 'beyond_timer'
                          : 'within_timer',
                      awolData: awolData,
                    );
                    // The runner acknowledged — stop the alarm now instead of
                    // letting it run out its repeat count. `silence` (not
                    // `stop`) because the breach is still active: the episode
                    // must survive so this breach can't re-alarm off the next
                    // poll, while a genuinely new one still can.
                    unawaited(AlarmSilencer.silence());
                    Navigator.of(dialogContext).pop();
                    overlayProvider.markAwolDialogDismissed();
                    runnerRtDataProvider.fetchCurrentState().then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              );
            } else {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: AwolReEnteredWidget(
                  data: awolData,
                  languageProvider: languageProvider,
                  isDialog: true,
                  onUnderstood: () {
                    // Re-entered the hotspot: the alarm is already moot, but the
                    // clip can still be mid-sequence when this renders — stop it
                    // on the tap rather than waiting for the state feed.
                    unawaited(AlarmSilencer.silence());
                    Navigator.of(dialogContext).pop();
                    overlayProvider.markAwolDialogDismissed();
                    runnerRtDataProvider.fetchCurrentState().then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              );
            }
          },
        );
      },
    );
  }

  void _handleAppPaused() async {
    isAppForeground = false;

    // Fetch fresh data so the overlay countdown matches the server's truth.
    // This triggers notifyListeners() → _onAwolDataChanged(), which handles
    // overlay creation/dismissal when isAppForeground is false.
    await runnerRtDataProvider.fetchCurrentState();
    _enterPipOnBackground();
  }

  void _enterPipOnBackground() async {
    try {
      // Only enter PiP if supported and not already in PiP mode
      if (pipProvider.isPipSupported && !pipProvider.isInPipMode) {
        await pipProvider.enterPipMode();
      }
    } catch (e) {
      Logger().e('Error entering PiP mode: $e');
    }
  }

  void _checkPipExitAndTrack() async {
    try {
      final pipProvider = Provider.of<PipProvider>(context, listen: false);

      wasPreviouslyInPipMode = pipProvider.isInPipMode;
    } catch (e) {
      Logger().e('Error tracking PiP exit: $e');
    }
  }

  void _initializePipStateTracking() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pipProvider = Provider.of<PipProvider>(context, listen: false);
        // Initialize the tracking state
        wasPreviouslyInPipMode = pipProvider.isInPipMode;
      } catch (e) {
        Logger().e('Error initializing PiP state tracking: $e');
      }
    });
  }

  /// Listen for real-time Remote Config changes to kill the overlay mid-session.
  void _listenForAwolOverlayToggle() {
    _remoteConfigSubscription =
        RemoteConfigService.instance.onUpdatedKeys.listen((updatedKeys) {
      if (updatedKeys.contains(RemoteConfigKeys.enableAwolOverlay) &&
          !_isAwolOverlayEnabled) {
        if (overlayProvider.isOverlayActive) {
          overlayProvider.stopOverlay();
        }
        overlayProvider.resetAwolForegroundState();
      }
      // v2 (KMP) overlay flipped on mid-session: it needs SYSTEM_ALERT_WINDOW
      // too, and the permission UX lives here. The flag itself reaches native
      // via AwolOverlayChannel.listenForUpdates; the prompt no-ops when the
      // permission is already granted.
      if (updatedKeys.contains(RemoteConfigKeys.enableAwolV2Overlay) &&
          _isAwolV2OverlayEnabled) {
        _initializeOverlayPermission();
      }
    });
  }

  void _initializeOverlayPermission() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await overlayProvider.refreshPermission();
        if (!overlayProvider.hasPermission && mounted) {
          final isDismissable = !_isAwolOverlayPermissionMandatory;
          showDialog(
            context: context,
            barrierDismissible: isDismissable,
            builder: (_) => OverlayPermissionDialog(
              isDismissable: isDismissable,
            ),
          );
        }
      } catch (e) {
        Logger().e('Error initializing overlay permission: $e');
      }
    });
  }

  /// Gate 1: mic + location both required before the home page is usable.
  /// Shown once on initial load; dialog stays open until both are granted.
  void _requestMicAndLocationPermissions() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final micStatus = await Permission.microphone.status;
        final locAlways = await Permission.locationAlways.status;
        if (micStatus.isGranted && locAlways.isGranted) return;

        final isPermanentlyDenied =
            micStatus.isPermanentlyDenied || locAlways.isPermanentlyDenied;
        if (!mounted) return;
        await ShieldPermissionHandler.showPermissionDialog(
          context,
          isPermanentlyDenied: isPermanentlyDenied,
          permissionContext: ShieldPermissionContext.micAndLocation,
          hardGate: true,
        );
      } catch (e) {
        MonitoringServiceHelper.logError(
          'mic_location_gate_error',
          {'error': e.toString()},
        );
      }
    });
  }

  // late AnimationController _refreshAnimationController;
  // late Duration _refreshAnimationDuration;

  // final RefreshController _refreshController =
  //     RefreshController(initialRefresh: false);

  void showLunchBottomSheet() {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return const CommonBottomSheetSetup(
            child: LunchBreak(),
          );
        }).then((_) {
      isLunchBottomSheetVisible = false;
    });
  }

  /// Builds the localized label map for the native KMP job surfaces (keys =
  /// the native `JobScreenExtras` extra names) and pushes it to the launcher.
  /// Covers the new-job/check-in `JobStrings` extras and the delayed check-in
  /// penalty strings; each value resolves through the same
  /// `languageProvider.getMessage(key, englishDefault)` the Dart surfaces use.
  void _pushJobScreenLabels() {
    final lp = languageProvider;
    final labels = <String, String>{
      // JobStrings (see JobScreenExtras.stringsFrom)
      'extra_new_job_title': lp.getMessage('new_job_assigned', 'New Job'),
      'extra_you_will_earn': lp.getMessage('you_will_earn', 'You Will Earn'),
      'extra_accept_in': lp.getMessage('accept_job_cap', 'ACCEPT IN'),
      'extra_accept_job': lp.getMessage('accept_job', 'Accept Job'),
      'extra_deny': lp.getMessage('deny', 'Deny'),
      'extra_check_in_by': lp.getMessage('check_in_by', 'Check In by'),
      // Check-in FOOTER captions (JobStrings.checkIn/checkInByCaps/runningLate) — kept in
      // sync with the delayed-checkin footer beside them so the two never render in
      // different languages. Same i18n keys the Dart check-in surfaces already use.
      'extra_check_in': lp.getMessage('check_in', 'Check In'),
      'extra_check_in_by_caps':
          lp.getMessage('check_in_by_caps', 'CHECK IN BY'),
      'extra_running_late':
          lp.getMessage('getting_late_capital', 'RUNNING LATE'),
      'extra_generic_error': lp.getMessage(
          'something_went_wrong', 'Something went wrong. Please try again.'),
      'extra_job_reassigned': lp.getMessage(
          'job_reassigned', 'This job has been reassigned to another expert.'),
      'extra_job_accepted': lp.getMessage('job_accepted', 'Job accepted'),
      'extra_job_denied': lp.getMessage('job_denied', 'Job denied'),
      'extra_red_card_nudge':
          lp.getMessage('if_job_not_accepted', 'If job not accepted'),
      // DelayedCheckinStrings (see JobScreenExtras.delayedCheckinStringsFrom)
      'extra_dc_call_support_title':
          lp.getMessage('call_support_partner', 'Call Support Partner'),
      'extra_dc_call_support_subtitle': lp.getMessage(
          'select_option_below', 'Select an option below and place call'),
      'extra_dc_submit': lp.getMessage('submit', 'Submit'),
      'extra_dc_running_late':
          lp.getMessage('getting_late_capital', 'RUNNING LATE'),
      'extra_dc_check_in': lp.getMessage('check_in', 'Check In'),
      'extra_dc_help': lp.getMessage('help', 'Help'),
      'extra_dc_call_partner_support':
          lp.getMessage('call_partner_support', 'Call Partner Support'),
      'extra_dc_callback_toast':
          lp.getMessage('call_back_soon', 'You will receive a call back soon'),
      'extra_dc_support_details_not_found': lp.getMessage(
          'support_details_not_found', 'Support details not found'),
      'extra_dc_helpline_unavailable': lp.getMessage(
          'helpline_unavailable', 'Helpline number not available'),
      'extra_dc_submit_failed': lp.getMessage(
          'something_went_wrong', 'Something went wrong. Please try again.'),
      // Title-case fallbacks match the Figma pill + the KMP DelayedCheckinStrings
      // defaults, so a missing i18n key doesn't flip the pill to all-caps.
      'extra_dc_red_card_received':
          lp.getMessage('red_card_received', 'Red Card Received'),
      'extra_dc_red_cards_received':
          lp.getMessage('red_cards_received', 'Red Cards Received'),
    };
    final signature = labels.values.join('');
    if (signature == _lastPushedJobLabelsSignature) return;
    _lastPushedJobLabelsSignature = signature;
    JobOverlayChannel.setJobStrings(labels);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    // The mqtt_config cohort grants battery-opt pre-KMP on the language screen
    // (SelectLanguageV2._requestCohortPrePermissions); its interim home is a
    // headless loader, so re-prompting here would fire over that loader.
    if (!_isMqttCohort) ignoreBatteryOptimization();

    // _refreshAnimationController = AnimationController(vsync: this);
    // _refreshAnimationDuration = 1.ms;
    // initConnectivity();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   runnerRtDataProvider.fetchDataNow();
    // });
    // _connectivitySubscription =
    //     _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    // Initialize PiP state tracking — Flutter-home only. The cohort's native KMP
    // home owns PiP, and this reads a `late` provider the cohort never sets.
    if (!_isMqttCohort) _initializePipStateTracking();

    // KMP-migration entrypoint MOVED: the mqtt_config cohort is routed into the
    // KMP stack at login by RegistrationNavigation.openKMPStackForMqttCohort
    // (which starts the MQTT engine, then opens `bottom_nav_shell` and stands the poll
    // down). This replaces the old cmpHomeScreenEnabled cover-from-PartnerHome
    // path — non-cohort runners simply stay on this Flutter PartnerHome.

    // Re-evaluate force-update on the authenticated home: /me has loaded by now,
    // so the per-runner Android floor (if any) is applied on top of the global one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUpdateRequiredPopup();
    });

    super.initState();
  }

  // Future<void> initConnectivity() async {
  //   late List<ConnectivityResult> result;
  //
  //   try {
  //     result = await _connectivity.checkConnectivity();
  //   } on PlatformException catch (e) {
  //     Logger().e('Couldn\'t check connectivity status', error: e);
  //     return;
  //   }
  //
  //   if (!mounted) {
  //     return Future.value(null);
  //   }
  //
  //   return _updateConnectionStatus(result);
  // }

  // Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
  //   setState(() {
  //     _connectionStatus = result;
  //   });
  //   ConnectivityResult connectivityResult1 = _connectionStatus.first;
  //   runnerRtDataProvider.updateRunnerStatus(
  //     RunnerStatus(
  //       text: connectivityResult1 == ConnectivityResult.none
  //           ? "offline"
  //           : "online",
  //       color: connectivityResult1 == ConnectivityResult.none
  //           ? AppColors.r40
  //           : AppColors.g40,
  //     ),
  //   );
  //
  //   // print('Connectivity changed: $_connectionStatus');
  // }

  void _showModalBottomNeedHelp() {
    if (runnerRtDataProvider.delayedCheckinData != null) {
      _openJobSupportSheet();
      return;
    }
    showModalBottomSheet(
      context: context,
      // isScrollControlled: true,
      // constraints: BoxConstraints(
      //   minHeight: MediaQuery.of(context).size.height * 0.3,
      //   maxHeight: MediaQuery.of(context).size.height * 0.5,
      // ),
      builder: (context) {
        return const CommonBottomSheetSetup(
          child: SupportPopup(),
        );
      },
    );
  }

  void _openJobSupportSheet() {
    JobSupportBottomSheet.show(
      context,
      languageProvider: languageProvider,
      widgetData: runnerRtDataProvider.widgetInfo?.data,
      widgetName: runnerRtDataProvider.widgetInfo?.name,
      runnerId:
          Provider.of<UserProfileProvider>(context, listen: false).user?.id ??
              -1,
    );
  }

  List<Widget> pendingDocs() {
    return [
      if ((userProfileProvider.user?.isPanVerified != true ||
              userProfileProvider.user?.bankVerified != true) &&
          userProfileProvider.loading != true)
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: SizedBox(
            height: 200.h,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                // itemCount: 3,
                // shrinkWrap: true,
                // scrollDirection: Axis.horizontal,
                children: [
                  if (userProfileProvider.user?.isPanVerified != true)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MissingDetailsCard(
                        widthFactor: userProfileProvider.user?.isPanVerified !=
                                    true &&
                                userProfileProvider.user?.bankVerified != true
                            ? 0.6.sw
                            : 0.8.sw,
                        missingDetails: "Your Pan Details are missing",
                        subtitle: "Having a PAN card helps you save tax",
                        actionText: "Upload PAN card details",
                        action: () {
                          // Handle upload PAN card details action here
                          showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return const UploadPanModalSheetV2();
                              }).then((_) {
                            userProfileProvider.runnersMeSetup();
                          });
                        },
                      ),
                    ),
                  if (userProfileProvider.user?.isPanVerified != true &&
                      userProfileProvider.user?.bankVerified != true)
                    SizedBox(
                      width: 16.w,
                    ),
                  if (userProfileProvider.user?.bankVerified != true)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MissingDetailsCard(
                        widthFactor: userProfileProvider.user?.isPanVerified !=
                                    true &&
                                userProfileProvider.user?.bankVerified != true
                            ? 0.6.sw
                            : 0.8.sw,
                        missingDetails: "Your Bank Details are missing",
                        subtitle: "Please provide bank details for earnings",
                        actionText: "Upload bank details",
                        action: () {
                          Navigator.pushNamed(
                                  context, '/add_bank_or_upi_details')
                              .then((_) {
                            userProfileProvider.runnersMeSetup();
                          });
                        },
                      ),
                    ),
                ],
                // separatorBuilder:
                //     (BuildContext context, int index) {
                //   return SizedBox(
                //     width: 16.w,
                //   );
                // },
              ),
            ),
          ),
        ),
    ];
  }

  bool isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    // MQTT cohort: this Flutter home is only an interim background host — the native
    // KMP home Activity covers it within a second or two (openKMPStackForMqttCohort).
    // Render a loader, never the home UI, so cohort runners don't see the jarring
    // home-then-switch flash. (Also short-circuits the _shield == null path below,
    // since the cohort deliberately doesn't build the Dart Shield.)
    if (_isMqttCohort) {
      // Paint the KMP home's light background (n0), NOT the brand pink — the native
      // Activity (also light) covers this within ~0.5s, so matching colours makes the
      // hand-off seamless instead of a pink flash. Brand-coloured spinner for contrast.
      // If the shell couldn't be brought up (see _ensureCohortShellOpen), show a retry
      // action instead of an indefinite loader so the runner can self-recover.
      return Scaffold(
        backgroundColor: AppColors.n0,
        body: Center(
          child: _cohortShellFailed
              ? _cohortShellRetry()
              : const CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }
    // Defensive: _shield is assigned in didChangeDependencies before the first
    // build in the normal path. Guard the rare race (e.g. user profile null at
    // first dependency resolution) so build() never dereferences null — _shield!
    // was a hard crash that could take down the whole home screen.
    final shield = _shield;
    if (shield == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    // Scoped rebuild: only triggers build() when isInPipMode changes.
    // Does NOT trigger didChangeDependencies (unlike listen: true).
    final isInPipMode = context.select<PipProvider, bool>((p) => p.isInPipMode);

    if (isLunchBottomSheetVisible == false &&
        runnerRtDataProvider.widgetInfo?.data?['show_nudge'] == true &&
        isAppForeground == true) {
      isLunchBottomSheetVisible = true;
      Future(() {
        showLunchBottomSheet();
      });
    }
    if (GlobalState().showSnabbitCongratsPopup) {
      GlobalState().showSnabbitCongratsPopup = false;
      Future(() {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            constraints: BoxConstraints(
              maxHeight: 0.7.sh,
            ),
            builder: (_) {
              return CommonBottomSheetSetup(
                bgColor: AppColors.brand,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 18.h),
                      Image.asset(
                        'assets/pngs/congrats.png',
                        height: 189.h,
                      ),
                      SizedBox(height: 32.h),
                      Text(
                        languageProvider.getMessage(
                          'your_are_now',
                          'You are now a',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.n0),
                      ),
                      SizedBox(height: 16.h),
                      Image.asset(
                        "assets/pngs/snabbit_expert.png",
                        height: 87.h,
                      ),
                      SizedBox(height: 77.h),
                      SizedBox(
                        width: 1.sw,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.n90,
                            backgroundColor: AppColors.n0,
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              'get_started',
                              'Get started',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              );
            });
      });
    }

    if (runnerRtDataProvider.widgetInfo?.data?[AppStrings.autoArrival] ==
            true &&
        isAppForeground == true) {
      Future(() {
        showAutoMarkArrival();
      });
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: shield.shieldProvider),
        ChangeNotifierProvider.value(value: shield.consentProvider),
      ],
      child: PopScope(
        canPop: isDrawerOpen,
        onPopInvokedWithResult: (didPop, result) {
          try {
            _enterPipOnBackground();
          } catch (_) {
            // DO NOTHING
          }
        },
        child: Scaffold(
          drawer: isInPipMode ? null : const DrawerMenu(),
          resizeToAvoidBottomInset: false,
          drawerEnableOpenDragGesture: userProfileProvider.user?.runnerStatus !=
                  null &&
              userProfileProvider.user?.runnerStatus != RunnerState.SUSPENDED,
          onDrawerChanged: (val) {
            isDrawerOpen = val;
            if (val) {
              unawaited(
                  runnerRtDataProvider.refreshEmergencyLogoutAvailability());
              unawaited(runnerRtDataProvider.refreshPeriodLeaveAvailability());
            }
            setState(() {});
          },
          body: isInPipMode
              ? _buildPipModeUI()
              : runnerRtDataProvider.widgetUtil == null
                  ? const Center(
                      child: CupertinoActivityIndicator(),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 326,
                                child: RainbowAnimBg(
                                  initColor:
                                      runnerRtDataProvider.widgetUtil!.bgColor,
                                ),
                              ),
                              Expanded(
                                flex: 674,
                                child: Container(
                                  color: AppColors.n30,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Column(
                            children: [
                              Expanded(
                                flex: 10,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    MediaQuery.of(context).padding.top,
                                    16.w,
                                    0,
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8.h),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (runnerRtDataProvider
                                                    .widgetUtil?.showDrawer ??
                                                false)
                                              Builder(
                                                  builder: (BuildContext ctx) {
                                                return IconButton(
                                                    onPressed: () async {
                                                      Scaffold.of(ctx)
                                                          .openDrawer();
                                                    },
                                                    icon: const Icon(
                                                      Icons.menu,
                                                      color: AppColors.n0,
                                                    ));
                                              }),
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment:
                                                    Alignment.centerRight,
                                                // or center, start, etc.
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 8.w),
                                                      child: RefreshHome(),
                                                    ),
                                                    _PartnerHomeHelpChip(
                                                      label: languageProvider
                                                          .getMessage(
                                                              "help", "Help"),
                                                      onPressed: () async {
                                                        _showModalBottomNeedHelp();
                                                        ClevertapSetup.logEvent(
                                                            TrackingEvents
                                                                .homeHelpButtonClicked,
                                                            {
                                                              "home":
                                                                  "Help button clicked"
                                                            });
                                                      },
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    const SOSTab(),
                                                    if (userProfileProvider
                                                            .optedForNewRateCard &&
                                                        userProfile
                                                                .runnerStatus !=
                                                            null &&
                                                        userProfile
                                                                .runnerStatus !=
                                                            RunnerState
                                                                .SUSPENDED &&
                                                        userProfile
                                                                .isTieringEnabled !=
                                                            true) ...[
                                                      SizedBox(width: 8.w),
                                                      Consumer<
                                                          RunnerRtDataProvider>(
                                                        builder: (_, rt, __) =>
                                                            HomeRewardsHeaderPill(
                                                          coinsCount: rt
                                                              .gamificationCoins,
                                                          ticketsCount: rt
                                                              .gamificationRedCards,
                                                        ),
                                                      ),
                                                    ],
                                                    if (runnerRtDataProvider
                                                                    .widgetInfo
                                                                    ?.data?[
                                                                'break_eligible'] ==
                                                            AppStrings
                                                                .eligible ||
                                                        runnerRtDataProvider
                                                                    .widgetInfo
                                                                    ?.data?[
                                                                'break_eligible'] ==
                                                            AppStrings
                                                                .notEligible)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                left: 8.w),
                                                        child: Opacity(
                                                          opacity: runnerRtDataProvider
                                                                          .widgetInfo
                                                                          ?.data?[
                                                                      'break_eligible'] ==
                                                                  AppStrings
                                                                      .eligible
                                                              ? 1.0
                                                              : 0.5,
                                                          child: SizedBox(
                                                            width: 48.r,
                                                            // height: 38.r,
                                                            child:
                                                                OutlinedButton(
                                                              onPressed: () {
                                                                ClevertapSetup
                                                                    .logEvent(
                                                                  TrackingEvents
                                                                      .homeBreakButtonClicked,
                                                                  {},
                                                                );
                                                                showLunchBottomSheet();
                                                              },
                                                              style:
                                                                  OutlinedButton
                                                                      .styleFrom(
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                              ),
                                                              child:
                                                                  Image.asset(
                                                                "assets/pngs/lunch_icon.png",
                                                                color: AppColors
                                                                    .n0,
                                                                height: 24.r,
                                                                width: 24.r,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 8.w),
                                                      child: TierBadgeV2(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              languageProvider
                                                  .getMessage("hi_name",
                                                      "Hi ${userProfileProvider.user?.name ?? ""}")
                                                  .format({
                                                #name:
                                                    "${userProfileProvider.user?.name ?? ""}"
                                              }),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    color: AppColors.n0,
                                                  ),
                                            ),
                                            // Text(
                                            //   getKeyFromMainMessage(runnerRtDataProvider
                                            //               .widgetUtil!.mainMessage) !=
                                            //           null
                                            //       ? languageProvider.getMessage(
                                            //           getKeyFromMainMessage(
                                            //               runnerRtDataProvider
                                            //                   .widgetUtil!
                                            //                   .mainMessage)!,
                                            //           runnerRtDataProvider
                                            //               .widgetUtil!.mainMessage)
                                            //       : runnerRtDataProvider
                                            //           .widgetUtil!.mainMessage,
                                            //   //  The widget main message goes here
                                            //   style: Theme.of(context)
                                            //       .textTheme
                                            //       .headlineLarge
                                            //       ?.copyWith(
                                            //         color: AppColors.n0,
                                            //       ),
                                            // )
                                            // .animate(
                                            //     controller: _textAnimation,
                                            //     effects: [
                                            //       runnerRtDataProvider
                                            //                   .widgetUtil!.widgetName ==
                                            //               "RUNNER_JOB_IN_PROGRESS"
                                            //           ? ShakeEffect(
                                            //               delay: 900.ms,
                                            //               duration: 1200.ms)
                                            //           : MoveEffect(duration: 0.ms)
                                            //     ])
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Selector<SnabbitShieldProvider,
                                            bool>(
                                          selector: (_, p) =>
                                              p.isShieldRecording,
                                          shouldRebuild: (prev, next) =>
                                              prev != next,
                                          builder: (context, isActive, _) {
                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Container(
                                                        constraints:
                                                            BoxConstraints(
                                                          minWidth:
                                                              double.infinity,
                                                          minHeight:
                                                              MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.3,
                                                          maxHeight: MediaQuery
                                                                      .of(
                                                                          context)
                                                                  .size
                                                                  .height *
                                                              (runnerRtDataProvider
                                                                          .widgetUtil!
                                                                          .bottomButton !=
                                                                      null
                                                                  ? 0.67
                                                                  : 0.75),
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors.n0,
                                                          borderRadius:
                                                              _shield?.isCardVisible ==
                                                                      true
                                                                  ? BorderRadius
                                                                      .only(
                                                                      topLeft: Radius
                                                                          .circular(
                                                                              8.r),
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8.r),
                                                                    )
                                                                  : BorderRadius
                                                                      .circular(
                                                                          8.r),
                                                        ),
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal:
                                                                    20.w,
                                                                vertical: 25.h),
                                                        child: RefreshIndicator(
                                                          onRefresh:
                                                              runnerRtDataProvider
                                                                  .fetchDataNow,
                                                          backgroundColor:
                                                              runnerRtDataProvider
                                                                      .widgetUtil
                                                                      ?.bgColor ??
                                                                  AppColors.g40,
                                                          color: Colors.white,
                                                          child:
                                                              SingleChildScrollView(
                                                            child: Column(
                                                              children: [
                                                                if (runnerRtDataProvider
                                                                            .widgetInfo
                                                                            ?.data?['festive_banner']
                                                                        ?[
                                                                        'show'] ==
                                                                    true)
                                                                  HomeFestiveBanner(
                                                                    data: runnerRtDataProvider
                                                                            .widgetInfo
                                                                            ?.data?['festive_banner']
                                                                        ?[
                                                                        'data'],
                                                                  ),
                                                                ListenableBuilder(
                                                                  listenable:
                                                                      runnerRtDataProvider,
                                                                  builder:
                                                                      (_, __) {
                                                                    final awolData =
                                                                        runnerRtDataProvider
                                                                            .awolData;
                                                                    if (awolData ==
                                                                            null ||
                                                                        !awolData
                                                                            .isBreach ||
                                                                        !overlayProvider
                                                                            .awolDialogDismissed) {
                                                                      return const SizedBox
                                                                          .shrink();
                                                                    }
                                                                    final homeBreachNudge = runnerRtDataProvider
                                                                        .preActionNudges
                                                                        .firstOfType(
                                                                            LifecycleActionType.awolBreachPenalty);
                                                                    return Padding(
                                                                      padding: EdgeInsets.only(
                                                                          bottom:
                                                                              16.h),
                                                                      child:
                                                                          AwolBreachWidget(
                                                                        data:
                                                                            awolData,
                                                                        languageProvider:
                                                                            languageProvider,
                                                                        isDialog:
                                                                            false,
                                                                        awolBreachNudge:
                                                                            homeBreachNudge,
                                                                        onShowDirections:
                                                                            () {
                                                                          AwolTracking
                                                                              .trackCtaClicked(
                                                                            ctaType:
                                                                                'show_directions',
                                                                            source:
                                                                                'home_card',
                                                                            timerState: _isTimedOutForAwol(awolData)
                                                                                ? 'beyond_timer'
                                                                                : 'within_timer',
                                                                            awolData:
                                                                                awolData,
                                                                          );
                                                                          _navigateToAwolDirection(
                                                                              runnerRtDataProvider.awolData);
                                                                        },
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                if (RemoteConfigHelperUtils
                                                                    .isReferralsV2Enabled)
                                                                  const ReferralEarnBanner(),
                                                                runnerRtDataProvider
                                                                        .widgetUtil
                                                                        ?.mainWidget ??
                                                                    Container(),
                                                                SnabbitUdaanBanner(
                                                                  margin: EdgeInsets
                                                                      .only(
                                                                          top: 16
                                                                              .h),
                                                                ),
                                                                ApplicableTieringNudge(),
                                                                const GenericBannerWidget(
                                                                    placement:
                                                                        BannerPlacement
                                                                            .home,
                                                                    position:
                                                                        'above_referral'),
                                                                if (!RemoteConfigHelperUtils
                                                                        .isReferralsV2Enabled &&
                                                                    runnerRtDataProvider
                                                                            .widgetInfo
                                                                            ?.data?['show_referral_banner'] ==
                                                                        true)
                                                                  Padding(
                                                                    padding: EdgeInsets.only(
                                                                        top: 16
                                                                            .h),
                                                                    child:
                                                                        const ReferralHeaderView(
                                                                      source:
                                                                          'home_page',
                                                                    ),
                                                                  ),
                                                                const GenericBannerWidget(
                                                                    placement:
                                                                        BannerPlacement
                                                                            .home,
                                                                    position:
                                                                        'below_referral'),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (_shield
                                                            ?.isCardVisible ==
                                                        true)
                                                      Transform.translate(
                                                        offset: Offset(0, -8.h),
                                                        child: Consumer<
                                                            SnabbitShieldProvider>(
                                                          builder: (context,
                                                                  shield, _) =>
                                                              SnabbitShieldCard(
                                                            onStartMonitoring:
                                                                () => _shield
                                                                    ?.onStartMonitoringTapped(
                                                                        context),
                                                          ),
                                                        ),
                                                      ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          bottom: 16.h),
                                                      child:
                                                          CommonWidgetCarousel(
                                                        activeIndicatorColor:
                                                            AppColors.n60,
                                                        inactiveIndicatorColor:
                                                            AppColors.n50,
                                                        indicatorSize: 10.r,
                                                        children: [
                                                          if (_shield?.isCardVisible ==
                                                                  true &&
                                                              isActive &&
                                                              context.select<
                                                                      SnabbitShieldProvider,
                                                                      bool>(
                                                                  (p) => p
                                                                      .monitoringAcknowledged))
                                                            Padding(
                                                              padding: EdgeInsets
                                                                  .only(
                                                                      bottom:
                                                                          0.h),
                                                              child:
                                                                  _ShieldSosButton(),
                                                            ),
                                                          if (runnerRtDataProvider
                                                                      .widgetInfo
                                                                      ?.data?[
                                                                  'show_good_shift_banner'] ==
                                                              true)
                                                            TodayShiftPerformanceWidget(),
                                                          if (runnerRtDataProvider
                                                                      .widgetInfo
                                                                      ?.data?[
                                                                  'show_info_banners'] ==
                                                              true)
                                                            ...infoBannerProvider
                                                                    .infoBanners
                                                                    ?.map((e) =>
                                                                        InfoBanner(
                                                                          infoBannerModel:
                                                                              e,
                                                                        ))
                                                                    .toList() ??
                                                                [],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (isActive &&
                                                    context.select<
                                                            SnabbitShieldProvider,
                                                            bool>(
                                                        (p) => p
                                                            .monitoringAcknowledged))
                                                  Positioned(
                                                    top: -106.h,
                                                    left: 0,
                                                    right: 0,
                                                    bottom: 0,
                                                    child: IgnorePointer(
                                                      child: Center(
                                                        child: Lottie.asset(
                                                          'assets/kavach_opt.json',
                                                          key: const ValueKey(
                                                              'kavach_lottie'),
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                          repeat: false,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              Icon(
                                                                  Icons
                                                                      .error_outline,
                                                                  size: 48.r,
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (runnerRtDataProvider.waitForFetchData ==
                                      false &&
                                  runnerRtDataProvider
                                          .widgetUtil?.bottomButton !=
                                      null)
                                runnerRtDataProvider.widgetUtil!.bottomButton!,
                              // Lunch-slots banner (server-driven
                              // `show_lunch_selection`) — flush at the bottom
                              // edge. Renders nothing while the flag is off.
                              const LunchSlotsBannerSlot(),
                              if (GlobalState().appConfig?.useNavPadding !=
                                  false)
                                Container(
                                  color: AppColors.n0,
                                  width: 1.sw,
                                  // Fixed 32.h is shorter than a 3-button nav
                                  // bar, so the content above (the lunch
                                  // banner's CTA) was clipped by it. Take the
                                  // real bottom system inset when it is larger;
                                  // gesture-nav devices keep 32.h.
                                  height: math.max(
                                    32.h,
                                    MediaQuery.viewPaddingOf(context).bottom,
                                  ),
                                ),
                              // if (runnerRtDataProvider.widgetUtil?.widgetName ==
                              //         "RUNNER_JOB_IN_PROGRESS" &&
                              //     jobRemainingDuration!.inMinutes <= 1 &&
                              //     !cashCollected)
                              //   workInProgressBottomButton()
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildPipModeUI() {
    return GestureDetector(
      onTap: () {
        // Tapping will automatically expand the app from PiP mode
        Logger().i('PiP window tapped - expanding to full screen');
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    languageProvider.getMessage('pip_title', 'Snabbit Expert'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 30.h),
                  Icon(
                    Icons.location_on,
                    color: AppColors.n0,
                    size: 64.sp,
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    languageProvider.getMessage('pip_subtitle', 'Active'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            // Status indicator (online/offline)
            // Positioned(
            //   top: 8,
            //   right: 8,
            //   child: Consumer<RunnerRtDataProvider>(
            //     builder: (context, provider, child) {
            //       final isOnline =
            //           _connectionStatus.first != ConnectivityResult.none;
            //       return Container(
            //         width: 8,
            //         height: 8,
            //         decoration: BoxDecoration(
            //           color: isOnline ? Colors.green : Colors.red,
            //           shape: BoxShape.circle,
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  String? getKeyFromMainMessage(String message) {
    switch (message) {
      case "Please confirm your attendance":
        return "please_confirm_your_attendance";
      case "We are waiting for your response":
        return "waiting_for_response";
      case "You're marked absent.":
        return "youre_marked_absent";
      case "Mark your attendance":
        return "mark_your_attendance";
      case "You are logged in!":
        return "logged_in";
      case "You are logged out!":
        return "logged_out";
      case "You are suspended!":
        return "youre_suspended";
      case "We expect your presence on time":
        return "expect_presence_on_time";
      case "You are on the job!":
        return "on_the_job";
      case "Your shift has ended":
        return "youre_shift_ended";
      case "Give us some time to resolve the issue.":
        return "give_time_to_resolve_issue";
      case "Job completed. Take some rest!":
        return "job_completed_take_rest";
      default:
        return null;
    }
  }

  @override
  void dispose() {
    // Null the SOS callbacks BEFORE disposing the adapter so an in-flight
    // SOSProvider callback cannot invoke a half-disposed adapter.
    _sosProvider?.onSOSTriggered = null;
    _sosProvider?.onFalseAlarm = null;
    _shield?.dispose();
    _awolDebounce?.cancel();
    _remoteConfigSubscription?.cancel();
    runnerRtDataProvider.removeListener(_onAwolDataChanged);
    runnerRtDataProvider.stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    try {
      _screenTrace?.stop();
    } catch (_) {}
    // _refreshAnimationController.dispose();
    // _connectivitySubscription.cancel();

    // PartnerHome disposed

    super.dispose();
  }

  void showAutoMarkArrival() async {
    if (prefs == null) {
      return;
    }
    try {
      final markedArrival = prefs?.getInt(AppStrings.autoArrival);
      if (markedArrival == null ||
          runnerRtDataProvider.widgetInfo?.data?[AppStrings.runnerJobId] !=
              markedArrival) {
        showModalBottomSheet(
            context: context,
            barrierColor: Colors.black.withOpacity(0.79),
            builder: (_) {
              return const CommonBottomSheetSetup(
                child: AutoMarkArrival(),
              );
            });
        if (runnerRtDataProvider.widgetInfo?.data?[AppStrings.runnerJobId] !=
            null) {
          prefs?.setInt(AppStrings.autoArrival,
              runnerRtDataProvider.widgetInfo?.data?[AppStrings.runnerJobId]);
        }
      }
    } catch (_) {}
  }
}

class RunnerStatus extends StatelessWidget {
  final Color color;
  final String? text;

  const RunnerStatus({
    super.key,
    this.color = AppColors.g40,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return text != null && text!.isNotEmpty
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50.r),
              border: Border.all(color: AppColors.n40),
              color: AppColors.n0,
            ),
            padding: EdgeInsets.symmetric(
              vertical: 5.h,
              horizontal: 8.w,
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Container(
                    width: 8.r,
                    height: 8.r,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(
                  text!.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: color),
                ),
              ],
            ),
          )
        : Container();
  }
}

class PendingPayout extends StatelessWidget {
  const PendingPayout({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Response?>(
      future: PayoutHttp.getPendingPayout(),
      builder: (context, snapshot) {
        try {
          // If data is still loading or there's an error, show nothing
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data == null) {
            return const SizedBox.shrink();
          }

          // Extract data from response
          final data = snapshot.data!.data;
          final showPendingPayout = data['is_visible'] == true;
          final pendingPayoutAmount =
              anyValueToInt(data['pending_amount']) ?? 0;

          // If show_pending_payout is not true, show nothing
          if (!showPendingPayout) {
            return const SizedBox.shrink();
          }

          // Show payout amount if available
          return Consumer<UserProfileProvider>(
              builder: (context, userProfileProvider, _) {
            return InkWell(
              onTap: () => navigateToEarningsPage(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 125.w),
                child: Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 4.h,
                      horizontal: 12.w,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1000.r),
                      color: AppColors.n0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RichText(
                        overflow: TextOverflow.fade,
                        text: TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(right: 4.w),
                                child: Image.asset(
                                  "assets/pngs/referral_currency.png",
                                  height: 22.7.r,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: formatIndianCurrency(pendingPayoutAmount),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          });
        } catch (e) {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// SOS button matching Figma 23204-17203: red pill with siren icon + "SOS" text.
/// Used on partner home when shield card is visible and sos_visibility is true.
/// Shows a loader while the SOS bottom sheet is being prepared.
class _ShieldSosButton extends StatefulWidget {
  const _ShieldSosButton();

  @override
  State<_ShieldSosButton> createState() => _ShieldSosButtonState();
}

class _ShieldSosButtonState extends State<_ShieldSosButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.r,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading
              ? null
              : () async {
                  final adapter = GlobalState().shieldAdapter;
                  if (adapter == null) {
                    showSnackbar(context, 'An unexpected error has occurred.');
                    return;
                  }
                  setState(() => _loading = true);
                  try {
                    await adapter.triggerManualSosOnly(context);
                  } catch (_) {
                    if (mounted) {
                      showSnackbar(
                          context, 'An unexpected error has occurred.');
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEC1313),
              border: Border.all(color: AppColors.n0, width: 1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 6.h),
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: const CircularProgressIndicator(
                        color: AppColors.n0,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/pngs/shield_siren_icon.png',
                        width: 15.3.w,
                        height: 20.h,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'SOS',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.n0,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.sp,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Help — Expert App 2.0 header: transparent fill, white 1px stroke, white icon + label.
class _PartnerHomeHelpChip extends StatelessWidget {
  const _PartnerHomeHelpChip({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(1000.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1000.r),
              border: Border.all(color: AppColors.n0, width: 1),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    size: 15.sp,
                    color: AppColors.n0,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SOSTab extends StatefulWidget {
  const SOSTab({super.key});

  @override
  State<SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends State<SOSTab> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
      builder: (context, runnerRtDataProvider, child) {
        final sosVisibility = runnerRtDataProvider.sosVisibility;

        // Hide SOS button if visible is explicitly false
        // Default to visible if sos_visibility is null (backward compatibility)
        if (sosVisibility?.visible == false) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 35.r,
          child: InkWell(
            borderRadius: BorderRadius.circular(1000.r),
            onTap: () async {
              final adapter = GlobalState().shieldAdapter;

              // If adapter is available, mirror Shield SOS button behaviour.
              if (adapter != null) {
                try {
                  setState(() {
                    isLoading = true;
                  });
                  await adapter.triggerManualSosOnly(context);
                } catch (e, st) {
                  try {
                    await adapter.showSosBottomSheet();
                  } catch (_) {
                    MonitoringServiceHelper.logError(
                      'SOSTAB_SHIELD_SOS_FAILED',
                      {
                        'error': e.toString(),
                        'stack_trace': st.toString(),
                      },
                    );
                    ClevertapSetup.logEvent(
                      TrackingEvents.sosFromSosTabFailed,
                      {
                        'source': 'sostab',
                        'reason': 'shield_adapter_error',
                      },
                    );
                    if (context.mounted) {
                      showSnackbar(
                        context,
                        e.toString(),
                      );
                    }
                  }
                }
                setState(() {
                  isLoading = false;
                });
              } else {
                ClevertapSetup.logEvent(
                  TrackingEvents.sosFromSosTabFailed,
                  {
                    'source': 'sostab',
                    'reason': 'shield_adapter_missing',
                  },
                );

                // No Shield adapter available – surface a graceful error instead
                // of falling back to the slider-based SOS bottom sheet.
                if (context.mounted) {
                  showSnackbar(
                    context,
                    'An unexpected error has occurred.',
                  );
                }
              }
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1000.r),
                  border: Border.all(
                    color: AppColors.n0,
                    width: 1.r,
                  ),
                  color: const Color(0xffC72514),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 5.h,
                  horizontal: 12.w,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isLoading
                        ? CupertinoActivityIndicator(
                            radius: 10.r,
                            color: AppColors.n0,
                          )
                        : Image.asset(
                            'assets/pngs/shield_siren_icon.png',
                            width: 15.3.w,
                            height: 18.h,
                            fit: BoxFit.contain,
                          ),
                    SizedBox(width: 4.w),
                    Text(
                      'SOS',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: AppColors.n0,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RefreshHome extends StatefulWidget {
  const RefreshHome({super.key});

  @override
  State<RefreshHome> createState() => _RefreshHomeState();
}

class _RefreshHomeState extends State<RefreshHome> {
  bool isRefreshing = false;
  int countdown = GlobalState().appConfig?.refreshCooldown ?? 10;

  void _handleRefresh(BuildContext context) {
    if (isRefreshing) return;

    final runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: false);
    runnerRtDataProvider.fetchDataNow();

    setState(() {
      isRefreshing = true;
      countdown = GlobalState().appConfig?.refreshCooldown ?? 10;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() {
          countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          isRefreshing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleRefresh(context),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: Icon(
              Icons.refresh_rounded,
              color:
                  isRefreshing ? Colors.white.withOpacity(0.5) : Colors.white,
            ),
          ),
          if (isRefreshing)
            Positioned(
              right: 5.r,
              bottom: 2.r,
              child: Container(
                width: 12.r,
                height: 12.r,
                decoration: const BoxDecoration(
                  color: AppColors.n0,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                padding: EdgeInsets.all(2.r),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$countdown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
