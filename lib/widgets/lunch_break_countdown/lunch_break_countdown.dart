import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/lunch_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/lunch_break_countdown/countdown_timer_widget.dart';
import 'package:snabbit_runner/widgets/lunch_time/lunch_time_refusal.dart';

import '../../utils/constants.dart';

class LunchBreakCountdown extends StatefulWidget {
  const LunchBreakCountdown({super.key});

  @override
  State<LunchBreakCountdown> createState() => _LunchBreakCountdownState();
}

class _LunchBreakCountdownState extends State<LunchBreakCountdown> {
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
  bool isCooldownComplete = false;

  ///[data] will store the data from [runnerRtDataProvider].widgetInfo?.data
  late Map<String, dynamic> data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    data = runnerRtDataProvider.widgetInfo?.data ?? {};
    setup();
    setLocalDurationRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_timer?.isActive == true) {
        timerPeriodicProcess();
        // What the actual hell is this??
        if (!extraPollAfterTimeEnd &&
            localDurationRemaining.inSeconds == secondsAfterBreakApiCall) {
          extraPollAfterTimeEnd = true;
          runnerRtDataProvider.fetchDataNow();
        }
      }
      if (localDurationRemaining.inSeconds == 0) {
        t.cancel();
      }
    });
  }

  void setup() async {
    try {
      coolDownStart = DateTime.tryParse(data['cooldown_start_time'] ?? "")?.toLocal();

      coolDownDuration = Duration(minutes: data['cooldown_duration'] ?? 0);

      if (coolDownDuration != null) {
        coolDownEnd = coolDownStart?.add(coolDownDuration ?? Duration.zero);
      }
      breakStart = DateTime.tryParse(data['start_time'] ?? "")?.toLocal();
      breakDuration =
          data['duration'] ?? 0 + (coolDownDuration?.inMinutes ?? 0);
      breakEnd = breakStart?.add(
        Duration(
          minutes: breakDuration ?? 0,
        ),
      );
    } catch (e) {
      // DO NOTHING
    }
  }

  void setLocalDurationRemaining() {
    if (coolDownEnd != null) {
      final newDuration = coolDownEnd!.difference(DateTime.now());

      // Check if cooldown is complete or newly completed
      if (newDuration.inSeconds <= 0 && !isCooldownComplete) {
        setState(() {
          isCooldownComplete = true;
        });
      }

      localDurationRemaining =
          newDuration.isNegative ? Duration.zero : newDuration;
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

  String _formatCountdownTime() {
    if (localDurationRemaining.inSeconds <= 0) {
      return "00:00";
    }

    final minutes =
        (localDurationRemaining.inMinutes).toString().padLeft(2, '0');
    final seconds =
        (localDurationRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return runnerRtDataProvider.waitForFetchData
        ? const Center(
            child: CupertinoActivityIndicator(
              color: AppColors.n0,
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Timer circle
              if (breakStart != null)
                CountdownTimerWidget(
                  startTime: breakStart!,
                  duration: Duration(minutes: breakDuration ?? 0),
                  canStart: isCooldownComplete,
                  greenStateDuration:
                      Duration(minutes: data['green_state_duration'] ?? 0)
                          .inSeconds,
                  amberStateDuration:
                      Duration(minutes: data['amber_state_duration'] ?? 0)
                          .inSeconds,
                  redStateDuration:
                      Duration(minutes: data['red_state_duration'] ?? 0)
                          .inSeconds,
                ),

              // Cooldown Timer
              isCooldownComplete
                  ? const SizedBox()
                  : Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                      ),
                      margin: EdgeInsets.only(
                        top: 32.h,
                      ),
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: AppColors.n60.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: AppColors.n90,
                            size: 18,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            isCooldownComplete
                                ? languageProvider.getMessage(
                                    "break_started",
                                    "Break started",
                                  )
                                : "${languageProvider.getMessage(
                                    "break_starts_in_time",
                                    "Break starts in",
                                  )} ${_formatCountdownTime()}",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.n90,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
              // End break button
              Container(
                width: 1.sw,
                margin: EdgeInsets.only(
                  top: 32.h,
                ),
                // height: 47.h,
                child: ElevatedButton(
                  onPressed: endMyBreak,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.r40,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      "end_my_break",
                      "End my break",
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.n0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ],
          );
  }

  void endMyBreak() {
    showLunchTimeRefusalBottomSheet(
      context,
      onPositive: () async {
        try {
          ClevertapSetup.logEvent(
            TrackingEvents.breakConfirmEndButtonClicked,
            {},
          );
          Response? response = await LunchHttp.runnersMeBreakEnd();
          if (response != null && response.statusCode == 200) {
            // SUCCESS
          } else {
            if (mounted) {
              showSnackbar(
                  context, "Break ending failed - ${response?.statusCode}");
            }
          }
        } catch (e) {
          if (mounted) {
            showSnackbar(context, "Break ending failed - $e");
          }
        }
        runnerRtDataProvider.setWaitForFetchData(true);
        setState(() {});
        runnerRtDataProvider.fetchDataNow();
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      onNegative: () {
        // Check if widget is still mounted before using context
        if (mounted && context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}
