import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/analytics/job_lifecycle_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/svg_strings.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/attendance_flow/attendance_confirmed.dart';
import 'package:snabbit_runner/widgets/checkout_outside_job_location.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/elevated_button_with_loader.dart';
import 'package:snabbit_runner/widgets/job_in_progress/late_checkout_warning.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/job_in_progress/rating_block_handler.dart';

import '../../constants/assets_constants.dart';
import '../job_start_flow/new_job_assigned.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import '../common_widgets/job_payout_card.dart';
import 'card_penalty.dart';

class RateCustomer extends StatefulWidget {
  const RateCustomer({
    super.key,
  });

  @override
  State<RateCustomer> createState() => _RateCustomerState();
}

class _RateCustomerState extends State<RateCustomer>
    with WidgetsBindingObserver {
  bool init = true;
  bool loading = false;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late UserProfileProvider userProfileProvider;
  late OnTheJobStateProvider onTheJobStateProvider;
  late List<dynamic> blockedCustomers;
  bool showRating = false;
  bool isAppForeground = true;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      _trackJobCompletedScreenLoad();
    }
  }

  void _trackJobCompletedScreenLoad() {
    final data = runnerRtDataProvider.widgetInfo?.data ?? const {};
    final payout =
        (data['payout_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    JobLifecycleAnalytics.logEvent(TrackingEvents.jobCompletedScreenLoad, {
      'is_long_distance': data['is_long_distance'] == true,
      'is_ot': data['is_ot'] == true,
      'date': data['date'],
      'shift_end_time': data['shift_end_time'],
      'is_yellow_card': data['is_yellow_card'] == true,
      'yellow_card_amount': data['yellow_card_amount'],
      'is_red_card': data['is_red_card'] == true,
      'red_card_amount': data['red_card_amount'],
      'total_earning': payout['total_earning'],
      'work_earning': payout['work_amount'],
      'work_duration_mins': payout['work_duration_mins'],
      'ot_earning': payout['ot_amount'],
      'ot_duration_mins': payout['ot_duration_mins'],
      'long_distance_earning': payout['long_distance_amount'],
      'long_distance_km': payout['long_distance_km'],
      'checkin_earning': payout['check_in_amount'],
      'checkin_time_shown': payout['check_in_time'],
      'minutes_early_or_late': payout['check_in_mins'],
      'is_past_checkin': payout['is_past_checkin'] == true,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    isAppForeground = state == AppLifecycleState.resumed;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isAppForeground == true) {
      Future(() {
        showCheckoutWarning(
          context,
          runnerRtDataProvider.widgetInfo?.data,
        );
      });
    }
    return Column(
      children: [
        if (runnerRtDataProvider
                .widgetInfo?.data?['show_late_checkout_warning'] ==
            true)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: const LateCheckoutWarning(),
          ),
        YellowCard1(
          languageProvider: languageProvider,
          data: runnerRtDataProvider.widgetInfo?.data,
        ),
        RedCard(
          languageProvider: languageProvider,
          data: runnerRtDataProvider.widgetInfo?.data,
        ),
        if (runnerRtDataProvider.widgetInfo?.data?["is_ot"] == true &&
            (runnerRtDataProvider.widgetInfo?.data?["ot_amount"] ?? 0) > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: AmountBanner(
              // bottomPrefix: runnerRtDataProvider
              //             .widgetInfo?.data?["ot_mins"] !=
              //         null
              //     ? '${minsToHours(runnerRtDataProvider.widgetInfo?.data?["ot_mins"])} ${languageProvider.getMessage(
              //         'hours',
              //         'Hours',
              //       )}'
              //     : null,
              prefixIconSize: 80.w,
              valueBoxSize: 110.w,
              image: AssetConstants.otBanner,
              amount: anyValueToInt(
                      runnerRtDataProvider.widgetInfo?.data?["ot_amount"]) ??
                  0,
              title: Text(
                languageProvider.getMessage(
                  "bonus_capital",
                  "BONUS",
                ),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff03445F),
                    ),
              ),
              subtitle: languageProvider.getMessage(
                "extra_capital",
                "EXTRA",
              ),
            ),
          ),
        if (runnerRtDataProvider.widgetInfo?.data?["is_long_distance"] ==
                true &&
            (runnerRtDataProvider.widgetInfo?.data?["long_distance_amount"] ??
                    0) >
                0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: AmountBanner(
              prefixIconSize: 80.w,
              valueBoxSize: 110.w,
              image: AssetConstants.longDistanceBanner,
              amount: anyValueToInt(runnerRtDataProvider
                      .widgetInfo?.data?["long_distance_amount"]) ??
                  0,
              title: Text(
                languageProvider.getMessage(
                  "long_distance_capital",
                  "LONG\nDISTANCE\nBONUS",
                ),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff1F0B6E),
                    ),
              ),
              subtitle: languageProvider.getMessage(
                "extra_capital",
                "EXTRA",
              ),
            ),
          ),
        if (runnerRtDataProvider.widgetInfo?.data?["is_time_pe"] == true &&
            (runnerRtDataProvider.widgetInfo?.data?["time_pe_amount"] ?? 0) > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: AmountBanner(
              prefixIconSize: 80.w,
              valueBoxSize: 110.w,
              amount: anyValueToInt(runnerRtDataProvider
                      .widgetInfo?.data?["time_pe_amount"]) ??
                  0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      languageProvider.getMessage(
                        "bonus_capital",
                        "BONUS",
                      ),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff276209),
                          ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      languageProvider.getMessage(
                        "you_arrived_before_time",
                        "You arrived before time",
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, color: AppColors.r60),
                    ),
                  ),
                ],
              ),
              image: AssetConstants.timePeBanner,
              subtitle: languageProvider.getMessage(
                "extra_capital",
                "EXTRA",
              ),
            ),
          ),
        if (runnerRtDataProvider.widgetInfo?.data?["is_time_pe"] == true &&
            (runnerRtDataProvider.widgetInfo?.data?["time_pe_amount"] ?? 0) < 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: AmountBanner(
              prefixIconSize: 80.w,
              valueBoxSize: 110.w,
              amount: anyValueToInt(runnerRtDataProvider
                      .widgetInfo?.data?["time_pe_amount"]) ??
                  0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      languageProvider.getMessage(
                        "penalty_capital",
                        "PENALTY",
                      ),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.r40,
                          ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      languageProvider.getMessage(
                        "you_arrived_late",
                        "You arrived Late",
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.r60,
                          ),
                    ),
                  ),
                ],
              ),
              image: AssetConstants.timePePenalty,
            ),
          ),
        if (runnerRtDataProvider
                    .widgetInfo?.data?['show_logout_warning_widgets'] ==
                true &&
            runnerRtDataProvider.widgetInfo?.data?['is_logout'] == true)
          logoutWarningWidgets(),
        showRating
            ? loading || runnerRtDataProvider.waitForFetchData
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildYouEarnedCard(),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 8.h,
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.g40,
                          size: 72,
                        ),
                        SizedBox(
                          height: 24.h,
                        ),
                        Text(
                          languageProvider.getMessage(
                              "completed_job", "Completed the job"),
                          style:
                              TextStyle(fontSize: 15.sp, color: AppColors.n90),
                        ),
                        SizedBox(
                          height: 24.h,
                        ),
                        _buildYouEarnedCard(),
                        const Divider(
                          color: AppColors.n30,
                        ),
                        SizedBox(height: 8.h),
                        const RatingBlockHandler(),
                      ],
                    ),
                  )
            : TasksDoneByRunner(
                postProcess: () {
                  setState(() {
                    showRating = true;
                  });
                },
              ),
        if (runnerRtDataProvider
                    .widgetInfo?.data?['show_logout_warning_widgets'] ==
                true &&
            runnerRtDataProvider.widgetInfo?.data?['is_logout'] != true)
          logoutWarningWidgets(),
      ],
    );
  }

  /// Shown only after [TasksDoneByRunner] confirms; not while task checkboxes are visible.
  Widget _buildYouEarnedCard() {
    final raw = runnerRtDataProvider.widgetInfo?.data?['payout_info'];
    if (raw == null) {
      final isV2Effective =
          userProfileProvider.user?.isRateCardV2Effective == true;
      if (!isV2Effective) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: _CalculatingEarningsCard(languageProvider: languageProvider),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: JobPayoutCard(
        payoutInfo: PayoutInfo.fromDynamic(raw),
        headerText: languageProvider.getMessage('you_earned', 'You Earned'),
      ),
    );
  }

  Widget logoutWarningWidgets() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: 16.h,
            top: 12.h,
          ),
          child: AmountBanner(
            prefixIconSize: 90.w,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  languageProvider.getFormattedMessage(
                    'logout_at',
                    'Logout at {{shift_end_time}}',
                    {
                      'shift_end_time': runnerRtDataProvider
                          .widgetInfo?.data?["shift_end_time"],
                    },
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xff623D09), fontSize: 16.sp),
                ),
                Text(
                  languageProvider.getMessage(
                    'dont_lose_ming',
                    'Don\'t Lose MinG',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xff623D09),
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
            image: AssetConstants.attendancePendingAmber,
            valueBoxSize: 0,
          ),
        ),
        if (runnerRtDataProvider.widgetInfo?.data?['is_logout'] != true)
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.y10,
                borderRadius: BorderRadius.circular(1000.r),
              ),
              padding: EdgeInsets.symmetric(
                vertical: 12.h,
                horizontal: 21.w,
              ),
              child: Text(
                languageProvider.getMessage(
                  'remain_at_place_for_logout',
                  'Remain at your place to logout',
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16.sp,
                      color: AppColors.y60,
                    ),
              ),
            ),
          ),
        Text(
          "${runnerRtDataProvider.widgetInfo?.data?["date"] ?? ""}",
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
              ?.copyWith(fontSize: 28.sp, fontWeight: FontWeight.w800),
        ),
        Text(
          "${runnerRtDataProvider.widgetInfo?.data?["shift_end_time"] ?? ""}",
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(fontSize: 28.sp, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 20.h),
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed:
                runnerRtDataProvider.widgetInfo?.data?['is_logout'] == true
                    ? () async {
                        Response? response = await JobHttp.runnerLogout();
                        if (response != null && response.statusCode == 200) {
                          // success
                          if (mounted) {
                            showSnackbar(
                              context,
                              languageProvider.getMessage(
                                'logout_successful',
                                'Logout successful',
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            showSnackbar(
                              context,
                              "${response?.data ?? "Something went wrong. Please try again!"}",
                            );
                          }
                        }
                        runnerRtDataProvider.fetchDataNow();
                        ClevertapSetup.logEvent(
                            TrackingEvents.runnerLogoutButtonClicked, {
                          "action": "runner logout button clicked",
                        });
                      }
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.n90,
            ),
            child: Text(
              languageProvider.getMessage(
                'logout',
                'Logout',
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
      ],
    );
  }
}

/// Skip task UI when API returns nothing actionable (null, NONE, empty, non-list).
bool _shouldSkipPostCheckoutTaskPayload(dynamic data) {
  if (data == null) return true;
  if (data is String) {
    return data.trim().toUpperCase() == 'NONE';
  }
  if (data is! List) return true;
  return data.isEmpty;
}

class TasksDoneByRunner extends StatefulWidget {
  final VoidCallback postProcess;

  const TasksDoneByRunner({
    super.key,
    required this.postProcess,
  });

  @override
  State<TasksDoneByRunner> createState() => _TasksDoneByRunnerState();
}

class _TasksDoneByRunnerState extends State<TasksDoneByRunner> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  List<HouseTask>? houseTasks;
  List<HouseTask> selectedHouseTasks = [];
  HouseTask? otherHouseTask;

  @override
  void didChangeDependencies() {
    if (init) {
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
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    void skipToRating() {
      if (!mounted) return;
      widget.postProcess();
    }

    try {
      final response = await RunnerHttp.runnerHouseTasks(
        jobId: runnerRtDataProvider.jobId ?? 0,
      );
      if (response == null || response.statusCode != 200) {
        skipToRating();
        return;
      }
      final data = response.data;
      if (_shouldSkipPostCheckoutTaskPayload(data)) {
        skipToRating();
        return;
      }
      final rawList = data as List<dynamic>;
      final List<HouseTask> parsed = [];
      for (final e in rawList) {
        if (e is! Map) continue;
        try {
          parsed.add(
            HouseTask.fromJson(Map<String, dynamic>.from(e)),
          );
        } catch (_) {}
      }
      HouseTask? other;
      try {
        other = parsed.firstWhere((e) => e.key == AppStrings.othersTaskString);
        parsed.removeWhere((e) => e.key == AppStrings.othersTaskString);
      } catch (_) {}

      final filtered =
          parsed.where((t) => t.image != null || t.key != null).toList();

      if (filtered.isEmpty && other == null) {
        skipToRating();
        return;
      }
      houseTasks = filtered;
      otherHouseTask = other;
    } catch (_) {
      skipToRating();
    }
  }

  Future<void> submitHomeTasks() async {
    setState(() {
      loading = true;
    });
    try {
      Response? response = await RunnerHttp.runnerSubmitHouseTasks(
        jobId: runnerRtDataProvider.jobId ?? 0,
        data: {
          'job_task_collection':
              selectedHouseTasks.map((e) => e.toMap()).toList(),
        },
      );
      if (response != null && response.statusCode == 200) {
        // SUCCESS
        widget.postProcess();
      } else {
        if (mounted) {
          showSnackbar(context, "Server error - ${response?.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, "Something went wrong - $e");
      }
    }
    setState(() {
      loading = false;
    });
  }

  bool isCurrentTaskSelected(HouseTask task) {
    try {
      return selectedHouseTasks.contains(task);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : houseTasks != null
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      languageProvider.getMessage(
                        "choose_jobs_done_now",
                        "Choose the jobs you have done now",
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 25.h),
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 156 / 140),
                      itemCount: houseTasks?.length,
                      itemBuilder: (_, idx) {
                        HouseTask currentHouseTask = houseTasks![idx];
                        if (currentHouseTask.image == null &&
                            currentHouseTask.key == null) {
                          return const SizedBox();
                        }
                        return InkWell(
                          onTap: () {
                            try {
                              if (selectedHouseTasks
                                  .contains(currentHouseTask)) {
                                selectedHouseTasks.remove(currentHouseTask);
                              } else {
                                selectedHouseTasks.add(currentHouseTask);
                              }
                              setState(() {});
                            } catch (e) {
                              // DO NOTHING
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrentTaskSelected(currentHouseTask)
                                  ? AppColors.g0
                                  : AppColors.n0,
                              border: Border.all(
                                color: isCurrentTaskSelected(currentHouseTask)
                                    ? AppColors.g20
                                    : AppColors.n50,
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Stack(
                              children: [
                                if (isCurrentTaskSelected(currentHouseTask))
                                  Positioned(
                                    top: 9.h,
                                    right: 11.w,
                                    child: const CircularCheckbox(
                                      value: true,
                                      bgColor: AppColors.g40,
                                      iconSize: 14,
                                      circularCheckboxPadding: 4,
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: 20.h,
                                    left: 16.w,
                                    right: 16.w,
                                    bottom: 10.h,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Image.network(
                                          currentHouseTask.image ?? "",
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 13.h,
                                      ),
                                      Center(
                                        child: Text(
                                          languageProvider.getMessage(
                                            currentHouseTask.key ?? "",
                                            currentHouseTask.key ?? "",
                                          ),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: isCurrentTaskSelected(
                                                        currentHouseTask)
                                                    ? AppColors.g40
                                                    : AppColors.n90,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (otherHouseTask != null)
                      Padding(
                        padding: EdgeInsets.only(top: 24.h),
                        child: InkWell(
                          onTap: () {
                            if (selectedHouseTasks.contains(otherHouseTask)) {
                              selectedHouseTasks.remove(otherHouseTask);
                            } else {
                              selectedHouseTasks.add(otherHouseTask!);
                            }
                            setState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrentTaskSelected(otherHouseTask!)
                                  ? AppColors.g0
                                  : AppColors.n0,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isCurrentTaskSelected(otherHouseTask!)
                                    ? AppColors.g20
                                    : AppColors.n50,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (isCurrentTaskSelected(otherHouseTask!))
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: 9.h,
                                        right: 11.w,
                                      ),
                                      child: const CircularCheckbox(
                                        value: true,
                                        bgColor: AppColors.g40,
                                        iconSize: 14,
                                        circularCheckboxPadding: 4,
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.h),
                                    child: Text(
                                      languageProvider.getMessage(
                                        otherHouseTask?.key ?? "",
                                        AppStrings.othersTaskString,
                                      ),
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 36.h),
                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: selectedHouseTasks.isEmpty
                            ? null
                            : () async {
                                await submitHomeTasks();
                              },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.n0,
                          backgroundColor: AppColors.g40,
                        ),
                        child: const Text("Confirm"),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink();
  }
}

class _CalculatingEarningsCard extends StatelessWidget {
  final LanguageProvider languageProvider;

  const _CalculatingEarningsCard({required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            AssetConstants.earningCalculationInprogress,
            width: 40.w,
            height: 40.w,
          ),
          SizedBox(height: 8.h),
          Text(
            languageProvider.getMessage(
              'calculating_your_earnings',
              'Calculating your earnings',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
              height: 24 / 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            languageProvider.getMessage(
              'check_on_earnings_page_later',
              'You can check this on earnings page later',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w400,
              fontSize: 14.sp,
              height: 20 / 14,
              color: const Color(0xFF525871),
            ),
          ),
        ],
      ),
    );
  }
}

class HouseTask {
  String? key;
  String? image;

  HouseTask({
    this.key,
    this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
    };
  }

  factory HouseTask.fromJson(Map<String, dynamic> json) {
    return HouseTask(
      key: json['key'],
      image: json['asset_link'],
    );
  }
}
