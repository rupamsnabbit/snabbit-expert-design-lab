import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_absent.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/widgets/attendance_flow/current_day_attendance.dart';
// import 'package:snabbit_runner/widgets/attendance_flow/attendance_absent.dart';
// import 'package:snabbit_runner/widgets/attendance_flow/current_day_attendance.dart';
import 'package:snabbit_runner/widgets/attendance_flow/provisional_attendance.dart';
import 'package:snabbit_runner/widgets/attendance_flow/provisional_attendance_before_logout.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/job_in_progress/rate_customer.dart';
import 'package:snabbit_runner/widgets/job_in_progress/runner_suspended.dart';
import 'package:snabbit_runner/widgets/job_in_progress/see_you_tomorrow.dart';
import 'package:snabbit_runner/widgets/job_login/runner_logout.dart';
// import 'package:snabbit_runner/widgets/job_login/runner_logout.dart';
import 'package:snabbit_runner/widgets/job_start_flow/job_accepted.dart';
import 'package:snabbit_runner/widgets/job_login/auto_login_bottom_action_button.dart';
import 'package:snabbit_runner/widgets/job_login/job_login.dart';
import 'package:snabbit_runner/widgets/job_login/auto_login_selfie_check.dart';
import 'package:snabbit_runner/widgets/job_in_progress/wait_for_job.dart';
import 'package:snabbit_runner/widgets/job_start_flow/pre_mark_arrival.dart';
import 'package:snabbit_runner/widgets/lunch_time/lunch_time_request.dart';
import 'package:snabbit_runner/widgets/runner_lunch_cooldown.dart';
import 'package:snabbit_runner/widgets/lunch_break_countdown/lunch_break_countdown.dart';

import '../providers/runner_rt_data.dart';
import '../utils/app_strings.dart';
import 'job_start_flow/new_job_assigned.dart';
import 'job_start_flow/new_job_assigned_v1.dart';

class WidgetUtil {
  Widget status;
  Widget mainWidget;
  Widget? bottomButton;
  bool showDrawer;
  Color bgColor;
  String mainMessage;

  WidgetUtil({
    required this.status,
    required this.mainWidget,
    this.bottomButton,
    this.bgColor = AppColors.brand,
    this.mainMessage = "",
    this.showDrawer = true,
  });
}

WidgetUtil getRunnerStateWidgetUtil(WidgetInfo? widgetInfo) {
  // String? widgetName = getWidgetNameFromData(data);
  // Map<String, dynamic>? widgetData = data?["widget_data"];
  switch (widgetInfo?.name) {
    case "RUNNER_ATTENDANCE_TOMORROW":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "We are waiting for your response",
        mainWidget: ProvisionalAttendance(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_ATTENDANCE_TODAY":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "Please confirm your attendance",
        mainWidget: CurrentDayAttendance(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_ATTENDANCE_ABSENT":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "You're marked absent.",
        mainWidget: AttendanceAbsent(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_ATTENDANCE_CONFIRMED":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "Mark your attendance",
        mainWidget: AttendanceConfirmed(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "PA_BEFORE_LOGOUT":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "Please confirm your next shift",
        mainWidget:
            ProvisionalAttendanceBeforeLogout(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_NEW_JOB":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: "online",
        ),
        bgColor: AppColors.g40,
        mainMessage: "You are logged in!",
        mainWidget: NewJobAssignedRouter(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_SEE_YOU_TOMORROW":
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are logged out!",
        mainWidget: const SeeYouTomorrow(),
      );
      return widgetUtil;
    case "RUNNER_SUSPENDED":
      WidgetUtil widgetUtil = WidgetUtil(
          status: Container(),
          bgColor: AppColors.brand,
          mainMessage: "You are suspended!",
          mainWidget: const RunnerSuspended(),
          showDrawer: false);
      return widgetUtil;
    case "RUNNER_JOB_CANCELLED":
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are logged in!",
        mainWidget: WaitForJob(
          widgetData: widgetInfo?.data,
          widgetName: "RUNNER_JOB_CANCELLED",
        ),
      );
      return widgetUtil;

    case "RUNNER_WAIT_HOTSPOT":
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are logged in!",
        mainWidget: WaitForJob(widgetData: widgetInfo?.data),
      );
      return widgetUtil;

    case "SELFIE_CHECK":
      WidgetUtil widgetUtil = WidgetUtil(
          status: Container(),
          bgColor: AppColors.brand,
          mainMessage: "Please take a selfie to continue",
          mainWidget: AutoLoginSelfieCheck(),
          bottomButton: null);
      return widgetUtil;
    case "RUNNER_LOGIN_LOCATION": //TODO temp for testing
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "We expect your presence on time",
        mainWidget: JobLogin(
          widgetData: widgetInfo?.data,
          widgetName: widgetInfo?.name,
        ),
      );
      return widgetUtil;
    case "RUNNER_LOGIN_HOTSPOT": //TODO temp for testing
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "We expect your presence on time",
        mainWidget: JobLogin(
          widgetData: widgetInfo?.data,
          widgetName: widgetInfo?.name,
        ),
        bottomButton: AutoLoginBottomActionButton(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case "RUNNER_JOB_IN_PROGRESS":
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are on the job!",
        mainWidget: OnTheJob(widgetData: widgetInfo?.data),
        bottomButton: null,
      );
      return widgetUtil;
    case "RUNNER_JOB_POST_ACCEPT":
      WidgetUtil widgetUtil = WidgetUtil(
          status: Container(),
          bgColor: AppColors.g40,
          mainMessage: "You are logged in!",
          mainWidget: JobAccepted(
            widgetData: widgetInfo?.data,
            widgetName: widgetInfo?.name,
          ),
          bottomButton: JobAcceptedBottomActionButton(
            bgColor: AppColors.g40,
            widgetName: widgetInfo?.name,
            widgetData: widgetInfo?.data,
          ));
      return widgetUtil;
    case "RUNNER_JOB_CHECK_IN":
      WidgetUtil widgetUtil = WidgetUtil(
          status: Container(),
          bgColor: AppColors.g40,
          mainMessage: "You are logged in!",
          mainWidget: JobAccepted(
            widgetData: widgetInfo?.data,
            widgetName: widgetInfo?.name,
          ),
          bottomButton: JobAcceptedBottomActionButton(
            bgColor: AppColors.g40,
            widgetName: widgetInfo?.name,
            widgetData: widgetInfo?.data,
          ));
      return widgetUtil;
    case "RUNNER_LOGOUT":
      WidgetUtil widgetUtil = WidgetUtil(
        status: const RunnerStatus(
          text: null,
        ),
        bgColor: AppColors.brand,
        mainMessage: "Your shift has ended",
        mainWidget: RunnerLogout(widgetData: widgetInfo?.data),
      );
      return widgetUtil;
    case AppStrings.lunchWidgetName:
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        mainMessage: "You are on break!",
        bgColor: AppColors.brand,
        mainWidget: const LunchBreakCountdown(),
      );

      final data = widgetInfo?.data;
      print("data received is $data");
      return widgetUtil;
    case AppStrings.lunchBreakRequest:
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are requested to take a lunch break",
        mainWidget: const LunchTimeRequest(),
      );
      return widgetUtil;
    case AppStrings.lunchCoolDownWidgetName:
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "You are on cooldown!",
        mainWidget: const RunnerLunchCooldown(),
      );
      return widgetUtil;
    case AppStrings.postCheckoutWidgetName:
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        bgColor: AppColors.g40,
        mainMessage: "Job completed. Take some rest!",
        mainWidget: const RateCustomer(),
      );
      return widgetUtil;
    case AppStrings.preMarkArrival:
      WidgetUtil widgetUtil = WidgetUtil(
        status: Container(),
        mainMessage: "New Job assigned",
        bgColor: AppColors.brand,
        mainWidget: PreMarkArrival(
          data: widgetInfo?.data ?? {},
        ),
      );
      return widgetUtil;
    default:
      return WidgetUtil(
        status: Container(),
        bgColor: AppColors.brand,
        mainMessage: "Give us some time to resolve the issue.",
        mainWidget: Center(
          child: Column(
            children: [
              if (GlobalState().appError.value == AppErrorType.noInternet)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Text("Device is not connected to internet"),
                ),
              if (GlobalState().appError.value == AppErrorType.invalidRequest)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Text("Bad request from server"),
                ),
              if (GlobalState().appError.value == AppErrorType.serverDown)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child:
                      Text("Request timed out due to poor internet connection"),
                ),
              if (GlobalState().appError.value == AppErrorType.otherError)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Text("Something went wrong"),
                ),
              Image.asset(
                'assets/error_page.png',
                height: 150.r,
                width: 150.r,
              ),
            ],
          ),
        ),
      );
    // throw "Widget cannot be found";
  }
}

String? getWidgetNameFromData(Map<String, dynamic>? data) {
  return data?["widget_name"];
}

/// Routes runners on rate card v1 to the legacy assigned-job UI and v2
/// runners to the redesigned card. Mirrors the v1/v2 split used for the
/// emergency-logout flow in `drawer_menu.dart`.
class NewJobAssignedRouter extends StatelessWidget {
  final Map<String, dynamic>? widgetData;

  const NewJobAssignedRouter({super.key, this.widgetData});

  @override
  Widget build(BuildContext context) {
    final optedForNewRateCard =
        context.watch<UserProfileProvider>().optedForNewRateCard;
    return optedForNewRateCard
        ? NewJobAssigned(widgetData: widgetData)
        : NewJobAssignedV1(widgetData: widgetData);
  }
}
