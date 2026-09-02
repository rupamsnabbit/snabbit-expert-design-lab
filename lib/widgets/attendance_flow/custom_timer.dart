import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';

class CircularTimerWidget extends StatefulWidget {
  final String? utcTimeString; // Format: "HH:MM:SS" in UTC
  final Color backgroundColor;
  final Color? lateBackgroundColor;
  final double strokeWidth;
  final String? labelText;
  final String? lateText;
  final Color? labelTextColor;
  final Color? lateTextColor;
  final double width;
  final double height;
  final String sharedPrefsKeyPrefix;
  final bool persistDuration;
  final int? lateCeilingValue;
  final bool? showLateBlinking;
  final VoidCallback? onTimerComplete;
  final Function(int remainingSeconds)? tickCallback;

  const CircularTimerWidget({
    super.key,
    this.utcTimeString,
    required this.backgroundColor,
    this.lateBackgroundColor,
    this.strokeWidth = 16.0,
    this.labelText,
    this.lateText,
    this.labelTextColor,
    this.lateTextColor,
    this.width = 160.0,
    this.height = 160.0,
    this.sharedPrefsKeyPrefix = "timer_duration",
    this.persistDuration = false,
    this.lateCeilingValue,
    this.showLateBlinking,
    this.onTimerComplete,
    this.tickCallback,
  });

  @override
  CircularTimerWidgetState createState() => CircularTimerWidgetState();
}

class CircularTimerWidgetState extends State<CircularTimerWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  int? _totalDurationSeconds;
  bool _isInitialized = false;
  String? _effectiveTimeString;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _isBlinking = false;
  bool _hasCompletedTimer = false;

  @override
  void initState() {
    super.initState();

    // Set up animation controller for blinking
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // slower blinking
    );

    // Create tween animation for smoother blinking effect
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
        CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut));

    // Have the animation repeat back and forth
    _blinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _blinkController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _blinkController.forward();
      }
    });

    _initializeTimer();
  }

  Future<void> _initializeTimer() async {
    if (widget.utcTimeString == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    //  think about cleaning up shared preferences. Job timer will have lot of data
    final today = "${now.year}-${now.month}-${now.day}";
    final durationKey = "${widget.sharedPrefsKeyPrefix}_seconds_$today";
    final persistedTimeKey =
        "persisted_${widget.sharedPrefsKeyPrefix}_time_$today";

    // Determine which time string to use
    if (widget.persistDuration && prefs.containsKey(persistedTimeKey)) {
      // Use the persisted time string if available
      _effectiveTimeString = prefs.getString(persistedTimeKey);
    } else {
      // Otherwise use the provided time string
      _effectiveTimeString = widget.utcTimeString;

      // If persistence is enabled, store the time string
      if (widget.persistDuration) {
        await prefs.setString(persistedTimeKey, widget.utcTimeString!);
      }
    }

    // Parse the effective attendance time from UTC string
    final timeParts = _effectiveTimeString!.split(':');
    if (timeParts.length != 3) return;

    // Get the current date in UTC
    final nowUtc = DateTime.now().toUtc();
    final currentDateUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    // Create attendance time as UTC
    final attendanceTimeUTC = DateTime.utc(
        currentDateUtc.year,
        currentDateUtc.month,
        currentDateUtc.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]));

    // Convert to local for calculations
    final attendanceTimeLocal = attendanceTimeUTC.toLocal();

    // Calculate or retrieve total duration in seconds
    if (prefs.containsKey(durationKey)) {
      _totalDurationSeconds = prefs.getInt(durationKey);
    } else {
      // First calculation - abs difference in minutes
      final initialDifference = attendanceTimeLocal.difference(now);
      final initialDurationSeconds = (initialDifference.inSeconds.abs()) +
          1; // +1 to avoid division by zero
      _totalDurationSeconds = initialDurationSeconds;
      await prefs.setInt(durationKey, initialDurationSeconds);
    }

    _updateTimerState(attendanceTimeLocal);
    _startTimer(attendanceTimeLocal);

    setState(() {
      _isInitialized = true;
    });
  }

  void _updateTimerState(DateTime attendanceTime) {
    final now = DateTime.now();

    // If already in blinking state, don't update the timer further
    if (_isBlinking && widget.showLateBlinking == true) {
      return;
    }

    // Calculate difference between attendance time and now
    final difference = attendanceTime.difference(now);
    _remainingTime = difference;

    // Call onTimerComplete callback when timer becomes negative for the first time
    if (difference.isNegative &&
        !_hasCompletedTimer &&
        widget.onTimerComplete != null) {
      _hasCompletedTimer = true;
      widget.onTimerComplete!();
    }

    // Start blinking if we've reached zero and showLateNegative is true
    if (difference.isNegative &&
        widget.showLateBlinking == true &&
        !_isBlinking) {
      // Fix the remaining time at zero/negative threshold for consistent display
      _remainingTime = const Duration(seconds: -1);
      _startBlinking();
    }

    if (mounted) setState(() {});
  }

  void _startTimer(DateTime attendanceTime) {
    _timer?.cancel(); // Cancel existing timer if any
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTimerState(attendanceTime);
      }
      try {
        widget.tickCallback?.call(_remainingTime.inSeconds);
      } catch (e) {
        // DO NOTHING
      }
    });
  }

  void _startBlinking() {
    _isBlinking = true;
    _blinkController.forward();
  }

  @override
  void dispose() {
    // Only cancel timer if it has been initialized to prevent LateInitializationError
    _timer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    // If showLateNegative is true and time is negative, show 00:00
    if (widget.showLateBlinking == true && totalSeconds < 0) {
      return '00:00';
    }

    final isNegative = totalSeconds < 0;
    final absSeconds = totalSeconds.abs();

    final minutes = (absSeconds / 60).floor();
    final seconds = absSeconds % 60;

    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return isNegative ? '-$formattedTime' : formattedTime;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _totalDurationSeconds == null) {
      return const SizedBox();
    }

    // Force isLate to true when in blinking state
    final bool isLate = _isBlinking && widget.showLateBlinking == true
        ? true
        : (widget.lateCeilingValue != null
            ? _remainingTime.inSeconds <= widget.lateCeilingValue!
            : _remainingTime.isNegative);

    // Get the formatted time
    final timeText = _formatTime(_remainingTime.inSeconds);

    // Determine if blinking should be active
    final shouldBlink =
        widget.showLateBlinking == true && _remainingTime.isNegative;

    // Create the widget content
    final timerWidget = Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: widget.width.r,
          height: widget.height.r,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(isLate ? 0 : 3.14),
            child: CircularProgressIndicator(
              strokeWidth: widget.strokeWidth,
              // When in blinking state, always show the progress indicator at 100%
              value: _isBlinking && widget.showLateBlinking == true
                  ? 0
                  : (_totalDurationSeconds != null && _totalDurationSeconds! > 0
                      ? _remainingTime.inSeconds.abs() / _totalDurationSeconds!
                      : 0),
              color: isLate
                  ? widget.lateBackgroundColor ?? widget.backgroundColor
                  : widget.backgroundColor,
              backgroundColor: isLate
                  ? widget.lateTextColor
                  : widget.labelTextColor ?? AppColors.n0,
            ),
          ),
        ),
        SizedBox(
          width: widget.width.r,
          height: widget.height.r,
          child: Padding(
            padding: EdgeInsets.all(15.r),
            child: Center(
              child: FittedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((isLate ? widget.lateText : widget.labelText) != null)
                      Text(
                        isLate ? widget.lateText! : widget.labelText!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isLate
                                  ? widget.lateTextColor
                                  : widget.labelTextColor,
                            ),
                      ),
                    SizedBox(height: 4.h),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: isLate
                                ? widget.lateTextColor
                                : (widget.labelTextColor ?? AppColors.n90),
                          ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // Apply the animated opacity to the entire widget if needed
    return shouldBlink
        ? AnimatedBuilder(
            animation: _blinkAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _blinkAnimation.value,
                child: timerWidget,
              );
            },
          )
        : timerWidget;
  }
}
