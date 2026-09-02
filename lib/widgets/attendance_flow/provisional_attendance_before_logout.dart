import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/provisional_attendance_before_logout_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/widgets/attendance_flow/provisional_attendance_carousel.dart';
import 'package:snabbit_runner/widgets/attendance_flow/sunday_attendance_nudge.dart';
import 'package:snabbit_runner/widgets/attendance_flow/support_team_list.dart';
import 'package:snabbit_runner/widgets/attendance_flow/vishwaas_provisional_rate_card_sheet.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'early_logout_view.dart';

class ProvisionalAttendanceBeforeLogout extends StatelessWidget {
  final Map<String, dynamic>? widgetData;

  const ProvisionalAttendanceBeforeLogout({
    super.key,
    this.widgetData,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
      builder: (context, runnerRtDataProvider, _) {
        if (widgetData == null) return SizedBox.shrink();

        if (runnerRtDataProvider.waitForFetchData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        return ProvisionalAttendanceBeforeLogoutView(
          widgetData: widgetData!,
        );
      },
    );
  }
}

class ProvisionalAttendanceBeforeLogoutView extends StatelessWidget {
  final Map<String, dynamic> widgetData;

  const ProvisionalAttendanceBeforeLogoutView({
    super.key,
    required this.widgetData,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Consumer2<LanguageProvider,
        ProvisionalAttendanceBeforeLogoutProvider>(
      builder: (context, languageProvider,
          provisionalAttendanceBeforeLogoutProvider, _) {
        final date = widgetData["date"]?.toString() ?? "";
        final shiftEndTime = provisionalAttendanceBeforeLogoutProvider
            .extractShiftEndTime(widgetData["shift_time"]?.toString() ?? "");
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widgetData["early_logout"] == true) EarlyLogoutView(),
              SizedBox(
                width: 288.w,
                height: 55.h,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date,
                      style: textTheme.bodyLarge?.copyWith(
                        letterSpacing: -0.24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      languageProvider.getFormattedMessage(
                          "shift_end_time_x",
                          "Shift End time {{shift_end_time}}",
                          {'shift_end_time': shiftEndTime}),
                      style: textTheme.displayLarge?.copyWith(
                        letterSpacing: -1,
                        color: AppColors.n90,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Divider(
                height: 1.h,
                color: AppColors.n30,
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: 320.w,
                height: 52.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.n90,
                    foregroundColor: AppColors.n0,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () {
                    MixpanelSetup.logEvent(
                      'attendance_before_logout_bottom_sheet_opened',
                      provisionalAttendanceBeforeLogoutProvider
                          .attendanceBeforeLogoutMixpanelProps(widgetData),
                    );
                    showProvisionalAttendanceBeforeLogoutBottomSheet(
                      context: context,
                      widgetData: widgetData,
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      languageProvider.getMessage("mark_attendance_and_logout",
                          "Mark attendance and Logout"),
                      style: textTheme.labelLarge?.copyWith(
                        letterSpacing: -0.24,
                        color: AppColors.n0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              ProvisionalAttendanceCarousel(
                widgetData: widgetData,
              ),
              if (widgetData["customer_support"] != null)
                Padding(
                  padding: EdgeInsets.only(top: 24.h),
                  child: SupportTeamList(
                    membersJson: widgetData["customer_support"] ?? [],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showProvisionalAttendanceBeforeLogoutBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> widgetData,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: AppColors.n0,
    enableDrag: false,
    builder: (_) {
      return ProvisionalAttendanceBeforeLogoutBottomSheet(
        widgetData: widgetData,
      );
    },
  ).then((_) {
    if (context.mounted) {
      MixpanelSetup.logEvent(
        'attendance_before_logout_bottom_sheet_closed',
        context
            .read<ProvisionalAttendanceBeforeLogoutProvider>()
            .attendanceBeforeLogoutMixpanelProps(widgetData),
      );
      context.read<ProvisionalAttendanceBeforeLogoutProvider>().reset();
      context.read<RunnerRtDataProvider>().fetchDataNow();
    }

    // Vishwaas chain uses the app-level navigator context — the local
    // `context` may already be unmounted because marking attendance
    // rebuilds the home page and removes ProvisionalAttendanceBeforeLogout
    // from the tree. The global key is rooted on MaterialApp and survives.
    final globalContext = GlobalState().navigatorKey.currentContext;
    if (globalContext != null &&
        // ignore: use_build_context_synchronously
        globalContext.read<UserProfileProvider>().showVishwaasBanner) {
      // ignore: use_build_context_synchronously
      showVishwaasProvisionalRateCardIfNeeded(globalContext);
    }
  });
}

class ProvisionalAttendanceBeforeLogoutBottomSheet extends StatefulWidget {
  final Map<String, dynamic> widgetData;

  const ProvisionalAttendanceBeforeLogoutBottomSheet({
    super.key,
    required this.widgetData,
  });

  @override
  State<ProvisionalAttendanceBeforeLogoutBottomSheet> createState() =>
      _ProvisionalAttendanceBeforeLogoutBottomSheetState();
}

class _ProvisionalAttendanceBeforeLogoutBottomSheetState
    extends State<ProvisionalAttendanceBeforeLogoutBottomSheet> {
  bool init = true;
  late ProvisionalAttendanceBeforeLogoutProvider
      provisionalAttendanceBeforeLogoutProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late LanguageProvider languageProvider;

  static const Color _logoutTitleColor = Color(0xFFB45309);
  static const Color _lineColor = Color(0xFFD1D5DB);
  static const Color _timeColor = Color(0xFF111827);

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      provisionalAttendanceBeforeLogoutProvider =
          Provider.of<ProvisionalAttendanceBeforeLogoutProvider>(context,
              listen: true);
    }
    super.didChangeDependencies();
  }

  bool get _enableSundayAttendanceNudge =>
      widget.widgetData["is_next_working_day_sunday"] == true &&
      RemoteConfigService.instance.getBool(
        RemoteConfigKeys.expertEnableSundayAttendanceNudge,
        defaultValue: true,
      );

  void _markPresent() {
    provisionalAttendanceBeforeLogoutProvider.markPresent(
        widgetData: widget.widgetData,
        onStart: () => runnerRtDataProvider.setWaitForFetchData(true),
        onApiSuccess: () =>
            runnerRtDataProvider.provisionalAttendanceOverride = 'present',
        onSuccess: () {
          if (!mounted) return;
          Navigator.of(context).pop();
        },
        onFailure: () {
          runnerRtDataProvider.setWaitForFetchData(false);
          if (!mounted) return;
          showSnackbar(
            context,
            "Something went wrong. Please try again!",
          );
        });
  }

  void _markAbsent() {
    provisionalAttendanceBeforeLogoutProvider.markAbsent(
        widgetData: widget.widgetData,
        onStart: () => runnerRtDataProvider.setWaitForFetchData(true),
        onApiSuccess: () =>
            runnerRtDataProvider.provisionalAttendanceOverride = 'absent',
        onSuccess: () {
          if (!mounted) return;
          Navigator.of(context).pop();
        },
        onFailure: () {
          runnerRtDataProvider.setWaitForFetchData(false);
          if (!mounted) return;
          showSnackbar(
            context,
            "Something went wrong. Please try again!",
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.widgetData["tomorrow_date"]?.toString() ?? "";
    final shiftRange =
        widget.widgetData["tomorrow_shift_time"]?.toString() ?? "";
    final formattedShiftRange = provisionalAttendanceBeforeLogoutProvider
        .formatTimeRangeForDisplay(shiftRange);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: PopScope(
        canPop: false, // Prevents back button from closing
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Builder(
          builder: (context) {
            if (provisionalAttendanceBeforeLogoutProvider.state ==
                ProvisionalAttendanceBeforeLogoutSheetState.success) {
              final isV2 =
                  context.read<UserProfileProvider>().optedForNewRateCard;
              return CommonBottomSheetSetup(
                bottomPadding: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SuccessState(
                      title: languageProvider.getMessage(
                          'thank_you!', "Thank You!"),
                      subtitle: languageProvider.getMessage(
                          'you_have_been_logged_out_successfully',
                          "You have been logged out successfully!"),
                    ),
                    if (isV2) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ViewTodaysEarningsButton(
                          label: languageProvider.getMessage(
                            'view_todays_earnings',
                            "View Today's Earnings",
                          ),
                          onPressed: () =>
                              Navigator.of(context).popAndPushNamed(
                            AppWebViewPage.routeName,
                            arguments: WebViewArgs(
                              url: buildWebviewUrl(
                                WebviewRoutes.payoutsShiftEndSummary,
                              ),
                              title: "Today's Earnings",
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ],
                ),
              );
            } else if (provisionalAttendanceBeforeLogoutProvider.state ==
                ProvisionalAttendanceBeforeLogoutSheetState.denialBuffer) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ChangeAbsentConfirmation(
                  onPositiveAction: () {
                    if (_enableSundayAttendanceNudge) {
                      showSundayAttendanceNudgeBottomSheet(
                          context: context,
                          onKeepSundayAsLeaveTap: () {
                            _markAbsent();
                            Navigator.pop(context);
                          },
                          onWorkTomorrowTap: () {
                            _markPresent();
                            Navigator.pop(context);
                          });
                    } else {
                      _markAbsent();
                    }
                  },
                  onNegativeAction: () {
                    MixpanelSetup.logEvent(
                      'attendance_before_logout_no_confirm_cancel_clicked',
                      provisionalAttendanceBeforeLogoutProvider
                          .attendanceBeforeLogoutMixpanelProps(
                              widget.widgetData),
                    );
                    provisionalAttendanceBeforeLogoutProvider.setState(
                        ProvisionalAttendanceBeforeLogoutSheetState.initial);
                  },
                ),
              );
            }

            final isSubmitting =
                provisionalAttendanceBeforeLogoutProvider.isSubmitting;

            return CommonBottomSheetSetup(
              bottomPadding: 32.h,
              showDragHandle: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24.h,
                    width: 1.sw,
                  ),
                  Text(
                    languageProvider.getMessage("complete_this_step_to_logout",
                        "Complete this step to logout"),
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 16.sp,
                      color: _logoutTitleColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),
                  Divider(
                    height: 1.h,
                    indent: 10.w,
                    endIndent: 10.w,
                    color: _lineColor,
                  ),
                  SizedBox(height: 20.h),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        date,
                        style: textTheme.bodyLarge?.copyWith(
                          letterSpacing: -0.24,
                          color: _timeColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        formattedShiftRange,
                        style: textTheme.displayLarge?.copyWith(
                          letterSpacing: -1,
                          color: _timeColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Divider(
                    height: 1.h,
                    indent: 10.w,
                    endIndent: 10.w,
                    color: _lineColor,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    languageProvider.getMessage(
                        "are_you_coming_tomorrow?", "Are you coming tomorrow?"),
                    style: textTheme.headlineMedium?.copyWith(
                      letterSpacing: -0.24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  isSubmitting
                      ? const CupertinoActivityIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 52.h,
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.g40,
                                  foregroundColor: AppColors.n0,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                onPressed: isSubmitting ? null : _markPresent,
                                child: Text(
                                  languageProvider.getMessage(
                                      "yes_i_am_coming", "Yes, I am coming"),
                                  style: textTheme.labelLarge?.copyWith(
                                    letterSpacing: -0.24,
                                    color: AppColors.n0,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              height: 52.h,
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.r40,
                                  foregroundColor: AppColors.n0,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                onPressed: () {
                                  MixpanelSetup.logEvent(
                                    'attendance_before_logout_no_clicked',
                                    provisionalAttendanceBeforeLogoutProvider
                                        .attendanceBeforeLogoutMixpanelProps(
                                            widget.widgetData),
                                  );
                                  provisionalAttendanceBeforeLogoutProvider
                                      .setState(
                                          ProvisionalAttendanceBeforeLogoutSheetState
                                              .denialBuffer);
                                },
                                child: Text(
                                  languageProvider.getMessage(
                                      "no_i_am_not_coming",
                                      "No, I am not coming"),
                                  style: textTheme.labelLarge?.copyWith(
                                    letterSpacing: -0.24,
                                    color: AppColors.n0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  SizedBox(height: 12.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SuccessState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 40.h),
        Container(
          width: 48.r,
          height: 48.r,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.g40,
          ),
          child: Icon(
            Icons.check,
            color: AppColors.n0,
            size: 26.sp,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          title,
          style: textTheme.headlineMedium?.copyWith(
            letterSpacing: -0.24,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: textTheme.labelLarge?.copyWith(
            fontSize: 16.sp,
            letterSpacing: -0.24,
            color: AppColors.n80,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
