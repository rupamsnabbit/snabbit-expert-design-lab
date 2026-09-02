import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';

import '../../services/auto_ot_orchestrator.dart';
import '../../utils/colors.dart';
import 'attendance_change_sheet.dart';
import 'no_show_red_card_cluster.dart';

class AttendanceAbsent extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const AttendanceAbsent({
    super.key,
    required this.widgetData,
  });

  @override
  State<AttendanceAbsent> createState() => _AttendanceAbsentState();
}

class _AttendanceAbsentState extends State<AttendanceAbsent> {
  bool init = true;

  bool loading = true;

  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init = false;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: true);
    initProcess().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.widgetData;
    // Current-state `widget_data`: cards for this no-show (BE). Snake_case primary.
    final noShowRedCardCount = anyValueToInt(data?['no_show_red_card_count']) ??
        anyValueToInt(data?['noShowRedCardCount']);
    final showNoShowRedCards = data?['attendance_type'] == 'NO_SHOW' &&
        noShowRedCardCount != null &&
        noShowRedCardCount > 0;

    return data == null
        ? Container()
        : runnerRtDataProvider.waitForFetchData
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : Column(
                children: [
                  Text(
                    "${data['date'] ?? ""}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "${data["shift_time"] ?? ""}",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Divider(
                      color: AppColors.n30,
                    ),
                  ),
                  if (showNoShowRedCards) ...[
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Center(
                        child: NoShowRedCardCluster(
                          count: noShowRedCardCount,
                        ),
                      ),
                    ),
                  ],
                  Container(
                    height: 48.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.r50,
                    ),
                    padding: EdgeInsets.all(8.r),
                    child: const FittedBox(
                      child: Icon(
                        Icons.close,
                        color: AppColors.n0,
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      data["type"] == "TOMORROW"
                          ? languageProvider.getMessage(
                              "tomorrows_attendance_marked_as",
                              "Tomorrow's attendance marked as")
                          : languageProvider.getMessage(
                              "today_attendance_marked_as",
                              "Today's attendance marked as",
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  data["attendance_type"] == "ABSENT"
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: Column(
                            children: [
                              Text(
                                languageProvider.getMessage("absent", "Absent"),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20.sp,
                                        color: AppColors.r50),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: const Divider(
                                  color: AppColors.n30,
                                ),
                              ),
                              if (widget.widgetData?["change_atn"] == true)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.g50,
                                    side:
                                        const BorderSide(color: AppColors.n30),
                                  ),
                                  child: Text(
                                    languageProvider.getMessage(
                                      "change_attendance",
                                      "Change attendance",
                                    ),
                                  ),
                                  onPressed: () {
                                    final sheetNudges = filterSheetWarnings(
                                      runnerRtDataProvider.sheetWarnings,
                                      AttendanceSheetLifecycle
                                          .confirmMarkPresent,
                                    );
                                    final ctaMap =
                                        ctaOverridesForSheet(sheetNudges);
                                    final redCards = ctaMap[
                                                AttendanceSheetCtaIds
                                                    .markPresent]
                                            ?.redCards ??
                                        0;

                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (modalContext) {
                                        return AttendanceChangeSheet(
                                          entrySource: 'attendance_absent',
                                          headlineOverride:
                                              languageProvider.getMessage(
                                            'confirm_change_attendance',
                                            'Are you sure you want to change attendance?',
                                          ),
                                          sheetWarningLifecycle:
                                              AttendanceSheetLifecycle
                                                  .confirmMarkPresent,
                                          redCardCount: redCards,
                                          periodLeaveAvailable: false,
                                          supportsPeriodLeave: false,
                                          onMarkAbsent: () {
                                            Navigator.pop(modalContext);
                                          },
                                          onMarkPresent: () async {
                                            // Capture before any await so we don't use [modalContext]
                                            // after an async gap (use_build_context_synchronously).
                                            final nav =
                                                Navigator.maybeOf(modalContext);
                                            await ClevertapSetup.logEvent(
                                              TrackingEvents.attendanceChanged,
                                              {
                                                'runner_attendance_absent':
                                                    'attendance change',
                                                'from': 'absent',
                                              },
                                            );
                                            // Dismiss the sheet before post-action (root) overlay so the
                                            // same Navigator isn't popping with competing routes.
                                            if (nav != null && nav.canPop()) {
                                              nav.pop();
                                            }
                                            await Future<void>.delayed(
                                                const Duration(
                                                    milliseconds: 300));
                                            if (!context.mounted) return;

                                            runnerRtDataProvider
                                                .setWaitForFetchData(true);
                                            final response =
                                                await JobHttp.changeAttendance(
                                                    data: {
                                                  'mark': true,
                                                  'shift_date':
                                                      data['start_date_ist'],
                                                });
                                            if (response?.statusCode == 200) {
                                              await PostActionOverlayController
                                                  .instance
                                                  .showFromResponse(
                                                response?.data,
                                                LifecycleActionType
                                                    .falseAttendance,
                                              );
                                              await AutoOtOrchestrator
                                                  .onAttendanceMarked();
                                            } else {
                                              if (context.mounted) {
                                                showSnackbar(
                                                  context,
                                                  '${response?.data ?? 'Something went wrong. Please try again!'}',
                                                );
                                              }
                                            }
                                            await runnerRtDataProvider
                                                .fetchDataNow();
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              SizedBox(height: 28.h),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: AppColors.n60,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 10.h,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.widgetData?["type"] == "TOMORROW"
                                            ? languageProvider
                                                .getFormattedMessage(
                                                "attendance_earnings_warning_tomorrow",
                                                "You will lose {{lost_ming_amount}} MinG tomorrow",
                                                {
                                                  "lost_ming_amount":
                                                      createNegativeAmount(
                                                          anyValueToInt(
                                                              runnerRtDataProvider
                                                                      .widgetInfo
                                                                      ?.data?[
                                                                  "lost_ming_amount"])),
                                                },
                                              )
                                            : languageProvider
                                                .getFormattedMessage(
                                                "attendance_earnings_warning_today",
                                                "You will lose {{lost_ming_amount}} MinG today",
                                                {
                                                  "lost_ming_amount":
                                                      createNegativeAmount(
                                                          anyValueToInt(
                                                              runnerRtDataProvider
                                                                      .widgetInfo
                                                                      ?.data?[
                                                                  "lost_ming_amount"])),
                                                },
                                              ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: AppColors.n0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    SvgPicture.asset(AssetConstants.sadEmoji),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            SizedBox(height: 4.h),
                            Text(
                              widget.widgetData?['attendance_type'] == 'NO_SHOW'
                                  ? languageProvider.getMessage(
                                      'no_show',
                                      'No Show',
                                    )
                                  : languageProvider.getMessage(
                                      'false_attendance',
                                      'False Attendance',
                                    ),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.r50,
                                  ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: const Divider(
                                color: AppColors.n30,
                              ),
                            ),
                            if (widget.widgetData?['fp_warning'] == true)
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: AppColors.y20,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 10.h,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            languageProvider.getMessage(
                                              'strict_warning',
                                              'Strict Warning',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                  fontSize: 18.sp,
                                                  color: AppColors.y60,
                                                ),
                                          ),
                                          SizedBox(height: 4.h),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: languageProvider
                                                      .getMessage(
                                                    'allowed_once_per_month',
                                                    'Allowed once a month. ',
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: AppColors.y60,
                                                      ),
                                                ),
                                                TextSpan(
                                                  text: languageProvider
                                                      .getFormattedMessage(
                                                    "fp_penalty_warning2",
                                                    "You will lose {{fp_penalty}} next time.",
                                                    {
                                                      "fp_penalty": createNegativeAmount(
                                                          anyValueToInt(
                                                              runnerRtDataProvider
                                                                      .widgetInfo
                                                                      ?.data?[
                                                                  "fp_penalty"])),
                                                    },
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        color: AppColors.y60,
                                                      ),
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    SvgPicture.asset(
                                      AssetConstants.sadEmoji,
                                      color: AppColors.y50,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: AppColors.r20,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 10.h,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            languageProvider
                                                .getFormattedMessage(
                                              "penalty_of",
                                              "Penalty of {{fp_penalty}}",
                                              {
                                                "fp_penalty":
                                                    createNegativeAmount(
                                                        anyValueToInt(
                                                            runnerRtDataProvider
                                                                    .widgetInfo
                                                                    ?.data?[
                                                                "fp_penalty"])),
                                              },
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayMedium
                                                ?.copyWith(
                                                  fontSize: 18.sp,
                                                  color: AppColors.r60,
                                                ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            languageProvider.getMessage(
                                              'lost_ming',
                                              'Lost MinG',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: AppColors.r60,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    SvgPicture.asset(
                                      AssetConstants.sadEmoji,
                                      color: AppColors.r50,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ],
              );
  }
}
