/// Represents a shift time bucket configurable from Firebase Remote Config
/// Each bucket defines a display text and start hour range for API
class ShiftTimeBucket {
  final String timeText; // Displayed text like "Morning" or "Afternoon"
  final int startHourRangeMin; // Minimum start hour (e.g., 6 for Morning)
  final int startHourRangeMax; // Maximum start hour (e.g., 10 for Morning)

  ShiftTimeBucket({
    required this.timeText,
    required this.startHourRangeMin,
    required this.startHourRangeMax,
  });

  // For Firebase Remote Config integration
  factory ShiftTimeBucket.fromJson(Map<String, dynamic> json) {
    final startHourRange =
        json['start_hour_range'] as Map<String, dynamic>? ?? {};
    return ShiftTimeBucket(
      timeText: json['time_text'] as String? ?? '',
      startHourRangeMin: startHourRange['min'] as int? ?? 6,
      startHourRangeMax: startHourRange['max'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time_text': timeText,
      'start_hour_range': {
        'min': startHourRangeMin,
        'max': startHourRangeMax,
      },
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTimeBucket &&
          runtimeType == other.runtimeType &&
          timeText == other.timeText &&
          startHourRangeMin == other.startHourRangeMin &&
          startHourRangeMax == other.startHourRangeMax;

  @override
  int get hashCode =>
      Object.hash(timeText, startHourRangeMin, startHourRangeMax);
}
