import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/pages/login/send_otp.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/pages/signup/training_slots.dart';
import 'package:snabbit_runner/pages/verification_display.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/overlay_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/select_language_init_provider.dart';
import 'package:snabbit_runner/referrals/widgets/referee_modal.dart';
import 'package:snabbit_runner/services/analytics/analytics_service.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/realtime/mqtt_cohort_cache.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_manager.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/widgets/language_list_v2.dart';
import 'package:snabbit_runner/widgets/overlay_permission_dialog.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import '../../services/globals.dart';
import '../../utils/common_methods.dart';
import '../../providers/user_profile.dart';
import '../../utils/app_strings.dart';
import '../../widgets/location_permission_confirmation.dart';
import '../../widgets/notification_permission_service.dart';
import '../../widgets/update_required_popup.dart';

class SelectLanguageV2 extends StatefulWidget {
  static const String routeName = "/select_language_v2";

  const SelectLanguageV2({super.key});

  @override
  State<SelectLanguageV2> createState() => _SelectLanguageV2State();
}

class _SelectLanguageV2State extends State<SelectLanguageV2> {
  String? error;
  bool loading = true;
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;
  UserProfile? userProfile;
  Trace? _screenTrace;

  static bool _drainedThisLaunch = false;

  @override
  void initState() {
    super.initState();
    if (!_drainedThisLaunch) {
      _drainedThisLaunch = true;
      unawaited(ReferralAttributionService.validateCapturedLink());
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;

      // Start screen trace (Firebase should be initialized by now)

      _screenTrace =
          FirebasePerformance.instance.newTrace('screen_select_language_v2');
      _screenTrace?.start();

      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);

      initProcess().then((_) {
        // loading = false;
        if (mounted) {
          setState(() {});

          // Measure first frame render
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _screenTrace?.stop();
            debugPrint(
                '⏱️ [PERFORMANCE] SelectLanguageV2 screen trace completed');
          });
        }
        showUpdateRequiredPopup();
        showLocationPermissionConfirmation();
        showNotificationPermissionConfirmation();
      }).onError((e, stackTrace) {
        loading = false;
        error = e.toString();
        if (mounted) {
          setState(() {});
        }

        _screenTrace?.stop();

        showUpdateRequiredPopup();
        showLocationPermissionConfirmation();
        showNotificationPermissionConfirmation();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    // Track initProcess (Firebase should be initialized by now)
    Trace? initProcessTrace;
    Trace? runnersMeTrace;

    initProcessTrace =
        FirebasePerformance.instance.newTrace('select_language_init_process');
    initProcessTrace.start();

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? accessToken = await SecureStorageUtils.getAccessToken(
        "SELECT_LANGUAGE_V2_INIT_PROCESS_METHOD");

    if (accessToken != null) {
      // Track API call

      runnersMeTrace =
          FirebasePerformance.instance.newTrace('select_language_runners_me');
      runnersMeTrace.start();

      Response? response = await RunnerHttp.runnersMe();

      runnersMeTrace.stop();

      referralDataProvider.getReferralDetails();
      showRefereeBottomSheet();
      if (response == null || response.statusCode != 200) {
        // mqtt_config cohort: route to the native KMP stack even offline / on a
        // server error — it renders the last-known state from the on-device DB
        // (+ the offline banner) instead of the "no internet" screen. Keep the
        // spinner up under the hand-off (like the online navigate path). Fail-open:
        // fall through to the error screen if we're not the cohort or KMP can't open.
        if (mounted) {
          final poller =
              Provider.of<RunnerRtDataProvider>(context, listen: false);
          if (await RegistrationNavigation.openKMPStackForOfflineCohort(
              poller)) {
            return; // KMP is the surface — leave the spinner beneath it
          }
        }
        if (!mounted) return;
        setState(() {
          loading = false;
          error = response != null
              ? response.data.toString()
              : GlobalState().appError.value.description;
        });
      } else {
        error = null;
        try {
          userProfile = UserProfile.fromMap(response.data);
        } catch (e) {
          loading = false;
          error = e.toString();
        }
        userProfileProvider.user = userProfile;
        // Remember cohort membership so an offline cold-start can still route to
        // KMP (MqttCohortCache → openKMPStackForOfflineCohort). mqtt_config only
        // arrives in this online runners/me and toMap() doesn't persist it.
        unawaited(MqttCohortCache.setCohort(userProfile?.mqttConfig != null));
        // Store runner_id in SharedPreferences for IoT background service
        if (userProfile != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', userProfile!.id.toString());
          } catch (_) {
            // Ignore SharedPreferences errors
          }
        }

        if (userProfile != null) {
          // Track monitoring service user data setup
          Trace? monitoringTrace;
          monitoringTrace = FirebasePerformance.instance
              .newTrace('select_language_monitoring_setup');
          monitoringTrace.start();

          await MonitoringServiceHelper.setUserDataAcrossServices(userProfile!);
          monitoringTrace.stop();

          MonitoringServiceHelper.logInfo(
            "Select language runnersMe call",
            {},
          );

          // Set user ID in Firebase Crashlytics for crash tracking
          try {
            await FirebaseCrashlytics.instance.setUserIdentifier(
              userProfile!.id.toString(),
            );
            AnalyticsService.instance.setUserId(userProfile!.id.toString());
          } catch (e) {
            MonitoringServiceHelper.logError(
                "failed to set user id in firebase crashlytics post login", {
              "error": e.toString(),
            });
          }
        }
        try {
          await ClevertapSetup.setCustomer({
            'Identity': userProfile?.id.toString(),
            'Phone': userProfile?.phoneNumber,
            'service_id': userProfile?.service?.id,
          });
          await prefs.setBool(AppStrings.cleverTapAccountExists, true);
        } catch (e) {
          MonitoringServiceHelper.logError("failed to set clever tap account", {
            "error": e.toString(),
          });
        }
        // Identify user in Mixpanel (independent of CleverTap)
        if (userProfile != null) {
          unawaited(OnboardingAnalytics.identifyOnLogin(userProfile!));
        }
        // Track language messages fetch
        Trace? languageFetchTrace;

        languageFetchTrace = FirebasePerformance.instance
            .newTrace('select_language_fetch_messages');
        languageFetchTrace.start();

        await languageProvider.fetchMessages(
            userProfileProvider.user?.languagePreference ??
                AppStrings.defaultLanguage);

        languageFetchTrace.stop();

        // Track Shorebird update check
        Trace? shorebirdTrace;

        shorebirdTrace = FirebasePerformance.instance
            .newTrace('select_language_shorebird_check');
        shorebirdTrace.start();

        ShorebirdManager.instance
            .checkForUpdatesWithRemoteConfig(bypassDebounce: false);

        shorebirdTrace.stop();

        final SelectLanguageInitProvider selectLanguageInitProvider =
            Provider.of<SelectLanguageInitProvider>(context, listen: false);

        if (userProfile != null) {
          selectLanguageInitProvider.initializeServices(userProfile!);
        }

        // Cohort-only: grant the runtime permissions the interim PartnerHome no
        // longer prompts for (it renders a headless loader for the mqtt_config
        // cohort) BEFORE navigateAfterRunnersMe hands off to the native KMP home
        // below. Awaited so each prompt resolves on this screen, not over KMP.
        if (mounted && userProfile?.mqttConfig != null) {
          // Never let a permission failure strand the cohort: navigation must
          // still proceed to KMP below even if a prompt throws unexpectedly.
          try {
            await _requestCohortPrePermissions();
          } catch (e) {
            MonitoringServiceHelper.logError(
              "cohort pre-KMP permissions aborted",
              {"error": e.toString()},
            );
          }
        }

        if (mounted) {
          // Keep the loading spinner up across the navigation. Whenever
          // navigateAfterRunnersMe routes away from this screen — replacing the
          // root stack (ACTIVE/SUSPENDED/FAILED) or pushing a back-blocked page
          // over it (onboarding hub / training webview / TrainingSlots) —
          // dropping `loading` first would flash this screen's content during
          // the transition. Only clear it when we stay on this screen.
          final navigatedAway =
              await RegistrationNavigation.navigateAfterRunnersMe(context);
          if (!navigatedAway && mounted) {
            setState(() {
              loading = false;
            });
          }
        }
      }
    } else {
      loading = false;
      error = AppStrings.authTokenNotFound;
      _redirectToLoginScreen();
    }

    try {
      await initProcessTrace.stop();
    } catch (_) {}
  }

  /// Cohort-only: request the runtime permissions the interim [PartnerHome] no
  /// longer prompts for. The mqtt_config cohort is routed straight to the native
  /// KMP home by [RegistrationNavigation.navigateAfterRunnersMe], and its interim
  /// PartnerHome renders a headless loader (it never shows the home UI) — so the
  /// battery-optimisation, microphone and over-other-apps (overlay) permissions
  /// PartnerHome owned must be requested HERE, before that hand-off, or the cohort
  /// never sees them. Awaited so the prompts resolve on this screen, not over KMP.
  /// No-op for the polling cohort — Flutter PartnerHome still owns these there.
  Future<void> _requestCohortPrePermissions() async {
    // The IoT foreground service is gated on microphone, and battery-opt keeps it
    // alive across Doze — both are native one-tap prompts.
    try {
      await Permission.ignoreBatteryOptimizations.request();
      await Permission.microphone.request();
    } catch (e) {
      MonitoringServiceHelper.logError(
        "cohort pre-KMP permission request failed",
        {"error": e.toString()},
      );
    }

    // Overlay (SYSTEM_ALERT_WINDOW) is a system-settings round-trip, so only
    // prompt when an overlay surface is actually enabled for the cohort — the KMP
    // AWOL-v2 over-other-apps alert or the new-job overlay. KMP only CHECKS this
    // permission; nothing on the native side requests it.
    if (!mounted) return;
    final overlayProvider =
        Provider.of<OverlayProvider>(context, listen: false);
    final needsOverlay = overlayProvider.isAwolV2OverlayEnabled ||
        RemoteConfigService.instance.getBool(
          RemoteConfigKeys.expertEnableNewJobOverlay,
          defaultValue: false,
        );
    if (!needsOverlay) return;
    try {
      await overlayProvider.refreshPermission();
      if (!mounted || overlayProvider.hasPermission) return;
      final isMandatory = RemoteConfigService.instance.getBool(
        RemoteConfigKeys.awolOverlayPermissionMandatory,
        defaultValue: false,
      );
      await showDialog(
        context: context,
        barrierDismissible: !isMandatory,
        builder: (_) => OverlayPermissionDialog(isDismissable: !isMandatory),
      );
    } catch (e) {
      MonitoringServiceHelper.logError(
        "cohort pre-KMP overlay permission failed",
        {"error": e.toString()},
      );
    }
  }

  void _redirectToLoginScreen() {
    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(SendOtp.routeName, (_) => false);
    }
    return;
  }

  @override
  void dispose() {
    try {
      _screenTrace?.stop();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      persistentFooterButtons: [
        if (!loading && error == null)
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: !loading && !userProfileProvider.loading
                  ? () async {
                      final selectedLang =
                          userProfileProvider.user?.languagePreference;
                      if (selectedLang != null) {
                        OnboardingAnalytics.registerSuperProperties(
                            {'selected_language': selectedLang});
                      }
                      OnboardingAnalytics.logEvent(
                          TrackingEvents.languageSelectionConfirmed, {
                        'selected_language': selectedLang,
                      });
                      setState(() {
                        loading = true;
                      });
                      await languageProvider.fetchMessages(
                          userProfileProvider.user?.languagePreference ??
                              AppStrings.defaultLanguage);
                      setState(() {
                        loading = false;
                      });
                      if (languageProvider.error != null) {
                        if (context.mounted) {
                          showSnackbar(
                            context,
                            "Saving language failed!",
                          );
                        }
                      } else {
                        if (context.mounted) {
                          await userProfileProvider
                              .runnerRegistrationAndErrorHandler(
                            context: context,
                            isFirstRoute: true,
                            onError: (errorMessage) {
                              error = errorMessage;
                            },
                          );
                        }
                      }
                    }
                  : null,
              child: const Text(
                "Confirm",
              ),
            ),
          ),
      ],
      body: loading || userProfileProvider.loading
          ? Padding(
              padding: EdgeInsets.all(16.r),
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
            )
          : error != null
              ? Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          error ?? "Something went wrong",
                        ),
                        SizedBox(height: 32.h),
                        SizedBox(
                          width: 1.sw,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (error == AppStrings.authTokenNotFound) {
                                _redirectToLoginScreen();
                              } else {
                                setState(() {
                                  loading = true;
                                });
                                try {
                                  await GlobalState().setAppConfig();
                                  await initProcess();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                  showUpdateRequiredPopup();
                                } catch (e) {
                                  loading = false;
                                  error = e.toString();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                  showUpdateRequiredPopup();
                                }
                              }
                            },
                            child: Text(
                                languageProvider.getMessage('retry', 'Retry')),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        children: [
                          // Todo: Get the image from the server
                          RemoteImageHandler(
                            imageUrl: "onboarding/language_banner.png".cdn,
                            fit: BoxFit.fitWidth,
                            width: 1.sw,
                          ),
                          // Todo: Check the message key
                          Padding(
                            padding: EdgeInsets.only(
                                left: 30.w, top: 32.h, right: 91.w),
                            child: Text(
                              languageProvider.getMessage(
                                  'select_language_banner_text',
                                  "New beginnings, new opportunities - your progress is in your hands!"),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                            ),
                          )
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 40.h),
                              Text(
                                languageProvider.getMessage(
                                    'select_a_language_to_continue',
                                    'Select a language to continue'),
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                              SizedBox(height: 24.h),
                              const Expanded(
                                child: LanguageListV2(),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}
