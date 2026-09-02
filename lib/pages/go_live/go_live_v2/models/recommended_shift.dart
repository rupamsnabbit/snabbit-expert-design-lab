/// Model for shift timings
class ShiftTimings {
  final String start;
  final String end;

  ShiftTimings({
    required this.start,
    required this.end,
  });

  factory ShiftTimings.fromJson(Map<String, dynamic> json) {
    return ShiftTimings(
      start: (json['start'] as String?) ?? '00:00',
      end: (json['end'] as String?) ?? '23:59',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }

  String get displayText => '${_formatTime(start)} to ${_formatTime(end)}';

  /// Get formatted start time with AM/PM
  String get formattedStartTime => _formatTime(start);

  /// Get formatted end time with AM/PM
  String get formattedEndTime => _formatTime(end);

  /// Format time from 24-hour (HH:mm) to 12-hour with AM/PM
  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.isEmpty) return time24;

      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? parts[1] : '00';

      if (hour == 0) {
        return '12:$minute AM';
      } else if (hour < 12) {
        return '$hour:$minute AM';
      } else if (hour == 12) {
        return '12:$minute PM';
      } else {
        return '${hour - 12}:$minute PM';
      }
    } catch (e) {
      // Return original string if parsing fails
      return time24;
    }
  }
}

/// Model for a recommended shift
class RecommendedShift {
  final int rank;
  final int clusterId;
  final String clusterName;
  final int hoodId;
  final String hoodName;
  final ShiftTimings shiftTimings;
  final int duration;
  final String shiftDays;
  final double hungerScore;
  final int rateCardId;
  final int hourlyRate;
  final int estimatedMaxEarning;
  final int joiningBonus;
  final int topShiftBonus;
  final bool isTopShift;

  RecommendedShift({
    required this.rank,
    required this.clusterId,
    required this.clusterName,
    required this.hoodId,
    required this.hoodName,
    required this.shiftTimings,
    required this.duration,
    required this.shiftDays,
    required this.hungerScore,
    required this.rateCardId,
    required this.hourlyRate,
    required this.estimatedMaxEarning,
    required this.joiningBonus,
    required this.topShiftBonus,
    required this.isTopShift,
  });

  factory RecommendedShift.fromJson(Map<String, dynamic> json) {
    return RecommendedShift(
      rank: (json['rank'] as int?) ?? 0,
      clusterId: (json['cluster_id'] as int?) ?? 0,
      clusterName: (json['cluster_name'] as String?) ?? '',
      hoodId: (json['hood_id'] as int?) ?? 0,
      hoodName: (json['hood_name'] as String?) ?? '',
      shiftTimings: json['shift_timings'] != null
          ? ShiftTimings.fromJson(json['shift_timings'] as Map<String, dynamic>)
          : ShiftTimings(start: '00:00', end: '23:59'),
      duration: (json['duration'] as int?) ?? 0,
      shiftDays: (json['shift_days'] as String?) ?? '',
      hungerScore: ((json['hunger_score'] as num?) ?? 0).toDouble(),
      rateCardId: (json['rate_card_id'] as int?) ?? 0,
      hourlyRate: ((json['hourly_rate'] as num?) ?? 0).toInt(),
      estimatedMaxEarning:
          ((json['estimated_max_earning'] as num?) ?? 0).toInt(),
      joiningBonus: ((json['joining_bonus'] as num?) ?? 0).toInt(),
      topShiftBonus: ((json['top_shift_bonus'] as num?) ?? 0).toInt(),
      isTopShift: json['is_top_shift'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'cluster_id': clusterId,
      'cluster_name': clusterName,
      'hood_id': hoodId,
      'hood_name': hoodName,
      'shift_timings': shiftTimings.toJson(),
      'duration': duration,
      'shift_days': shiftDays,
      'hunger_score': hungerScore,
      'rate_card_id': rateCardId,
      'hourly_rate': hourlyRate,
      'estimated_max_earning': estimatedMaxEarning,
      'joining_bonus': joiningBonus,
      'top_shift_bonus': topShiftBonus,
      'is_top_shift': isTopShift,
    };
  }

  /// Returns formatted shift days text
  String get shiftDaysText {
    switch (shiftDays) {
      case 'MONDAY_TO_FRIDAY':
        return 'Monday to Friday';
      case 'SATURDAY_SUNDAY':
      case 'SATURDAY_TO_SUNDAY':
        return 'Saturday to Sunday';
      case 'MONDAY_TO_SUNDAY':
        return 'Monday to Sunday';
      default:
        return shiftDays;
    }
  }

  /// Returns formatted duration text
  String get durationText => '$duration hours';

  /// Returns total bonus amount
  int get totalBonus => joiningBonus + topShiftBonus;
}

/// Response model for POST /v2/go_live/recommended_shifts
class RecommendedShiftsResponse {
  final List<RecommendedShift> shifts;

  RecommendedShiftsResponse({
    required this.shifts,
  });

  factory RecommendedShiftsResponse.fromJson(Map<String, dynamic> json) {
    return RecommendedShiftsResponse(
      shifts: (json['shifts'] as List<dynamic>?)
              ?.map((e) => RecommendedShift.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Returns the top recommended shift (rank == 1)
  RecommendedShift? get topShift {
    try {
      return shifts.firstWhere((s) => s.rank == 1);
    } catch (_) {
      return shifts.isNotEmpty ? shifts.first : null;
    }
  }
}

/// Model for hood preferences for a big cluster
class BigClusterHoodPreference {
  final int clusterId;
  final List<int>
      rankedHoodIds; // Hood IDs in preference order (most preferred first)

  BigClusterHoodPreference({
    required this.clusterId,
    required this.rankedHoodIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'cluster_id': clusterId,
      'ranked_hood_ids': rankedHoodIds,
    };
  }
}

/// Request model for POST /v2/go_live/recommended_shifts
class RecommendedShiftsRequest {
  final List<int> rankedClusterIds;
  final int shiftDurationMin;
  final int shiftDurationMax;
  final int startHourRangeMin;
  final int startHourRangeMax;
  final int limit;
  final bool isWeekend;
  final String adm;
  final int? hoodId;
  final List<BigClusterHoodPreference>? bigClusterHoodPreferences;

  RecommendedShiftsRequest({
    required this.rankedClusterIds,
    required this.shiftDurationMin,
    required this.shiftDurationMax,
    required this.startHourRangeMin,
    required this.startHourRangeMax,
    required this.limit,
    this.isWeekend = false,
    this.adm = 'FOOT',
    this.hoodId,
    this.bigClusterHoodPreferences,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'ranked_cluster_ids': rankedClusterIds,
      'shift_duration': {
        'min': shiftDurationMin,
        'max': shiftDurationMax,
      },
      'start_hour_range': {
        'min': startHourRangeMin,
        'max': startHourRangeMax,
      },
      'limit': limit,
      'is_weekend': isWeekend,
      'adm': adm,
    };

    // Add hood_id only for weekend requests
    if (isWeekend && hoodId != null) {
      json['hood_id'] = hoodId!;
    }

    // Add big_cluster_hood_preferences if provided
    if (bigClusterHoodPreferences != null &&
        bigClusterHoodPreferences!.isNotEmpty) {
      json['big_cluster_hood_preferences'] =
          bigClusterHoodPreferences!.map((p) => p.toJson()).toList();
    }

    return json;
  }
}
