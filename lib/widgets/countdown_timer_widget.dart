import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class ContestTimerWidget extends StatefulWidget {
  final DateTime endDateTime;
  final String? messageKey;
  final String? fallbackMessage;
  final Map<String, String>? messageParams;
  final String? endedMessageKey;
  final String? endedFallbackMessage;
  final Map<String, String>? endedMessageParams;
  final String Function(DateTime date)? activeDateFormatter;
  final String Function(DateTime date)? endedDateFormatter;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final VoidCallback? onTimerComplete;

  const ContestTimerWidget({
    super.key,
    required this.endDateTime,
    this.messageKey,
    this.fallbackMessage,
    this.messageParams,
    this.endedMessageKey,
    this.endedFallbackMessage,
    this.endedMessageParams,
    this.activeDateFormatter,
    this.endedDateFormatter,
    this.padding,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.textStyle,
    this.onTimerComplete,
  });

  @override
  State<ContestTimerWidget> createState() => _ContestTimerWidgetState();
}

class _ContestTimerWidgetState extends State<ContestTimerWidget> {
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTimeRemaining();
      }
    });
  }

  void _updateTimeRemaining() {
    final now = DateTime.now();
    final difference = widget.endDateTime.difference(now);

    setState(() {
      _timeRemaining = difference;

      // Check if timer has completed
      if (difference.isNegative && !_isCompleted) {
        _isCompleted = true;
        widget.onTimerComplete?.call();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final now = DateTime.now();
    final targetDate = now.add(duration);
    // Active state date string (e.g., "9th October")
    final formatter = widget.activeDateFormatter ?? _defaultActiveDateFormatter;
    return formatter(targetDate);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: true);

    return Container(
      padding: widget.padding ??
          EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.borderColor ?? AppColors.n30,
          width: widget.borderWidth ?? 1.2.r,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 5.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon ?? Icons.timer_outlined,
            size: widget.iconSize ?? 16.sp,
            color: widget.iconColor ?? const Color(0xff1D2129),
          ),
          SizedBox(width: 4.w),
          Text(
            _buildMessage(languageProvider),
            style: widget.textStyle ??
                Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 10.sp,
                      color: const Color(0xff1D2129),
                      fontWeight: FontWeight.w700,
                    ),
          ),
        ],
      ),
    );
  }

  String _buildMessage(LanguageProvider languageProvider) {
    if (_isCompleted) {
      // Contest has ended - show ended message
      final endedFormatter =
          widget.endedDateFormatter ?? _defaultEndedDateFormatter;
      final endDateString = endedFormatter(widget.endDateTime);
      final endedParams = {
        'date': endDateString,
        ...?widget.endedMessageParams,
      };

      if (widget.endedMessageKey != null) {
        return languageProvider.getFormattedMessage(
          widget.endedMessageKey!,
          widget.endedFallbackMessage ?? "Contest ended on $endDateString",
          endedParams,
        );
      }

      return widget.endedFallbackMessage ?? "Contest ended on $endDateString";
    } else {
      // Contest is still active - show countdown message
      final timeString = _formatDuration(_timeRemaining);
      final params = {
        'time': timeString,
        ...?widget.messageParams,
      };

      if (widget.messageKey != null) {
        return languageProvider.getFormattedMessage(
          widget.messageKey!,
          widget.fallbackMessage ?? "Ends on - $timeString",
          params,
        );
      }

      return widget.fallbackMessage ?? "Ends on - $timeString";
    }
  }

  // Default: 9th October (ordinal, no year)
  String _defaultActiveDateFormatter(DateTime date) {
    final day = date.day;
    final month = _monthName(date.month);
    final suffix = _ordinalSuffix(day);
    return "$day$suffix $month";
  }

  // Default: 9 October 2025 (no ordinal, with year)
  String _defaultEndedDateFormatter(DateTime date) {
    final day = date.day;
    final month = _monthName(date.month);
    final year = date.year;
    return "$day $month $year";
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1:
        return "st";
      case 2:
        return "nd";
      case 3:
        return "rd";
      default:
        return "th";
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
