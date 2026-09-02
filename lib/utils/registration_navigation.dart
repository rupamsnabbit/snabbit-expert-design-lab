import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/pages/signup/training_slots.dart';
import 'package:snabbit_runner/pages/verification_display.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/partner_home_init_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/services/realtime/mqtt_cohort_cache.dart';
import 'package:snabbit_runner/services/realtime/realtime_channel.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';

/// Central navigation for registration [registration_step] and related webviews.
class RegistrationNavigation {
  RegistrationNavigation._();

  @visibleForTesting
  static RegistrationStep? registrationStepAfterReset({
    required RegistrationStep? snapshot,
    required RegistrationStep? refreshed,
    required bool resetSucceeded,
  }) =>
      resetSucceeded ? refreshed : snapshot;

  /// True when the runner dismissed city webview without completing (back/close
  /// with no bifrost result). Completion may still leave [cityStep] on runners/me
  /// briefly — that must not be treated as a dismiss.
  @visibleForTesting
  static bool shouldSkipNavigationAfterCityClose({
    required String? stepBefore,
    required String? stepAfter,
    required String cityStep,
    required bool webviewClosedWithResult,
  }) =>
      stepBefore == cityStep &&
      stepAfter == cityStep &&
      !webviewClosedWithResult;

  /// True when a required Android update must block the KMP cohort handoff: the
  /// force-update popup (`showUpdateRequiredPopup`) is a Flutter dialog and the
  /// native KMP shell would cover it, so while an update is required — and the RC
  /// gate ([RemoteConfigKeys.kmpForceUpdateGateEnabled], default-ON) is on — we
  /// keep the runner on the Flutter surface where the block is visible. Reads the
  /// two live singletons so both KMP-shell openers gate identically from one place.
  /// Default-ON is intentional: if RC can't be read we fail toward BLOCKING an
  /// outdated runner rather than letting the bypass back in.
  static bool _forceUpdateBlocksKmpHandoff() {
    final gateEnabled = RemoteConfigService.instance.getBool(
      RemoteConfigKeys.kmpForceUpdateGateEnabled,
      defaultValue: true,
    );
    final updateRequired = GlobalState().isAndroidUpdateRequired();
    // Observability: isAndroidUpdateRequired() returns false BOTH when the build is
    // genuinely at/above the floor AND when the check couldn't run on real inputs
    // (version code unknown, or neither floor loaded — see
    // androidUpdateCheckIndeterminate). If an ENABLED gate passes on missing inputs,
    // that's a fail-open, not a confirmed pass — surface it so the two are
    // distinguishable in Coralogix.
    if (gateEnabled &&
        !updateRequired &&
        GlobalState().androidUpdateCheckIndeterminate) {
      MonitoringServiceHelper.logInfo(
          'kmp_handoff_gate_check_indeterminate', const {});
    }
    return gateEnabled && updateRequired;
  }

  /// Routes after [UserProfileProvider.runnersMeSetup] (e.g. init or city close).
  ///
  /// Returns `true` when it routed **away** from the current screen, leaving it
  /// covered — either by replacing the root stack (SUSPENDED / FAILED / ACTIVE)
  /// or by pushing a back-blocked page over it (onboarding hub / training
  /// webview / TrainingSlots, all `canPop: false`). In that case the caller must
  /// keep any loading spinner up: clearing its loading flag would flash the
  /// current screen's content during the route transition, and — since those
  /// targets block back — the current screen is never shown again anyway.
  ///
  /// Returns `false` only when it **stayed** on the current screen (e.g. the
  /// language picker), so the caller should reveal that screen's content.
  static Future<bool> navigateAfterRunnersMe(
    BuildContext context, {
    bool replace = false,
    bool skipCityWebView = false,
  }) async {
    if (!context.mounted) return false;
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    // Wait for the post-login RC targeting refresh so config-gated routing
    // below (isTrainingV2Enabled) reads fresh values on first login instead of
    // racing the fire-and-forget refresh.
    await provider.ensureTargetingApplied();
    if (!context.mounted) return false;
    final user = provider.user;

    if (user?.runnerStatus == RunnerState.SUSPENDED) {
      if (user?.registrationStep?.step == PartnerHome.routeName) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          PartnerHome.routeName,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          VerificationDisplay.routeName,
          (route) => false,
        );
      }
      return true;
    }

    if (user?.runnerStatus == RunnerState.FAILED) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        VerificationDisplay.routeName,
        (route) => false,
      );
      return true;
    }

    if (user?.runnerStatus == RunnerState.ACTIVE) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        PartnerHome.routeName,
        (route) => false,
      );
      // MQTT (realtime) cohort. Selector = presence of `mqtt_config` on
      // runners/me — server-owned, with the per-runner kill living inside it
      // (`mqtt_kmp_enabled`); the native pushConfig result is authoritative.
      // When enabled we start the MQTT engine and cover the just-pushed
      // PartnerHome with the KMP stack (bottom_nav_shell → BottomNavHost), which reads
      // RunnerStateStore — now fed by MQTT→DB. Otherwise we fail OPEN to Flutter
      // PartnerHome + polling. RunnerRtDataProvider is captured synchronously
      // (context in scope) so no BuildContext crosses the async gap.
      if (user?.mqttConfig != null) {
        final poller =
            Provider.of<RunnerRtDataProvider>(context, listen: false);
        // Captured synchronously (context in scope) so no BuildContext crosses the
        // async gap — the cohort switch awaits its IoT-FGS-ready signal before
        // covering PartnerHome with the native Activity (so the FGS starts first).
        final initProvider =
            Provider.of<PartnerHomeInitProvider>(context, listen: false);
        unawaited(openKMPStackForMqttCohort(user, poller, initProvider));
      }
      return true;
    }

    // Match release: onboarding hub takes priority over REGISTERED/TRAINING.
    if (user?.registrationStep?.step == OnboardingScreen.routeName) {
      final bool useWebHub = (user?.runnerStatus == RunnerState.CREATED ||
              user?.runnerStatus == RunnerState.TRAINING) &&
          user?.registrationStep?.rawStep ==
              RunnerRegistrationStep.onboardingV2 &&
          RemoteConfigHelperUtils.isTrainingV2Enabled;
      if (useWebHub) {
        // V2: the onboarding hub is the training webview. Delegate to the
        // canonical entry so placement stays consistent and replace-aware
        // (replace:true clears any prior hub to the language/root anchor;
        // replace:false stacks) instead of duplicating that here. The legacy
        // (flag-off) native push below is unchanged.
        NavigationUtils.openTrainingWebView(context: context, replace: replace);
        return true;
      }
      // Legacy native onboarding hub — unchanged.
      if (replace) {
        Navigator.of(context).pushReplacementNamed(OnboardingScreen.routeName);
      } else {
        Navigator.of(context).pushNamed(OnboardingScreen.routeName);
      }
      return true;
    }

    if (user?.runnerStatus == RunnerState.REGISTERED) {
      if (replace) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          TrainingSlots.routeName,
          (route) =>
              route.settings.name == SelectLanguageV2.routeName ||
              route.settings.name == '/',
        );
      } else {
        Navigator.of(context).pushNamed(TrainingSlots.routeName);
      }
      return true;
    }

    if (user?.registrationStep?.step == SelectLanguageV2.routeName) {
      return false;
    }

    await navigateToRegistrationStep(
      context,
      replace: replace,
      skipCityWebView: skipCityWebView,
    );
    return false;
  }

  /// MQTT cohort login switch (replaces the `cmpHomeScreenEnabled` entrypoint,
  /// modelled on PR #449): starts the realtime engine and covers the just-pushed
  /// [PartnerHome] with the KMP stack (`bottom_nav_shell` → `BottomNavHost`), which
  /// reads `RunnerStateStore` — now fed by MQTT→DB. Cohort = presence of
  /// `mqtt_config` ([UserProfile.mqttConfig]); absent ⇒ polling cohort, stays on
  /// Flutter. Rollback is server-side (backend stops sending `mqtt_config`).
  ///
  /// Fails OPEN at every step so a runner is never stranded on a stopped poll
  /// with no surface:
  ///   1. [RunnerRtDataProvider.beginMqttCohortAttempt] stands the poll down
  ///      synchronously (pending) before the async gap.
  ///   2. `pushConfig` → per-runner kill (`mqtt_kmp_enabled`=false) reports
  ///      enabled=false ⇒ [RunnerRtDataProvider.abortMqttCohort] back to polling.
  ///   3. `start()` the engine, then open the KMP host. Host launched ⇒
  ///      [RunnerRtDataProvider.confirmMqttCohort] (KMP is the surface, poll
  ///      stays down); could not launch (no host / Koin-not-ready / destination
  ///      unregistered) ⇒ [RunnerRtDataProvider.abortMqttCohort] so the
  ///      already-foreground PartnerHome polls.
  ///
  /// The wire key is `bottom_nav_shell` (`BottomNavHost`), NOT `shift_home` — the
  /// latter is registered nowhere (the original #449 typo that left it inert).
  static Future<void> openKMPStackForMqttCohort(
    UserProfile? user,
    RunnerRtDataProvider poller,
    PartnerHomeInitProvider initProvider,
  ) async {
    final mqttConfig = user?.mqttConfig;
    if (mqttConfig == null) return; // polling cohort → Flutter PartnerHome

    // Force-update wins over the KMP migration. The "Update Required" block is a
    // Flutter dialog (`showUpdateRequiredPopup`) and the native KMP shell would
    // cover it — so when a mandatory update is pending we do NOT hand off: the
    // runner stays on the just-pushed Flutter PartnerHome, whose initState popup
    // blocks them until they update. Self-heals — once they are on a build at/above
    // the floor, isAndroidUpdateRequired() is false and the handoff runs as normal.
    // Placed BEFORE beginMqttCohortAttempt so the poll is never stood down here.
    // RC-gated (default-ON) so it is reversible without a binary push.
    if (_forceUpdateBlocksKmpHandoff()) {
      MonitoringServiceHelper.logInfo('kmp_handoff_blocked_force_update', {
        'surface': 'online',
      });
      // We return before the try/finally below that drains a queued deeplink, so
      // surface any pending link instead of dropping it silently (no-op if none).
      unawaited(DeepLinkRouter.instance.reportPendingDroppedByForceUpdate());
      return;
    }

    // Stand the poll down synchronously (pending) BEFORE the async gap so a
    // concurrent PartnerHome init can't arm a poll while we stand up MQTT + KMP.
    // Double-open guard: returns false if an attempt is already pending or
    // confirmed, so a re-fired navigateAfterRunnersMe (city-close / refresh /
    // re-login) never stacks a second engine + KMP host.
    if (!poller.beginMqttCohortAttempt()) return;

    // When the shell is confirmed up, the deeplink is drained by the shell's onResume
    // (drainDeeplinks → drainPending) so the linked screen opens ON TOP of the shell.
    // Only if the shell does NOT come up (fail-open to Flutter) do we drain here.
    var shellConfirmed = false;
    try {
      final enabled = await RealtimeChannel.pushConfig(mqttConfig);
      if (!enabled) {
        // Per-runner KMP kill (mqtt_kmp_enabled=false). Rare (backend rarely sends
        // it) and until now silent — log it so a resulting stuck loader is
        // diagnosable. PartnerHome's watchdog surfaces a retry in this case.
        MonitoringServiceHelper.logWarning(
            'kmp_cohort_disabled_for_runner', {});
        poller.abortMqttCohort(); // per-runner kill → fail OPEN to polling
        return;
      }
      // Feature #1: push the app-side MQTT kill-switch + poll cadence so the
      // engine we start next picks MQTT vs poll-only mode (persisted natively for
      // the cold-boot path). Fail-open: default MQTT-on when RC is unavailable.
      await RealtimeChannel.setMqttEnabled(
        RemoteConfigService.instance
            .getBool(RemoteConfigKeys.mqttEnabled, defaultValue: true),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.currentStatePollInterval,
          defaultValue: 60,
        ),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.mqttConnectTimeout,
          defaultValue: 25,
        ),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.mqttPostActionTimeout,
          defaultValue: 5,
        ),
        healthAnalyticsEnabled: RemoteConfigService.instance
            .getBool(RemoteConfigKeys.mqttHealthAnalytics, defaultValue: true),
      );
      await RealtimeChannel.start();
      // Let the interim PartnerHome start the IoT foreground service while Flutter is
      // still foregrounded — wait (bounded) for its `startService()` BEFORE the native
      // Activity backgrounds the engine. Without this the FGS start races the pause and
      // the IoT service often never starts for the cohort. Best-effort: the timeout
      // never blocks the KMP open (the FGS self-heals on the next foreground otherwise).
      try {
        await initProvider.servicesReady.timeout(const Duration(seconds: 8));
      } catch (_) {
        // Timed out (or IoT init still running) — proceed; don't strand the cohort.
      }
      // Cover PartnerHome with the KMP stack. Only commit the cohort (keep the
      // poll down) if the host actually launched; otherwise fail OPEN so the
      // foreground PartnerHome still has data.
      final opened = await KmpNavigationBridge.instance
          .openNativeDestination('bottom_nav_shell');
      if (opened) {
        poller.confirmMqttCohort(); // KMP is the surface; poll stays down
        shellConfirmed = true; // shell onResume will drain the deeplink onto it
      } else {
        poller.abortMqttCohort();
        MonitoringServiceHelper.logWarning('kmp_bottom_nav_shell_open_failed', {
          'reason': 'no_host_or_koin_not_ready',
        });
      }
    } catch (e) {
      // Any failure standing up the engine/host → fail OPEN so the runner is
      // never stranded on a stopped poll with no surface.
      poller.abortMqttCohort();
      MonitoringServiceHelper.logError('realtime_enable_failed', {
        'error': e.runtimeType.toString(),
      });
    } finally {
      // Only drain here when the shell did NOT come up (fail-open to Flutter) — the link
      // then opens on the Flutter PartnerHome the runner is actually on. When the shell
      // IS confirmed, the drain is driven by the shell's onResume (drainDeeplinks) so the
      // link opens ON TOP of the shell instead of being covered by this launch. Idempotent
      // (drainPending nulls the slot first) and fire-and-forget.
      if (!shellConfirmed) {
        unawaited(DeepLinkRouter.instance.drainPending());
      }
    }
  }

  /// Offline cold-start path for the `mqtt_config` cohort. When `runners/me` fails
  /// (no network / server error) we can't read a fresh `mqtt_config`, but if the
  /// last online session persisted cohort membership ([MqttCohortCache]) we still
  /// stand up the KMP stack: the engine cold-boots from the natively-persisted
  /// config + JWT (`RealtimeConfigStore.hydrate`) — offline it can't connect, so it
  /// settles on the Offline status while the KMP home renders the last-known Room
  /// snapshot (+ the offline banner). No `pushConfig`: Dart has no config offline;
  /// the native store already holds the last-known-good.
  ///
  /// Returns true iff the KMP host launched (caller then leaves KMP as the surface);
  /// false fails OPEN to the caller's standard offline screen. Never throws.
  static Future<bool> openKMPStackForOfflineCohort(
    RunnerRtDataProvider poller,
  ) async {
    // Only the persisted cohort routes to KMP offline; everyone else sees the
    // standard offline screen.
    if (!await MqttCohortCache.isCohort()) return false;

    // Same force-update gate as the online path: keep a runner who owes a
    // mandatory update on the Flutter surface (where `showUpdateRequiredPopup`
    // can block them) instead of covering it with the native KMP shell.
    // Best-effort offline: on a cold offline start the version floors are usually
    // unknown (setAppConfig couldn't fetch), so this no-ops and KMP opens as
    // before — an offline runner can't reach the Play Store anyway, and the online
    // path gates them the moment they reconnect. Returning false fails open to the
    // caller's standard offline screen (where the popup still fires).
    if (_forceUpdateBlocksKmpHandoff()) {
      MonitoringServiceHelper.logInfo('kmp_handoff_blocked_force_update', {
        'surface': 'offline',
      });
      unawaited(DeepLinkRouter.instance.reportPendingDroppedByForceUpdate());
      return false;
    }

    // Stand the poll down (pending) + double-open guard, exactly as the online path.
    if (!poller.beginMqttCohortAttempt()) return false;
    try {
      // Start the engine from the persisted native config — no fresh pushConfig,
      // Dart has none offline. RealtimeHost.create hydrates mqtt_config + JWT.
      await RealtimeChannel.start();
      final opened = await KmpNavigationBridge.instance
          .openNativeDestination('bottom_nav_shell');
      if (opened) {
        poller.confirmMqttCohort(); // KMP is the surface; poll stays down
        return true;
      }
      poller.abortMqttCohort();
      MonitoringServiceHelper.logWarning('kmp_offline_cohort_open_failed', {
        'reason': 'no_host_or_koin_not_ready',
      });
      return false;
    } catch (e) {
      // Fail OPEN: any failure standing up the host → the caller shows the
      // standard offline screen instead of a blank wedge.
      poller.abortMqttCohort();
      MonitoringServiceHelper.logError('offline_cohort_enable_failed', {
        'error': e.runtimeType.toString(),
      });
      return false;
    }
  }

  /// Navigates to the screen for the current [RegistrationStep], including
  /// city-selection webview when [RegistrationStep.rawStep] is [citySelection].
  static Future<void> navigateToRegistrationStep(
    BuildContext context, {
    bool replace = false,
    bool skipCityWebView = false,
  }) async {
    if (!context.mounted) return;
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    final regSnapshot = provider.user?.registrationStep;
    final rawStep = regSnapshot?.rawStep;

    var resetSucceeded = true;
    if (RunnerRegistrationStep.requiresResetBeforeOpen(rawStep)) {
      resetSucceeded = await provider.resetRegistrationAndRefresh();
      if (!context.mounted) return;
      if (!resetSucceeded) {
        showSnackbar(
          context,
          'Could not refresh your registration. Please try again.',
        );
        return;
      }
    }

    final reg = registrationStepAfterReset(
      snapshot: regSnapshot,
      refreshed: provider.user?.registrationStep,
      resetSucceeded: resetSucceeded,
    );

    if (reg?.rawStep == RunnerRegistrationStep.citySelection) {
      if (skipCityWebView) {
        if (replace) {
          Navigator.of(context)
              .pushReplacementNamed(OnboardingScreen.routeName);
        } else {
          Navigator.of(context).pushNamed(OnboardingScreen.routeName);
        }
        refreshOnboardingModules(context);
        return;
      }
      await openCitySelectionWebView(context);
      return;
    }

    final route = reg?.step;
    if (route != null && route.isNotEmpty) {
      // v2: the onboarding hub is the training webview, not the native
      // OnboardingScreen. getStepRouteName maps the onboarding step to
      // OnboardingScreen unconditionally, so resolve it flag-awarely here —
      // same condition as navigateAfterRunnersMe — and enter the hub via the
      // canonical openTrainingWebView (replace-aware). Flag-off / other steps
      // are unchanged.
      final user = provider.user;
      final useWebHub = route == OnboardingScreen.routeName &&
          (user?.runnerStatus == RunnerState.CREATED ||
              user?.runnerStatus == RunnerState.TRAINING) &&
          reg?.rawStep == RunnerRegistrationStep.onboardingV2 &&
          RemoteConfigHelperUtils.isTrainingV2Enabled;
      if (useWebHub) {
        NavigationUtils.openTrainingWebView(context: context, replace: replace);
        return;
      }
      if (replace) {
        Navigator.of(context).pushReplacementNamed(route);
      } else {
        Navigator.of(context).pushNamed(route);
      }
      return;
    }

    if (replace) {
      Navigator.of(context).pushReplacementNamed(SelectLanguageV2.routeName);
    } else {
      Navigator.of(context).pushNamed(SelectLanguageV2.routeName);
    }
  }

  static Future<void> openCitySelectionWebView(BuildContext context) async {
    if (!context.mounted) return;
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    final stepBefore = provider.user?.registrationStep?.rawStep;
    final result = await Navigator.of(context).pushNamed(
      AppWebViewPage.routeName,
      arguments: WebViewArgs(
        url: buildWebviewUrl(WebviewRoutes.citySelection),
        title: 'City selection',
        fetchLocation: true,
      ),
    );
    if (!context.mounted) return;
    final webviewClosedWithResult = result != null;
    await refreshRegistrationAndContinue(
      context,
      skipAutoNavigateIfStillOn: RunnerRegistrationStep.citySelection,
      stepBeforeRefresh: stepBefore,
      webviewClosedWithResult: webviewClosedWithResult,
    );
  }

  static Future<void> openEarlyRegistrationWebView(
    BuildContext context, {
    required int moduleId,
  }) async {
    await Navigator.of(context).pushNamed(
      AppWebViewPage.routeName,
      arguments: WebViewArgs(
        url: buildWebviewUrl(WebviewRoutes.earlyRegistrationForm(moduleId)),
        title: 'Registration',
        fetchLocation: true,
      ),
    );
    if (!context.mounted) return;
    refreshOnboardingModules(context);
  }

  /// After city webview closes: refresh profile and route to latest step.
  ///
  /// When [skipAutoNavigateIfStillOn] is set (city flow), skips re-navigation if
  /// the runner dismissed the webview without completing — backend step unchanged.
  static Future<void> refreshRegistrationAndContinue(
    BuildContext context, {
    String? skipAutoNavigateIfStillOn,
    String? stepBeforeRefresh,
    bool webviewClosedWithResult = false,
  }) async {
    if (!context.mounted) return;
    final provider = Provider.of<UserProfileProvider>(context, listen: false);
    await provider.runnersMeSetup();

    if (skipAutoNavigateIfStillOn != null) {
      final stepAfter = provider.user?.registrationStep?.rawStep;
      if (shouldSkipNavigationAfterCityClose(
        stepBefore: stepBeforeRefresh,
        stepAfter: stepAfter,
        cityStep: skipAutoNavigateIfStillOn,
        webviewClosedWithResult: webviewClosedWithResult,
      )) {
        return;
      }
    }
    if (!context.mounted) return;
    await navigateAfterRunnersMe(
      context,
      replace: true,
      skipCityWebView: webviewClosedWithResult,
    );
  }

  /// After module webview closes: reload Opero onboarding modules on the hub.
  static void refreshOnboardingModules(BuildContext context) {
    Provider.of<OnboardingStepsProvider>(context, listen: false)
        .setupOnboardingScreen();
  }
}
