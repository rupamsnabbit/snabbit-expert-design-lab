import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/auto_ot_orchestrator.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/attendance_flow/custom_timer.dart';
import 'package:snabbit_runner/widgets/attendance_flow/support_team_list.dart';
import 'package:snabbit_runner/widgets/attendance_reason_dialog.dart';
import '../../providers/runner_rt_data.dart';
import '../../services/job_http.dart';
import '../../utils/app_strings.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../elevated_button_with_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrentDayAttendance extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const CurrentDayAttendance({
    super.key,
    required this.widgetData,
  });

  @override
  State<CurrentDayAttendance> createState() => _CurrentDayAttendanceState();
}

class _CurrentDayAttendanceState extends State<CurrentDayAttendance> {
  void showNoAttendanceConfirmation(BuildContext context) {
    String? error;
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16.r),
          ),
        ),
        builder: (BuildContext ctx) {
          return Consumer<RunnerRtDataProvider>(
              builder: (context, runnerRtDataProvider, child) {
            return StatefulBuilder(builder: (_, bottomSheetSetState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.2,
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.h),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 4.h,
                            width: 36.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.r),
                              color: const Color(0xffD1D1D1),
                              // TODO color not found
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          languageProvider.getMessage("are_you_sure_want_leave",
                              "Are you sure you want to take a leave?"),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          languageProvider.getMessage("charged_penalty_100",
                              "You will be charged a penalty of ₹ 100 if you say 'Yes'"),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.n80),
                        ),
                        SizedBox(height: 16.h),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButtonWithLoader(
                                  text:
                                      languageProvider.getMessage("yes", "Yes"),
                                  bgColor: const Color(0xffEAEAF1),
                                  // TODO color not found
                                  textColor: AppColors.r50,
                                  onPressed: () async {
                                    if (context.mounted) {
                                      String? selectedReason = await showDialog(
                                        context: context,
                                        builder: (BuildContext context) =>
                                            const AttendanceReasonDialog(),
                                      );
                                      if (selectedReason != null) {
                                        Response? response =
                                            await JobHttp.changeAttendance(
                                                data: {
                                              "mark": false,
                                              "shift_date": widget.widgetData?[
                                                  "start_date_ist"],
                                              "absentism_reason": selectedReason
                                            });

                                        if (response != null &&
                                            response.statusCode == 200) {
                                          error = null;
                                          await ClevertapSetup.logEvent(
                                              TrackingEvents.attendanceMarked, {
                                            "runner_attendance":
                                                "attendance marked",
                                            "marked": false,
                                            "type": "current_day"
                                          });
                                          runnerRtDataProvider.fetchDataNow();
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        } else {
                                          if (context.mounted) {
                                            error =
                                                "${response?.data ?? "Something went wrong. Please try again!"}";

                                            showSnackbar(
                                              context,
                                              "$error",
                                            );
                                          }
                                        }
                                      }
                                    }

                                    bottomSheetSetState(() {});
                                  },
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: ElevatedButtonWithLoader(
                                  text: languageProvider.getMessage("no", "No"),
                                  bgColor: AppColors.g40,
                                  onPressed: () async {
                                    // Response? response =
                                    //     await JobHttp.markAttendance(
                                    //         data: {"mark": true});
                                    // if (response != null &&
                                    //     response.statusCode == 200) {
                                    //   error = null;
                                    //   // success
                                    //   runnerRtDataProvider.fetchDataNow();
                                    //   if (context.mounted) {
                                    //     Navigator.of(context).pop();
                                    //   }
                                    // } else {
                                    //   error =
                                    //       "${response?.data ?? "Something went wrong. Please try again!"}";
                                    // }
                                    // bottomSheetSetState(() {});
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                            ),
                            child: Container(
                              width: double.infinity,
                              color: Colors.black,
                              padding: EdgeInsets.all(8.r),
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            });
          });
        });
  }

  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init = false;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    initProcess().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
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
                    if (widget.widgetData!['attendance_pending_status'] != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 24.h),
                        child:
                            (widget.widgetData!['attendance_pending_status'] ==
                                    'GREEN')
                                ? Image.asset(
                                    AssetConstants.people,
                                    height: 100.h,
                                    fit: BoxFit.contain,
                                  )
                                : (widget.widgetData![
                                            'attendance_pending_status'] ==
                                        'AMBER')
                                    ? Image.asset(
                                        AssetConstants.attendancePendingAmber,
                                        height: 100.h,
                                        fit: BoxFit.contain,
                                      )
                                    : (widget.widgetData![
                                                'attendance_pending_status'] ==
                                            'RED')
                                        ? Image.asset(
                                            AssetConstants.attendancePendingRed,
                                            height: 100.h,
                                            fit: BoxFit.contain,
                                          )
                                        : const SizedBox(),
                      ),
                    // Rest of the content
                    Text(
                      "${widget.widgetData!["date"] ?? ""}",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    // Show the timer if attendance_time is available
                    if (widget.widgetData?["attendance_time"] != null &&
                        ['AMBER', 'RED'].contains(
                            widget.widgetData!['attendance_pending_status']))
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: CircularTimerWidget(
                          labelText: languageProvider.getMessage(
                            'login_now',
                            'LOGIN NOW',
                          ),
                          lateText: languageProvider.getMessage(
                            'login_now',
                            'LOGIN NOW',
                          ),
                          labelTextColor: AppColors.r50,
                          lateTextColor: AppColors.r60,
                          sharedPrefsKeyPrefix:
                              TimerPrefixStrings.attendanceTime,
                          utcTimeString:
                              widget.widgetData!["attendance_time"] as String,
                          backgroundColor: AppColors.r30,
                          strokeWidth: 18,
                          width: 124,
                          height: 124,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Text(
                      "${widget.widgetData!["shift_time"] ?? ""}",
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    SizedBox(height: 12.h),
                    if (widget.widgetData?['provisional_atn'] == true) ...[
                      const Divider(
                        color: AppColors.n30,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        child: Text(
                          languageProvider.getMessage(
                              "provisional_attendance_marked_yesterday_present",
                              "Provisional attendance marked yesterday - Present"),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppColors.g40),
                        ),
                      ),
                    ],
                    const Divider(
                      color: AppColors.n30,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      languageProvider.getMessage(
                          "are_you_coming_today", "Are you coming today?"),
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: Colors.black),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButtonWithLoader(
                        text: languageProvider.getMessage(
                            "yes_i_am_coming", "Yes, I am coming"),
                        bgColor: AppColors.g40,
                        onPressed: () async {
                          // initializeService();
                          // final prefs = await SharedPreferences.getInstance();
                          // await prefs.setBool(
                          //     AppStrings.isBGLocationServiceEnabled, true);
                          // await Future.delayed(Duration(seconds: 10));
                          Response? response = await JobHttp.changeAttendance(
                              data: {
                                "mark": true,
                                "shift_date":
                                    widget.widgetData?["start_date_ist"],
                              });
                          if (response?.statusCode == 200) {
                            await AutoOtOrchestrator.onAttendanceMarked();
                            await ClevertapSetup.logEvent(
                                TrackingEvents.attendanceMarked, {
                              "runner_attendance": "attendance marked",
                              "marked": true,
                              "type": "current_day"
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
                        },
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          showNoAttendanceConfirmation(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.r40,
                        ),
                        child: Text(languageProvider.getMessage(
                            "no_i_am_not_coming", "No, I am not coming")),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child: const Divider(
                        color: AppColors.n30,
                      ),
                    ),
                    if (widget.widgetData!["is_ming_applicable"] == false)
                      const MingEligibilityCard(),

                    if(widget.widgetData?["customer_support"]!=null)
                      SupportTeamList(membersJson: widget.widgetData?["customer_support"] ?? [],),
                  ],
                );
    });
  }
}

class MingEligibilityCard extends StatefulWidget {
  const MingEligibilityCard({super.key});

  @override
  State<MingEligibilityCard> createState() => _MingEligibilityCardState();
}

class _MingEligibilityCardState extends State<MingEligibilityCard> {
  bool _isExpanded = false;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: AppColors.n30,
        border: Border.all(color: AppColors.n50),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          // Header section
          Container(
            decoration: BoxDecoration(
              color: AppColors.n30,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      languageProvider.getMessage(
                        "ming_wont_apply",
                        "MinG won't apply",
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.n80,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.n0,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getMessage(
                            "learn_more",
                            "Learn more",
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.n80,
                                  ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          color: AppColors.n80,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded content - only visible when expanded
          if (_isExpanded)
            Container(
              margin: EdgeInsets.only(top: 14.h),
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.n10.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MinG eligibility status bar
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff40515B), Color(0xffA0A7AE)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16.r,
                          height: 16.r,
                          decoration: BoxDecoration(
                            color: AppColors.n0,
                            borderRadius: BorderRadius.circular(9.58.r),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12.sp,
                            color: const Color(0xff4D5D66),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          languageProvider.getMessage(
                            "ming_not_eligible",
                            "MinG not eligible",
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.n0,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Reason for ineligibility
                  Text(
                    languageProvider.getMessage(
                      "not_eligible_because",
                      "You are not eligible for MinG because:",
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.n80,
                        ),
                  ),

                  SizedBox(height: 8.h),

                  // Specific reason with icon
                  Row(
                    children: [
                      Icon(
                        Icons.close,
                        color: AppColors.r50,
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        languageProvider.getMessage(
                          "marked_absent_yesterday",
                          "Marked Absent Yesterday",
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.n80,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
