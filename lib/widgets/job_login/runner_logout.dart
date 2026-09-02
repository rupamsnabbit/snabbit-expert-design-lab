import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/attendance_flow/vishwaas_provisional_rate_card_sheet.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/banner_with_media.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/assets_constants.dart';
import '../../utils/colors.dart';
import '../attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';

class RunnerLogout extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const RunnerLogout({
    super.key,
    this.widgetData,
  });

  @override
  State<RunnerLogout> createState() => _RunnerLogoutState();
}

class _RunnerLogoutState extends State<RunnerLogout> {
  bool init = true;

  bool loading = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init = false;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: true);
    initProcess().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  int get _delayTime => RemoteConfigService.instance.getNonZeroInt(
    RemoteConfigKeys.expertProvisionalAttendanceBottomsheetCloseTime,
    defaultValue: 5,
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
        builder: (context, runnerRtDataProvider, child) {
      return widget.widgetData == null
          ? Container()
          : runnerRtDataProvider.waitForFetchData
              ? const CupertinoActivityIndicator()
              : Column(
                  children: [
                    if (widget.widgetData?['logout_pending_warning'] == true)
                      Padding(
                        padding: EdgeInsets.only(bottom: 24.h),
                        child: AmountBanner(
                          prefixIconSize: 90.w,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                languageProvider.getMessage(
                                  'logout_now',
                                  'Logout Now',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: const Color(0xff623D09),
                                        fontSize: 16.sp),
                              ),
                              Text(
                                languageProvider.getMessage(
                                  'dont_lose_ming',
                                  'Don\'t Lose MinG',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: const Color(0xff623D09),
                                        fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          image: AssetConstants.attendancePendingAmber,
                          valueBoxSize: 0,
                        ),
                      ),
                    if (widget.widgetData?['is_outside_logout_area'] == true)
                      Container(
                        width: 1.sw,
                        height: 48.h,
                        margin: EdgeInsets.only(bottom: 16.h),
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF4F4),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              AssetConstants.fpWarningPng,
                              // color: const Color(0xFFD14343),
                              height: 24.h,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              languageProvider.getMessage(
                                'away_from_hotspot',
                                'You are away from the hotspot',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      fontSize: 16.sp, color: AppColors.r50),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      "${widget.widgetData?["date"] ?? ""}",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(
                      height: 4.h,
                    ),
                    Text(
                      languageProvider.getMessage(
                        'shift_end_time',
                        'Shift end time',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                              fontSize: 28.sp, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      "${widget.widgetData?["shift_end_time"] ?? ""}",
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                              fontSize: 28.sp, fontWeight: FontWeight.w800),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Divider(
                        color: AppColors.n30,
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.n90,
                        ),
                        onPressed: () async {
                                    // final service = FlutterBackgroundService();
                                    // service.invoke("stopService");
                                    // final prefs = await SharedPreferences.getInstance();
                                    // await prefs.setBool(
                                    //     AppStrings.isBGLocationServiceEnabled, false);
                                    Response? response =
                                        await JobHttp.runnerLogout();
                                    if (response != null &&
                                        response.statusCode == 200) {
                                      await PostActionOverlayController.instance
                                          .showFromResponse(
                                              response.data, LifecycleActionType.earlyLogout);
                                      // success
                                      if (context.mounted) {
                                        showModalBottomSheet(
                                          context: context,
                                          isDismissible: false,
                                          enableDrag: false,
                                          builder: (_) {
                                            return PopScope(
                                              canPop: false, // Prevents back button from closing
                                              onPopInvokedWithResult: (didPop, result) {
                                                if (didPop) return;
                                              },
                                              child: CommonBottomSheetSetup(
                                                child: Column(
                                                  children: [
                                                    SizedBox(height: 40.h),
                                                    Container(
                                                      width: 48.r,
                                                      height: 48.r,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: AppColors.g40,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding:
                                                          EdgeInsets.all(10.r),
                                                      child: FittedBox(
                                                        child: Icon(
                                                          Icons.check,
                                                          color: AppColors.n0,
                                                          size: 50.sp,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 24.h),
                                                    Text(
                                                      languageProvider.getMessage(
                                                        'thank_you',
                                                        'Thank You!',
                                                      ),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headlineMedium,
                                                    ),
                                                    SizedBox(height: 8.h),
                                                    Text(
                                                      languageProvider.getMessage(
                                                        'logged_out_successfully',
                                                        'You have been logged out successfully!',
                                                      ),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelLarge
                                                          ?.copyWith(
                                                            color: AppColors.n80,
                                                            fontSize: 16.sp,
                                                          ),
                                                    ),
                                                    if (widget.widgetData?[
                                                                'show_yulu_service_request'] ==
                                                            true &&
                                                        userProfileProvider.user
                                                                ?.alternateDeliveryMethod ==
                                                            AlternateDeliveryMethod
                                                                .yulu)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                          16.w,
                                                          26.h,
                                                          16.w,
                                                          16.h,
                                                        ),
                                                        child: GestureDetector(
                                                          onTap: () async {
                                                            if (widget.widgetData?[
                                                                    "yulu_service_cta"] !=
                                                                null) {
                                                              try {
                                                                launchUrl(Uri.parse(
                                                                    widget.widgetData?[
                                                                        'yulu_service_cta']));
                                                              } catch (_) {}
                                                            }
                                                          },
                                                          child: BannerWithMedia(
                                                            message:
                                                                languageProvider
                                                                    .getMessage(
                                                              "ensure_yulu_service",
                                                              "Please ensure bike brakes are serviced",
                                                            ),
                                                            foregroundImage:
                                                                AssetConstants
                                                                    .yuluBike,
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFFE8F7FF),
                                                            cta: widget.widgetData?[
                                                                        "yulu_service_cta"] !=
                                                                    null
                                                                ? ConstrainedBox(
                                                                    constraints:
                                                                        BoxConstraints(
                                                                      maxHeight:
                                                                          24.h,
                                                                    ),
                                                                    child:
                                                                        ElevatedButton(
                                                                      onPressed:
                                                                          () {},
                                                                      style: ElevatedButton.styleFrom(
                                                                          padding: EdgeInsets.symmetric(
                                                                            vertical:
                                                                                6.05.r,
                                                                            horizontal:
                                                                                7.81.r,
                                                                          ),
                                                                          backgroundColor: const Color(0xff29C9EC),
                                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.4.r))),
                                                                      child:
                                                                          FittedBox(
                                                                        child:
                                                                            Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Image
                                                                                .asset(
                                                                              AssetConstants.locate,
                                                                              height:
                                                                                  10.r,
                                                                            ),
                                                                            SizedBox(
                                                                              width:
                                                                                  4.w,
                                                                            ),
                                                                            Text(
                                                                              languageProvider.getMessage("locate_centre",
                                                                                  "Locate service centre"),
                                                                              softWrap:
                                                                                  true,
                                                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                                                    color: AppColors.n0,
                                                                                  ),
                                                                            )
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  )
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    SizedBox(height: 32.h),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                        await Future.delayed( Duration(
                                                seconds: _delayTime))
                                            .then((_) {
                                          runnerRtDataProvider.fetchDataNow();
                                        });
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                        // After the thank-you sheet
                                        // auto-dismisses, chain the
                                        // Vishwaas rate-card promotion
                                        // sheet for v1 runners. Same
                                        // gate as the drawer banner —
                                        // RC flag + hasLowerEarnings
                                        // InNewRateCard + v1, plus the
                                        // function's own one-time-per-
                                        // install prefs guard.
                                        if (context.mounted &&
                                            userProfileProvider
                                                .showVishwaasBanner) {
                                          showVishwaasProvisionalRateCardIfNeeded(
                                              context);
                                        }
                                      }
                                    } else {
                                      if (context.mounted) {
                                        showSnackbar(
                                          context,
                                          "${response?.data ?? "Something went wrong. Please try again!"}",
                                        );
                                      }
                                    }
                                    await runnerRtDataProvider.fetchDataNow();
                                    await ClevertapSetup.logEvent(
                                        TrackingEvents
                                            .runnerLogoutButtonClicked,
                                        {
                                          "action":
                                              "runner logout button clicked",
                                        });
                                  },
                        child: Text(
                          languageProvider.getMessage(
                            "logout",
                            "Logout",
                          ),
                        ),
                      ),
                    ),
                  ],
                );
    });
  }
}
