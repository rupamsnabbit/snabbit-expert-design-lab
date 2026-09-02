import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/auto_ot_orchestrator.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/attendance_flow/early_logout_view.dart';
import 'package:snabbit_runner/widgets/attendance_flow/provisional_attendance_carousel.dart';
import 'package:snabbit_runner/widgets/attendance_flow/sunday_attendance_nudge.dart';
import 'package:snabbit_runner/widgets/attendance_flow/support_team_list.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:snabbit_runner/widgets/attendance_reason_dialog.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_add_details_banner.dart';
import 'package:snabbit_runner/widgets/elevated_button_with_loader.dart';
import 'package:snabbit_runner/widgets/payout/add_bank_banner.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

import '../../utils/colors.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'earning_loss_bottom_sheet.dart';

import 'take_care_sheet.dart';

class ProvisionalAttendance extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const ProvisionalAttendance({
    super.key,
    this.widgetData,
  });

  @override
  State<ProvisionalAttendance> createState() => _ProvisionalAttendanceState();
}

class _ProvisionalAttendanceState extends State<ProvisionalAttendance> {
  bool init = true;

  bool loading = true;

  int _currentCarouselIndex = 0;

  late LanguageProvider languageProvider;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
        builder: (context, runnerRtDataProvider, child) {
      return widget.widgetData == null
          ? Container()
          : runnerRtDataProvider.waitForFetchData
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
                  children: [
                    if (widget.widgetData!["early_logout"] == true)
                      EarlyLogoutView(),
                    Text(
                      "${widget.widgetData!["date"] ?? ""}",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(
                      height: 4.h,
                    ),
                    Text(
                      "${widget.widgetData!["shift_time"] ?? ""}",
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
                    Text(
                      widget.widgetData!["next_shift_tomorrow"] == true
                          ? languageProvider.getMessage(
                              "are_you_coming_tomorrow",
                              "Are you coming tomorrow?")
                          : languageProvider.getFormattedMessage(
                              "are_you_coming_x_day",
                              "Are you coming on {{x_day}}?",
                              {"x_day": widget.widgetData!["date"] ?? ""}),
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButtonWithLoader(
                        text: languageProvider.getMessage(
                            "yes_i_am_coming", "Yes, I am coming"),
                        bgColor: AppColors.g40,
                        onPressed: () async =>
                            _markPresent(runnerRtDataProvider),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButtonWithLoader(
                        text: languageProvider.getMessage(
                            "no_i_am_not_coming", "No, I am not coming"),
                        bgColor: AppColors.r40,
                        onPressed: () async {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (modalContext) {
                              return EarningLossBottomSheet(
                                earningLossAmount: widget
                                        .widgetData!['earning_loss_amount']
                                        ?.toString() ??
                                    '',
                                onMarkAbsent: () {
                                  if (widget.widgetData?[
                                          "is_next_working_day_sunday"] ==
                                      true) {
                                    Navigator.pop(modalContext);
                                    showSundayAttendanceNudgeBottomSheet(
                                      context: context,
                                      onKeepSundayAsLeaveTap: () =>
                                          _markAbsent(runnerRtDataProvider),
                                      onWorkTomorrowTap: () {
                                        Navigator.pop(context);
                                        _markPresent(runnerRtDataProvider);
                                      },
                                    );
                                  } else {
                                    _markAbsent(runnerRtDataProvider);
                                  }
                                },
                                onMarkPresent: () {
                                  Navigator.pop(modalContext);
                                  _markPresent(runnerRtDataProvider);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    ProvisionalAttendanceCarousel(
                      widgetData: widget.widgetData,
                    ),
                    if (widget.widgetData?["customer_support"] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 24.h),
                        child: SupportTeamList(
                          membersJson:
                              widget.widgetData?["customer_support"] ?? [],
                        ),
                      ),
                  ],
                );
    });
  }

  void _markAbsent(
    RunnerRtDataProvider runnerRtDataProvider, {
    bool usePeriodLeave = false,
  }) async {
    Navigator.of(context).pop();
    // Wait for the pop animation to complete so the Navigator is unlocked.
    await Future.delayed(const Duration(milliseconds: 300));
    if (context.mounted) {
      String? selectedReason;
      if (!usePeriodLeave) {
        selectedReason = await showDialog(
          context: context,
          builder: (BuildContext context) => const AttendanceReasonDialog(),
        );
        if (selectedReason == null) {
          runnerRtDataProvider.fetchDataNow();
          return;
        }
      }

      runnerRtDataProvider.setWaitForFetchData(true);
      Response? response = await JobHttp.markAttendance(data: {
        "mark": false,
        if (selectedReason != null) "absentism_reason": selectedReason,
        if (usePeriodLeave) "use_period_leave": true,
      });
      if (response != null && response.statusCode == 200) {
        if (usePeriodLeave && context.mounted) {
          await TakeCareSheet.show(context, source: 'false_attendance');
        }
        await PostActionOverlayController.instance.showFromResponse(
            response.data, LifecycleActionType.falseAttendance);
        if (usePeriodLeave) {
          await runnerRtDataProvider.refreshPeriodLeaveAvailability();
        }
        await ClevertapSetup.logEvent(
          TrackingEvents.attendanceMarked,
          {
            "runner_attendance": "attendance marked",
            "marked": false,
            "type": "provisional",
            if (usePeriodLeave) "period_leave": true,
          },
        );
      } else {
        if (context.mounted) {
          showSnackbar(
            context,
            "${response?.data ?? "Something went wrong. Please try again!"}",
          );
        }
      }
    }

    runnerRtDataProvider.fetchDataNow();
  }

  void _markPresent(RunnerRtDataProvider runnerRtDataProvider) async {
    Response? response = await JobHttp.markAttendance(data: {"mark": true});
    Logger().i(
        "Response status code: ${response?.statusCode}\nFor Mark your attendance YES for tomorrow\n msg is ${response?.data}||${response?.statusMessage}");
    if (response != null && response.statusCode == 200) {
      await PostActionOverlayController.instance
          .showFromResponse(response.data, LifecycleActionType.falseAttendance);
      await AutoOtOrchestrator.onAttendanceMarked();
      await ClevertapSetup.logEvent(TrackingEvents.attendanceMarked, {
        "runner_attendance": "attendance marked",
        "marked": true,
        "type": "provisional"
      });
    } else {
      if (context.mounted) {
        showSnackbar(
          context,
          "${response?.data ?? "Something went wrong. Please try again!"}",
        );
      }
    }
    await runnerRtDataProvider.fetchDataNow();
  }
}
