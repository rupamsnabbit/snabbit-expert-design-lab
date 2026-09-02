/// Mock data for Go Live V2 APIs
/// Used for testing and development purposes
///
/// To enable mock mode, set `GoLiveV2Http.useMockData = true` in your code
/// or call `GoLiveV2Http.enableMockMode()` / `GoLiveV2Http.disableMockMode()`

class GoLiveV2MockData {
  /// Simulated network delay for mock responses
  static const Duration mockDelay = Duration(milliseconds: 800);

  /// Mock response for GET /v2/go_live/clusters_by_tc
  static Map<String, dynamic> getClustersResponse() {
    return {
      'clusters': [
        // tc_id = 5 (same as partner_tc_id) - sorted first
        {
          'id': 12,
          'name': 'HSR Layout',
          'tc_id': 5,
          'hunger_score': 0.95,
          'distance': 4300.0,
        },
        {
          'id': 22,
          'name': 'Whitefield',
          'tc_id': 5,
          'hunger_score': 0.85,
          'distance': 1200.0,
        },
        {
          'id': 8,
          'name': 'Koramangala',
          'tc_id': 5,
          'hunger_score': 0.82,
          'distance': 500.0,
        },
        {
          'id': 25,
          'name': 'Brigade Road',
          'tc_id': 5,
          'hunger_score': 0.68,
          'distance': 1500.0,
        },
        // tc_id = 7 (different from partner_tc_id) - sorted after
        {
          'id': 15,
          'name': 'Indiranagar',
          'tc_id': 7,
          'hunger_score': 0.78,
          'distance': 2500.0,
        },
        {
          'id': 18,
          'name': 'MG Road',
          'tc_id': 7,
          'hunger_score': 0.72,
          'distance': 1400.0,
        },
        {
          'id': 30,
          'name': 'Yellahanka',
          'tc_id': 7,
          'hunger_score': 0.65,
          'distance': 4600.0,
        },
      ],
      'partner_tc_id': 5,
      'adm_options': ['FOOT', 'CYCLE', 'ECYCLE', 'YULU', 'MOTORCYCLE'],
    };
  }

  /// Mock response for POST /v2/go_live/recommended_shifts (weekday)
  static Map<String, dynamic> getWeekdayRecommendedShiftsResponse() {
    return {
      'shifts': [
        {
          'rank': 1,
          'cluster_id': 12,
          'cluster_name': 'HSR Layout',
          'hood_id': 45,
          'hood_name': 'HSR Sector 2',
          'shift_timings': {
            'start': '09:00',
            'end': '17:00',
          },
          'duration': 8,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.95,
          'rate_card_id': 15,
          'hourly_rate': 125,
          'estimated_max_earning': 23100,
          'joining_bonus': 500,
          'top_shift_bonus': 1000,
        },
        {
          'rank': 2,
          'cluster_id': 12,
          'cluster_name': 'HSR Layout',
          'hood_id': 46,
          'hood_name': 'HSR Sector 3',
          'shift_timings': {
            'start': '10:00',
            'end': '16:00',
          },
          'duration': 6,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.90,
          'rate_card_id': 15,
          'hourly_rate': 125,
          'estimated_max_earning': 19800,
          'joining_bonus': 500,
          'top_shift_bonus': 0,
        },
        {
          'rank': 3,
          'cluster_id': 8,
          'cluster_name': 'Koramangala',
          'hood_id': 52,
          'hood_name': '2nd Block',
          'shift_timings': {
            'start': '11:00',
            'end': '19:00',
          },
          'duration': 8,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.85,
          'rate_card_id': 16,
          'hourly_rate': 120,
          'estimated_max_earning': 22000,
          'joining_bonus': 500,
          'top_shift_bonus': 0,
        },
        {
          'rank': 4,
          'cluster_id': 8,
          'cluster_name': 'Koramangala',
          'hood_id': 53,
          'hood_name': '4th Block',
          'shift_timings': {
            'start': '12:00',
            'end': '18:00',
          },
          'duration': 6,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.82,
          'rate_card_id': 16,
          'hourly_rate': 118,
          'estimated_max_earning': 18500,
          'joining_bonus': 400,
          'top_shift_bonus': 0,
        },
        {
          'rank': 5,
          'cluster_id': 15,
          'cluster_name': 'Indiranagar',
          'hood_id': 60,
          'hood_name': '100 Feet Road',
          'shift_timings': {
            'start': '08:00',
            'end': '16:00',
          },
          'duration': 8,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.78,
          'rate_card_id': 17,
          'hourly_rate': 115,
          'estimated_max_earning': 21000,
          'joining_bonus': 500,
          'top_shift_bonus': 0,
        },
        {
          'rank': 6,
          'cluster_id': 15,
          'cluster_name': 'Indiranagar',
          'hood_id': 61,
          'hood_name': '12th Main',
          'shift_timings': {
            'start': '14:00',
            'end': '20:00',
          },
          'duration': 6,
          'shift_days': 'MONDAY_TO_FRIDAY',
          'hunger_score': 0.75,
          'rate_card_id': 17,
          'hourly_rate': 112,
          'estimated_max_earning': 17500,
          'joining_bonus': 400,
          'top_shift_bonus': 0,
        },
      ],
    };
  }

  /// Mock response for POST /v2/go_live/recommended_shifts (weekend)
  /// Parameters allow customizing the response based on user selections
  static Map<String, dynamic> getWeekendRecommendedShiftsResponse({
    required String startTime,
    required String endTime,
    required int durationHours,
  }) {
    return {
      'shifts': [
        {
          'rank': 1,
          'cluster_id': 12,
          'cluster_name': 'HSR Layout',
          'hood_id': 47,
          'hood_name': 'HSR Sector 4',
          'shift_timings': {
            'start': startTime,
            'end': endTime,
          },
          'duration': durationHours,
          'shift_days': 'SATURDAY_TO_SUNDAY',
          'hunger_score': 0.92,
          'rate_card_id': 18,
          'hourly_rate': 150,
          'estimated_max_earning':
              28500, // Higher than weekday (23100) = +5400 weekend bonus
          'joining_bonus': 600,
          'top_shift_bonus': 1200,
        },
        {
          'rank': 2,
          'cluster_id': 12,
          'cluster_name': 'HSR Layout',
          'hood_id': 48,
          'hood_name': 'HSR Sector 5',
          'shift_timings': {
            'start': startTime,
            'end': endTime,
          },
          'duration': durationHours,
          'shift_days': 'SATURDAY_TO_SUNDAY',
          'hunger_score': 0.88,
          'rate_card_id': 18,
          'hourly_rate': 145,
          'estimated_max_earning':
              26800, // Higher than weekday (23100) = +3700 weekend bonus
          'joining_bonus': 550,
          'top_shift_bonus': 800,
        },
        {
          'rank': 3,
          'cluster_id': 8,
          'cluster_name': 'Koramangala',
          'hood_id': 54,
          'hood_name': '5th Block',
          'shift_timings': {
            'start': startTime,
            'end': endTime,
          },
          'duration': durationHours,
          'shift_days': 'SATURDAY_TO_SUNDAY',
          'hunger_score': 0.85,
          'rate_card_id': 19,
          'hourly_rate': 140,
          'estimated_max_earning':
              25200, // Higher than weekday (23100) = +2100 weekend bonus
          'joining_bonus': 500,
          'top_shift_bonus': 0,
        },
      ],
    };
  }

  /// Mock response for POST /v2/go_live/verify_shift
  static Map<String, dynamic> getVerifyShiftResponse(
      {bool isAvailable = true}) {
    return {
      'is_available': isAvailable,
      'errors': <Map<String, dynamic>>[],
    };
  }

  /// Mock response for POST /v2/go_live/confirm_shift
  static Map<String, dynamic> getConfirmShiftResponse({bool success = true}) {
    return {
      'success': success,
      'message':
          success ? 'Shift confirmed successfully' : 'Failed to confirm shift',
      'errors': <Map<String, dynamic>>[],
    };
  }
}
