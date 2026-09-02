import 'dart:async';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/sos.dart';

import '../utils/constants.dart';

class RunnerLunchCooldown extends StatefulWidget {
  const RunnerLunchCooldown({super.key});

  @override
  State<RunnerLunchCooldown> createState() => _RunnerLunchCooldownState();
}

class _RunnerLunchCooldownState extends State<RunnerLunchCooldown> {
  bool init = true;
  Duration localDurationRemaining = Duration.zero;
  late RunnerRtDataProvider runnerRtDataProvider;
  late LanguageProvider languageProvider;
  DateTime? coolDownStart;
  DateTime? coolDownEnd;
  Duration? coolDownDuration;
  DateTime? breakStart;
  DateTime? breakEnd;
  int? breakDuration;
  Timer? _timer;
  bool extraPollAfterTimeEnd = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      setup();
      setLocalDurationRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        timerPeriodicProcess();
        if (!extraPollAfterTimeEnd && localDurationRemaining.inSeconds == secondsAfterBreakApiCall) {
          extraPollAfterTimeEnd = true;
          runnerRtDataProvider.waitForFetchData = true;
          setState(() {});
          runnerRtDataProvider.fetchDataNow();
        }
      });
    }
    super.didChangeDependencies();
  }

  void setup() {
    try {
      coolDownStart = DateTime.tryParse(
              runnerRtDataProvider.widgetInfo?.data?['cooldown_start_time'] ?? "")
          ?.toLocal();
      coolDownDuration = Duration(
          minutes:
              runnerRtDataProvider.widgetInfo?.data?['cooldown_duration'] ??
                  0);
      if (coolDownDuration != null) {
        coolDownEnd =
            coolDownStart?.add(coolDownDuration ?? Duration.zero).toLocal();
      }
      breakStart = DateTime.tryParse(
              runnerRtDataProvider.widgetInfo?.data?['start_time'] ?? "")
          ?.toLocal();
      breakDuration = runnerRtDataProvider.widgetInfo?.data?['duration'];
      breakEnd =
          breakStart?.add(Duration(minutes: breakDuration ?? 0)).toLocal();
    } catch (e) {
      // DO NOTHING
    }
  }

  void setLocalDurationRemaining() {
    if (coolDownEnd != null) {
      localDurationRemaining = coolDownEnd!.difference(DateTime.now());
    } else {
      localDurationRemaining = Duration.zero;
    }
  }

  void timerPeriodicProcess() {
    setLocalDurationRemaining();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return runnerRtDataProvider.waitForFetchData
        ? const Center(
            child: CupertinoActivityIndicator(color: AppColors.n0,),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.n0.withOpacity(0.2),
                    ),
                    color: AppColors.n0.withOpacity(0.1),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 15.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Expanded(
                        flex: 14,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.timer_rounded,
                            color: AppColors.n0,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (breakEnd != null)
                        Expanded(
                          flex: 83,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: languageProvider.getMessage(
                                      "break_stats_in", "Break starts in "),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: AppColors.n0),
                                ),
                                TextSpan(
                                  text:
                                      "${formatTime(localDurationRemaining.inSeconds)} mins",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppColors.n0,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 39.h),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 204.r,
                      height: 204.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 16.r,
                        strokeCap: StrokeCap.round,
                        value: 1,
                        color: AppColors.n0,
                        backgroundColor: Color(0xff738DD7),
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
                        if (breakDuration != null)
                          Text(
                            formatTime(breakDuration! * 60),
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
                SizedBox(height: 46.h),
                const Divider(
                  color: Color(0xffACC4E8),
                ),
                SizedBox(height: 11.h),
                if (breakStart != null && breakEnd != null)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 16,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                LunchDurationTimerIcon(),
                                DottedLine(
                                  lineLength: 20.h,
                                  direction: Axis.vertical,
                                  lineThickness: 1.r,
                                  dashLength: 3.r,
                                  dashColor: AppColors.n30,
                                ),
                                LunchDurationTimerIcon(),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 13.5.w),
                        Expanded(
                          flex: 83,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${DateFormat('hh:mm a').format(breakStart!)} : ${languageProvider.getMessage(
                                  "break_starts",
                                  "Break starts",
                                )}",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: AppColors.n0),
                              ),
                              SizedBox(height: 20.h),
                              Text(
                                "${DateFormat('hh:mm a').format(breakEnd!)} : ${languageProvider.getMessage(
                                  "break_ends",
                                  "Break ends",
                                )}",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: AppColors.n0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
  }
}

class LunchDurationTimerIcon extends StatelessWidget {
  const LunchDurationTimerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.r,
      height: 24.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.n0.withOpacity(0.2),
      ),
      padding: EdgeInsets.all(4.r),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Icon(
          Icons.access_time_rounded,
          color: AppColors.n0,
        ),
      ),
    );
  }
}
