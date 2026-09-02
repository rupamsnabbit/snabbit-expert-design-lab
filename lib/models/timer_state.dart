import 'package:flutter/material.dart';

/// Represents a state of the timer with specific colors for different time thresholds
class TimerState {

  /// The foreground color (progress indicator track color)
  final Color foregroundColor;

  /// The background color (progress indicator background color)
  final Color backgroundColor;

  final String title;

  const TimerState({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.title,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimerState &&
        other.foregroundColor == foregroundColor &&
        other.backgroundColor == backgroundColor &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(
        foregroundColor,
        backgroundColor,
        title,
      );
}

