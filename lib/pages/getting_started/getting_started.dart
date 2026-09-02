import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/getting_started/debug_menu.dart';
import 'package:snabbit_runner/pages/getting_started/learn_more.dart';
import 'package:snabbit_runner/pages/login/send_otp.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/network_channel.dart';
import 'package:snabbit_runner/services/realtime/realtime_channel.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/security/root_detection_service.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/config/frontend_preview.dart';

import '../../widgets/location_permission_confirmation.dart';
import '../../widgets/notification_permission_service.dart';
import '../../widgets/update_required_popup.dart';

class GettingStarted extends StatefulWidget {
  static const String routeName = "/getting_started";

  const GettingStarted({super.key});

  @override
  State<GettingStarted> createState() => _GettingStartedState();
}

class _GettingStartedState extends State<GettingStarted> {
  bool screenLoading = true;
  Trace? _screenTrace;

  @override
  void initState() {
    super.initState();

    // Start screen trace (Firebase should be initialized by now)
    Trace? initProcessTrace;
    try {
      _screenTrace =
          FirebasePerformance.instance.newTrace('screen_getting_started');
      _screenTrace?.start();
    } catch (_) {}

    try {
      initProcessTrace =
          FirebasePerformance.instance.newTrace('getting_started_init_process');
      initProcessTrace.start();
    } catch (_) {}

    initProcess().then((_) async {
      try {
        initProcessTrace?.stop();
      } catch (_) {}

      screenLoading = false;
      if (mounted) {
        setState(() {});

        // Measure first frame render
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            _screenTrace?.stop();
            debugPrint(
                '⏱️ [PERFORMANCE] GettingStarted screen trace completed');
          } catch (_) {}
        });
      }
      if (!FrontendPreview.enabled) {
        showUpdateRequiredPopup();
        showLocationPermissionConfirmation();
        showNotificationPermissionConfirmation();
      }
      _checkAndShowEnvironmentChangeToast();
    }).catchError((Object e, StackTrace st) {
      // Defence-in-depth: no init failure may leave the screen stuck on the
      // loading spinner (black screen). Whatever threw, drop the spinner so
      // the user still reaches the getting-started content.
      MonitoringServiceHelper.reportError(
        'GETTING_STARTED_INIT_FAILED',
        {'error': e.toString()},
        st.toString(),
      );
      if (mounted) {
        setState(() {
          screenLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      _screenTrace?.stop();
    } catch (_) {}
    super.dispose();
  }

  // Future<void> _compulsoryLocationPermission(
  //   BuildContext context,
  // ) async {
  //   if (await Permission.locationAlways.isGranted == false) {
  //     try {
  //       if (mounted) {
  //         showLocationPermissionConfirmation();
  //       }
  //     } catch (e) {
  //       // DO NOTHING
  //     }
  //   }
  // }

  Future<void> initProcess() async {
    if (FrontendPreview.enabled) return;

    RootDetectionService.performRootCheck();
    SecureStorageUtils.clearToken();
    // Wipe the KMP-side token in lockstep with the Dart side. Awaited
    // so the subsequent shield-queue + refreshToken flow can't race
    // against KMP holding the stale value.
    //
    // Guarded: KMP surfaces disk-write failures as a `PERSIST_FAILED`
    // PlatformException (e.g. Tink/DataStore keyset unreadable on a
    // backup-restored install). The Dart-side token is already cleared
    // above, so a failed KMP clear degrades to a stale-token race at worst
    // — it must NOT propagate out of initProcess() and wedge the loading
    // spinner on a black screen.
    try {
      await NetworkChannel.clearToken();
    } catch (e) {
      MonitoringServiceHelper.logError('KMP_CLEAR_TOKEN_FAILED', {
        'error': e.toString(),
        'flow': 'getting_started_init',
      });
    }
    HttpService().invalidateTokenCache();
    await SecureStorageUtils.clearToken();
    // WS5: tear down the MQTT realtime engine + drop its persisted config in
    // lockstep with the token wipe (unconditional/idempotent — a polling-cohort
    // session is a no-op). Prevents a stale FGS + config leaking across users.
    await RealtimeChannel.stop();
    await RealtimeChannel.clearConfig();
    // Reset RT data so PartnerHome shows a loading spinner instead of stale content on re-login.
    if (mounted) {
      try {
        Provider.of<RunnerRtDataProvider>(context, listen: false)
            .resetForNewSession();
      } catch (_) {}
    }
    // Clear shield upload queue to prevent cross-user data leakage.
    GlobalState().shieldUploadQueue?.stop();
    await GlobalState().shieldUploadQueue?.clearAll();
    GlobalState().shieldUploadQueue = null;
    await refreshToken();
  }

  Future<void> refreshToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      await messaging.deleteToken();
    } catch (e) {
      debugPrint("Token not available to delete. First login - no issues.");
    }
  }

  Future<void> _checkAndShowEnvironmentChangeToast() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool envChanged = prefs.getBool('debug_env_changed') ?? false;

      if (envChanged && mounted) {
        // Clear the flag
        await prefs.remove('debug_env_changed');

        // Show toast
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Environment changed successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking environment change flag: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return screenLoading
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : Scaffold(
            backgroundColor: AppColors.brand,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 84.h,
                    ),
                    Expanded(
                      flex: 163,
                      child: Image.asset(
                        AssetConstants.snabbitExpertEntry,
                        fit: BoxFit.contain,
                      ),
                    ),

                    SizedBox(height: 9.h), // Spacing

                    // Image
                    Expanded(
                      flex: 375,
                      child: FrontendPreview.enabled
                          ? Image.asset(
                              AssetConstants.people,
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              'https://snabbit-assets.s3.ap-south-1.amazonaws.com/snabbit_expert_people.png',
                              errorBuilder: (_, __, ___) => Image.asset(
                                AssetConstants.people,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Debug Menu Button (only in debug mode)
                        if (kDebugMode) ...[
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, DebugMenu.routeName);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              side: BorderSide(
                                  color: AppColors.n0.withOpacity(0.5)),
                            ),
                            child: Text(
                              AppStrings.debugMenu,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: AppColors.n0.withOpacity(0.8)),
                            ),
                          ),
                          SizedBox(height: 16.h),
                        ],

                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, SendOtp.routeName);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.n0,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: Text(
                            AppStrings.getStarted,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),

                        SizedBox(height: 16.h), // Spacing

                        // Learn More Button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, LearnMore.routeName);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: Text(
                            AppStrings.learnMoreAboutSnabbit,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.n0),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}
