import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/lunch_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/sos.dart';

import '../../services/clevertap.dart';
import '../../utils/common_methods.dart';
import '../../utils/constants.dart';
import '../../utils/tracking_events.dart';
import '../common_bottomsheet_setup.dart';

class RunnerLunch extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const RunnerLunch({
    super.key,
    this.widgetData,
  });

  @override
  State<RunnerLunch> createState() => _RunnerLunchState();
}

class _RunnerLunchState extends State<RunnerLunch> {
  Duration localDurationRemaining = Duration.zero;
  int? currentDuration;
  Timer? _timer;
  String? error;
  bool init = true;
  bool loading = true;
  DateTime? endTime;
  DateTime? startTime;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  bool extraPollAfterTimeEnd = false;

  bool isError = false;

  Future<void> initProcess() async {
    setStartAndEndTime();
    // print("endtime $endTime");
    if (endTime != null) {
      localDurationRemaining = endTime!.difference(DateTime.now());
    }

    currentDuration = widget.widgetData?['duration'];
    await timerPeriodicProcess();
    _timer = Timer.periodic(1.seconds, (_) async {
      await timerPeriodicProcess();
      if (!extraPollAfterTimeEnd &&
          localDurationRemaining.inSeconds == secondsAfterBreakApiCall) {
        extraPollAfterTimeEnd = true;
        runnerRtDataProvider.waitForFetchData = true;
        setState(() {});
        runnerRtDataProvider.fetchDataNow();
      }
    });
  }

  Future<void> timerPeriodicProcess() async {
    currentDuration = widget.widgetData?['duration'];
    // String startTime = widget.widgetData?['start_time'];
    //
    // DateTime endtime = DateTime.parse(startTime)
    //     .add(Duration(minutes: widget.widgetData?['duration'])).toLocal();
    if (endTime != null) {
      localDurationRemaining = endTime!.difference(DateTime.now());
    } else {
      localDurationRemaining = Duration.zero;
    }

    setState(() {});
  }

  void setStartAndEndTime() {
    String? startTimeStr = widget.widgetData?['start_time'];
    if (startTimeStr != null) {
      startTime = DateTime.parse(startTimeStr).toLocal();
      endTime = startTime!
          .add(Duration(minutes: widget.widgetData?['duration']))
          .toLocal();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
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
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (currentDuration != null &&
          currentDuration != widget.widgetData?['duration']) {
        String startTime = widget.widgetData?['start_time'];

        DateTime endtime = DateTime.parse(startTime)
            .add(Duration(minutes: widget.widgetData?['duration']));

        localDurationRemaining = endtime.difference(DateTime.now());
      }
    } catch (e) {
      Logger().i(e);
    }
    return loading || runnerRtDataProvider.waitForFetchData == true
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 16.h,
                ),
                Text(
                  languageProvider.getMessage("time_to_relax",
                      "We value your hard work!\nTake this time to relax"),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.n0),
                ),
                SizedBox(height: 31.h),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.flip(
                      flipX: localDurationRemaining.inSeconds >= 0,
                      flipY: true,
                      child: SizedBox(
                        width: 204.r,
                        height: 204.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 16.r,
                          strokeCap: StrokeCap.round,
                          value: currentDuration != null && currentDuration != 0
                              ? localDurationRemaining.inSeconds.abs() /
                                  (currentDuration! * 60)
                              : 0,
                          color: AppColors.n0,
                          backgroundColor: const Color(0xff738DD7),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          "Break",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.n0),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          formatTime(localDurationRemaining.inSeconds),
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppColors.n0,
                                fontSize: 32.sp,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                // SizedBox(height: 24.h),
                SizedBox(height: 36.h),
                const Divider(
                  color: Color(0xffACC4E8),
                ),
                if (endTime != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      "Break ends at ${DateFormat('hh:mm a').format(endTime!)}",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppColors.n0),
                    ),
                  ),
                const Divider(
                  color: Color(0xffACC4E8),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: 1.sw,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                          context: context,
                          builder: (_) {
                            return CommonBottomSheetSetup(
                              child: Column(
                                children: [
                                  SizedBox(height: 32.h),
                                  Text(
                                    languageProvider.getMessage(
                                        "ending_break_early",
                                        "Ending break early?"),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    languageProvider.getMessage(
                                      "are_you_sure_end_break_early",
                                      "Are you sure you want to end your break now? Take this time to recharge before your next task.",
                                    ),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: AppColors.n80),
                                  ),
                                  SizedBox(height: 31.h),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 16.h),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.g40,
                                            ),
                                            child: Text(
                                              languageProvider.getMessage(
                                                  "continue", "Continue"),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              try {
                                                ClevertapSetup.logEvent(
                                                  TrackingEvents
                                                      .breakConfirmEndButtonClicked,
                                                  {},
                                                );
                                                Response? response =
                                                    await LunchHttp
                                                        .runnersMeBreakEnd();
                                                if (response != null &&
                                                    response.statusCode ==
                                                        200) {
                                                  // SUCCESS
                                                } else {
                                                  if (context.mounted) {
                                                    showSnackbar(context,
                                                        "Break ending failed - ${response?.statusCode}");
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  showSnackbar(context,
                                                      "Break ending failed - $e");
                                                }
                                              }
                                              runnerRtDataProvider
                                                  .waitForFetchData = true;
                                              setState(() {});
                                              runnerRtDataProvider
                                                  .fetchDataNow();
                                              if (mounted && context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.r50,
                                              side: const BorderSide(
                                                  color: AppColors.r50),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 20.w,
                                                  vertical: 14.h),
                                            ),
                                            child: Text(
                                              languageProvider.getMessage(
                                                "end_now",
                                                "End now",
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.n0,
                      foregroundColor: AppColors.r40,
                    ),
                    child: Text(
                      languageProvider.getMessage(
                          "end_my_break", "End my break"),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}
