import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/lunch_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/lunch_break_countdown/countdown_timer_widget.dart';
import 'package:snabbit_runner/widgets/lunch_time/lunch_time_refusal.dart';

import '../../utils/constants.dart';

class PreMarkArrival extends StatefulWidget {
  const PreMarkArrival({super.key, required this.data});

  ///[data] will store the data from [runnerRtDataProvider].widgetInfo?.data
  final Map<String, dynamic> data;

  @override
  State<PreMarkArrival> createState() => _PreMarkArrivalState();
}

class _PreMarkArrivalState extends State<PreMarkArrival> {
  bool init = true;
  Duration localDurationRemaining = Duration.zero;
  late RunnerRtDataProvider runnerRtDataProvider;
  late LanguageProvider languageProvider;
  DateTime? _breakEnd;
  DateTime? _breakStart;

  Duration? _expectedEta;
  Timer? _timer;
  bool _extraPollAfterTimeEnd = false;
  bool _isBreakComplete = false;

  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }

    setup();
    setLocalDurationRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_timer?.isActive == true) {
        timerPeriodicProcess();
      }
      if (localDurationRemaining.inSeconds == 0 && !_extraPollAfterTimeEnd) {
        t.cancel();
        _extraPollAfterTimeEnd = true;
        endMyBreak();
      }
    });
  }

  void setup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jobId = prefs.getInt(AppStrings.preMarkArrivalJobId);
      final startTime = prefs.getString(AppStrings.preMarkArrivalStartTime);
      final endTime = prefs.getString(AppStrings.preMarkArrivalEndTime);
      final storedBreak = prefs.getInt(AppStrings.preMarkArrivalBreakDuration);
      DateTime? start = DateTime.tryParse(startTime ?? '');
      DateTime? end = DateTime.tryParse(endTime ?? '');

      final currentEta = widget.data[AppStrings.expectedEta] ?? 0;
      final currentBreak = widget.data[AppStrings.breakDuration] ?? 0;
      _expectedEta = Duration(minutes: currentEta);

      int breakDuration = currentBreak * 60;
      _breakStart = start ?? DateTime.now();

      if (jobId == widget.data[AppStrings.jobId] && start != null && end != null) {
        // Check if expected_eta or break_duration changed
        if (storedBreak != currentBreak) {
          final expectedEndTime = start.add(Duration(minutes: currentBreak));

          final timeNow = DateTime.now();
          if (expectedEndTime.isAfter(timeNow)) {
            prefs.setInt(AppStrings.preMarkArrivalBreakDuration, currentBreak);
            if (currentBreak > storedBreak) {
              _breakEnd = timeNow.add(
                Duration(minutes: (currentBreak - storedBreak)),
              );
              prefs.setString(AppStrings.preMarkArrivalEndTime,
                  _breakEnd!.toIso8601String());
            } else {
              _breakEnd = expectedEndTime;
              prefs.setString(AppStrings.preMarkArrivalEndTime,
                  _breakEnd!.toIso8601String());
            }
          }
        } else {
          final timeNow = DateTime.now();
          breakDuration = end.difference(timeNow).inSeconds;
          _breakEnd = timeNow.add(Duration(seconds: breakDuration));
        }
      } else {
        prefs.setInt(AppStrings.preMarkArrivalJobId, widget.data[AppStrings.jobId]);
        prefs.setInt(AppStrings.preMarkArrivalBreakDuration, currentBreak);
        final timeNow = DateTime.now();
        prefs.setString(
            AppStrings.preMarkArrivalStartTime, timeNow.toIso8601String());
        _breakEnd = timeNow.add(Duration(seconds: breakDuration));

        prefs.setString(
            AppStrings.preMarkArrivalEndTime, _breakEnd!.toIso8601String());
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  void setLocalDurationRemaining() {
    if (_breakEnd != null) {
      final newDuration = _breakEnd!.difference(DateTime.now());

      // Check if cooldown is complete or newly completed
      if (newDuration.inSeconds <= 0 && !_isBreakComplete) {
        setState(() {
          _isBreakComplete = true;
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

  String _formatEtaTime() {
    if (_expectedEta == null || (_expectedEta?.inSeconds ?? 0) <= 0) {
      return "00:00";
    }

    final minutes = (_expectedEta?.inMinutes).toString().padLeft(2, '0');
    final seconds = (_expectedEta!.inSeconds % 60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return runnerRtDataProvider.waitForFetchData || init
        ? const Center(
            child: CupertinoActivityIndicator(
              color: AppColors.n0,
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(AssetConstants.markArrivalBuffer),
                  Positioned(
                    right: 40.w,
                    child: FittedBox(
                      child: Text(
                        "${widget.data[AppStrings.breakDuration] ?? 0} ${languageProvider.getMessage("mins_to_rest", "min ka aaram").toUpperCase()}",
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.n0,
                            ),
                        softWrap: true,
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(
                height: 16.h,
              ),
              // Timer circle
              Container(
                height: 160.h,
                width: 160.w,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.n60,
                      width: 18.r,
                    )),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        languageProvider.getMessage('reach_in', "REACH IN"),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.n60,
                            ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Flexible(
                      child: Text(
                        _formatEtaTime(),
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: AppColors.n60,
                                  fontSize: 32.sp,
                                ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cooldown Timer
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 16.h,
                ),
                margin: EdgeInsets.only(
                  top: 16.h,
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
                    SvgPicture.asset(
                      AssetConstants.countdown,
                      height: 18.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "${languageProvider.getMessage(
                        "rest_ends_in",
                        "Aaram ends in",
                      )} ${_isBreakComplete ? '00:00' : _formatCountdownTime()}",
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  top: 16.h,
                ),
                // height: 47.h,
                child: ElevatedButton(
                  onPressed: loading ? null : endMyBreak,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      "ready",
                      "I am ready",
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

  void endMyBreak() async {
    try {
      setState(() {
        loading = true;
      });
      final response = await LunchHttp.skipBuffer(widget.data[AppStrings.jobId]);
      if (response?.statusCode == 200) {
        ClevertapSetup.logEvent(TrackingEvents.endQuickBreak, {
          "break_start_time": _breakStart?.toIso8601String(),
          "actual_break_end_time":_breakEnd?.toIso8601String(),
          "current_time":DateTime.now().toIso8601String(),
        });
        runnerRtDataProvider.setWaitForFetchData(true);
        setState(() {});
        runnerRtDataProvider.fetchDataNow();
      } else {
        ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            final error = responseError.errors?.first;
            showSnackbar(context,
                "${error?.errorMessageCode} - ${error?.title}: ${error?.message}");
          },
        );
      }
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      showSnackbar(context, "Something went wrong: $e");
    }
  }
}
