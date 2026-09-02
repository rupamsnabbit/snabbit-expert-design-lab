import 'package:snabbit_runner/models/timer_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CountdownTimerWidget extends StatefulWidget {
  final DateTime startTime;
  final Duration duration;
  final bool canStart;
  final int? greenStateDuration;
  final int? amberStateDuration;
  final int? redStateDuration;

  const CountdownTimerWidget({
    super.key,
    required this.startTime,
    required this.duration,
    this.canStart = false,
    this.greenStateDuration,
    this.amberStateDuration,
    this.redStateDuration,
  });

  @override
  CountdownTimerWidgetState createState() => CountdownTimerWidgetState();
}

class CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  late DateTime _endTime;
  int _remainingTimeInSeconds = 0;
  int _totalDurationInSeconds = 0;

  String _currentLabel = "TIME REMAINING";
  late LanguageProvider _languageProvider;
  late RunnerRtDataProvider _runnerRtDataProvider;
  bool _isInitialized = false;
  bool _isRunning = false;

  late TimerState _currentTimerState;

  @override
  void didChangeDependencies() {
    if (!_isInitialized) {
      _isInitialized = true;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      _currentLabel = _languageProvider.getMessage(
        "time_remaining_capital",
        "TIME REMAINING",
      );
      // _isInitialized = true;
      // Future.delayed(
      //   Duration(seconds: _remainingTimeInSeconds),
      //   () {
      //     // Call fetchDataNow() when timer reaches zero
      //     if (_remainingTimeInSeconds == 0) {
      //       _runnerRtDataProvider.fetchDataNow();
      //     }
      //   },
      // );

      // setState(() {});
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start or stop timer based on canStart property change
    if (widget.canStart != oldWidget.canStart) {
      if (widget.canStart && !_isRunning) {
        _startTimer();
      } else if (!widget.canStart && _isRunning) {
        _stopTimer();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Calculate end time
    _endTime = widget.startTime.add(widget.duration);

    // Calculate total duration in seconds
    _totalDurationInSeconds = widget.duration.inSeconds;

    // Initial calculation of remaining time
    _calculateRemainingTime();
    _updateCurrentState();

    // Start the timer only if canStart is true
    if (widget.canStart) {
      _startTimer();
    }
  }

  void _startTimer() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemainingTime();
      _updateCurrentState();
    });
  }

  void _updateCurrentState() {
    TimerState? newState;

    if (widget.redStateDuration != null &&
        _remainingTimeInSeconds <= widget.redStateDuration!) {
      newState = redState;
    } else if (widget.amberStateDuration != null &&
        _remainingTimeInSeconds <= widget.amberStateDuration!) {
      newState = amberState;
    } else if (widget.greenStateDuration != null &&
        _remainingTimeInSeconds <= widget.greenStateDuration!) {
      newState = greenState;
    } else {
      newState = initialState;
    }
    if (newState != null) {
      setState(() {
        _currentTimerState = newState!;
      });
    }
  }

  void _stopTimer() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    final difference = _endTime.difference(now).inSeconds;

    setState(() {
      // If difference is negative, set remaining time to 0
      _remainingTimeInSeconds = difference > 0 ? difference : 0;
    });

    // If timer reached 0, stop the timer and fetch data
    if (_remainingTimeInSeconds <= 0) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress (0 to 1)
    final progress = widget.canStart && _totalDurationInSeconds > 0
        ? (_remainingTimeInSeconds / _totalDurationInSeconds)
        : 0.0;

    // Format the remaining time as MM:SS
    final timeText = widget.canStart
        ? _formatTime(_remainingTimeInSeconds)
        : _formatTime(_totalDurationInSeconds);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            _remainingTimeInSeconds <= 0
                ? _languageProvider.getMessage(
                    "break_has_ended",
                    "Your break has ended",
                  )
                : _currentTimerState.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.n90,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          height: 32.h,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160.r,
              height: 160.r,
              child: CircularProgressIndicator(
                strokeWidth: 18.r,
                value: 1 - progress,
                color: _currentTimerState.foregroundColor,
                backgroundColor: _currentTimerState.backgroundColor,
              ),
            ),
            SizedBox(
              width: 160.r,
              height: 160.r,
              child: Padding(
                padding: EdgeInsets.all(15.r),
                child: Center(
                  child: FittedBox(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentLabel,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: _currentTimerState.foregroundColor,
                                  ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          timeText,
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                color: _currentTimerState.foregroundColor,
                                fontSize: 32.sp,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TimerState get initialState => const TimerState(
        foregroundColor: AppColors.n60,
        backgroundColor: AppColors.n60,
        title: "Find a comfortable place",
      );

  // // Green state: More than 5 minutes and 1 second left
  TimerState get greenState => const TimerState(
        foregroundColor: AppColors.g50,
        backgroundColor: AppColors.g20,
        title: "Break started",
      );

  // // Yellow state: More than 6 seconds left (up to 5 minutes and 1 second)
  TimerState get amberState => const TimerState(
        foregroundColor: AppColors.y60,
        backgroundColor: AppColors.y40,
        title: "Break ending soon",
      );

  // // Red state: 6 seconds or less left
  TimerState get redState => const TimerState(
      foregroundColor: AppColors.r50,
      backgroundColor: AppColors.r30,
      title: "Break ending soon");
}
