import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/recommended_shift.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Helper class for CleverTap tracking in Go Live V2 flow
class GoLiveV2Tracking {
  GoLiveV2Tracking._();

  /// Common attributes helper
  static Map<String, dynamic> _getCommonAttributes() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        final userProfile = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        final user = userProfile.user;

        return {
          'runner_id': user?.id,
          'training_centre_id': user?.tc?.id,
        };
      }
    } catch (e) {
      // If we can't get the context or provider, return empty map
    }
    return {};
  }

  /// Track cluster selection screen load
  static Future<void> trackWorkSelectionLoad({
    required List<GoLiveCluster> allClusters,
    required List<GoLiveCluster> recommendedClusters,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'recommended_clusters': recommendedClusters
          .asMap()
          .entries
          .map((entry) => {
                'cluster': entry.value.name,
                'cluster_id': entry.value.id,
                'is_recommended': true,
                'rank': entry.key + 1,
              })
          .toList(),
    };

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveWorkSelectionLoad,
      properties,
    );
  }

  /// Track cluster selection CTA
  static Future<void> trackWorkSelectionCta({
    required List<GoLiveCluster> selectedClusters,
    required List<GoLiveCluster> recommendedClusters,
  }) async {
    int recommendedSelectedCount = 0;
    final Map<String, dynamic> properties = {
      ..._getCommonAttributes(),
      'selected_clusters_count': selectedClusters.length,
    };

    for (int i = 0; i < selectedClusters.length; i++) {
      final cluster = selectedClusters[i];
      final isRecommended = recommendedClusters.contains(cluster);
      if (isRecommended) recommendedSelectedCount++;

      properties['selected_${i + 1}'] = cluster.name;
      properties['selected_${i + 1}_is_recommended'] = isRecommended;
    }

    properties['recommended_selected_count'] = recommendedSelectedCount;

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveWorkSelectionCta,
      properties,
    );
  }

  /// Track back press in flow
  static Future<void> trackFlowBackPress({
    required String stepName,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveFlowBackPress,
      {
        ..._getCommonAttributes(),
        'step_name': stepName,
      },
    );
  }

  /// Track shift hours selection screen load
  static Future<void> trackShiftHoursSelectionLoad({
    required List<String> buckets,
    required bool isWeekend,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveShiftHoursSelectionLoad,
      {
        ..._getCommonAttributes(),
        'buckets_loaded': buckets,
        'card_day_type': isWeekend ? 'weekend' : 'weekday',
      },
    );
  }

  /// Track shift hours selection CTA
  static Future<void> trackShiftHoursSelectionCta({
    required String bucketSelected,
    required bool isWeekend,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveShiftHoursSelectionCta,
      {
        ..._getCommonAttributes(),
        'bucket_selected': bucketSelected,
        'card_day_type': isWeekend ? 'weekend' : 'weekday',
      },
    );
  }

  /// Track start time selection screen load
  static Future<void> trackStartTimeSelectionLoad({
    required List<String> buckets,
    required bool isWeekend,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveStartTimeSelectionLoad,
      {
        ..._getCommonAttributes(),
        'buckets_loaded': buckets,
        'card_day_type': isWeekend ? 'weekend' : 'weekday',
      },
    );
  }

  /// Track start time selection CTA
  static Future<void> trackStartTimeSelectionCta({
    required String bucketSelected,
    required bool isWeekend,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveStartTimeSelectionCta,
      {
        ..._getCommonAttributes(),
        'bucket_selected': bucketSelected,
        'card_day_type': isWeekend ? 'weekend' : 'weekday',
      },
    );
  }

  /// Track recommendation screen load
  static Future<void> trackRecommendationLoad({
    required RecommendedShift shift,
    required int preferenceNo,
    required String weekdayShiftHoursOption,
    required String weekdayStartTimeBucket,
    required bool isWeekend,
    String? weekendShiftHoursOption,
    String? weekendStartTimeBucket,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'order_rank': shift.rank,
      'card_cluster': shift.clusterName,
      'cluster_id': shift.clusterId,
      'card_weekday_shift_duration_option': '${shift.duration}hr',
      'card_weekday_start_time_bucket': weekdayStartTimeBucket,
      'card_weekday_start_time': shift.shiftTimings.formattedStartTime,
      'card_weekday_end_time': shift.shiftTimings.formattedEndTime,
      'card_estimated_monthly_earnings': shift.estimatedMaxEarning,
      'card_joining_bonus': shift.joiningBonus,
      'card_is_top_shift': shift.isTopShift,
      'preference_no': preferenceNo,
      'weekday_shift_hours_option': weekdayShiftHoursOption,
      'weekday_start_time_bucket': weekdayStartTimeBucket,
      'card_day_type': isWeekend ? 'weekend' : 'weekday',
    };

    if (isWeekend && weekendShiftHoursOption != null) {
      properties['weekend_shift_hours_option'] = weekendShiftHoursOption;
      properties['weekend_start_time_bucket'] = weekendStartTimeBucket;
    }

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveRecommendationLoad,
      properties,
    );
  }

  /// Track recommendation CTA (Yes/No)
  static Future<void> trackRecommendationCta({
    required RecommendedShift shift,
    required int preferenceNo,
    required String weekdayShiftHoursOption,
    required String weekdayStartTimeBucket,
    required bool isWeekend,
    required bool accepted,
    String? weekendShiftHoursOption,
    String? weekendStartTimeBucket,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'order_rank': shift.rank,
      'card_cluster': shift.clusterName,
      'cluster_id': shift.clusterId,
      'card_weekday_shift_duration_option': '${shift.duration}hr',
      'card_weekday_start_time_bucket': weekdayStartTimeBucket,
      'card_weekday_start_time': shift.shiftTimings.formattedStartTime,
      'card_weekday_end_time': shift.shiftTimings.formattedEndTime,
      'card_estimated_monthly_earnings': shift.estimatedMaxEarning,
      'card_joining_bonus': shift.joiningBonus,
      'card_is_top_shift': shift.isTopShift,
      'preference_no': preferenceNo,
      'weekday_shift_hours_option': weekdayShiftHoursOption,
      'weekday_start_time_bucket': weekdayStartTimeBucket,
      'card_day_type': isWeekend ? 'weekend' : 'weekday',
      'cta_click': accepted ? 'Yes' : 'No',
    };

    if (isWeekend && weekendShiftHoursOption != null) {
      properties['weekend_shift_hours_option'] = weekendShiftHoursOption;
      properties['weekend_start_time_bucket'] = weekendStartTimeBucket;
    }

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveRecommendationCta,
      properties,
    );
  }

  /// Track recommendation error
  static Future<void> trackRecommendationError({
    required String errorType,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveRecommendationError,
      {
        ..._getCommonAttributes(),
        'error_type': errorType,
      },
    );
  }

  /// Track weekend prompt response
  static Future<void> trackWeekendPromptResponse({
    required bool response,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveWeekendPromptResponse,
      {
        ..._getCommonAttributes(),
        'response': response ? 'yes' : 'no',
      },
    );
  }

  /// Track final confirmation screen load
  static Future<void> trackFinalConfirmationLoad({
    required bool weekendIsDifferent,
    required String weekdayCluster,
    required String weekdayShiftHoursOption,
    required String weekdayStartTime,
    required String weekdayEndTime,
    required int estimatedMonthlyEarnings,
    required int joiningBonus,
    String? weekendCluster,
    String? weekendShiftHoursOption,
    String? weekendStartTime,
    String? weekendEndTime,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'weekend_is_different': weekendIsDifferent,
      'weekday_cluster': weekdayCluster,
      'weekday_shift_hours_option': weekdayShiftHoursOption,
      'weekday_start_time': weekdayStartTime,
      'weekday_end_time': weekdayEndTime,
      'weekday_days': 'mon_fri',
      'estimated_monthly_earnings': estimatedMonthlyEarnings,
      'joining_bonus': joiningBonus,
    };

    if (weekendIsDifferent && weekendCluster != null) {
      properties['weekend_cluster'] = weekendCluster;
      properties['weekend_shift_hours_option'] = weekendShiftHoursOption;
      properties['weekend_start_time'] = weekendStartTime;
      properties['weekend_end_time'] = weekendEndTime;
      properties['weekend_days'] = 'sat_sun';
    }

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveFinalConfirmationLoad,
      properties,
    );
  }

  /// Track final confirmation CTA
  static Future<void> trackFinalConfirmationCta({
    required String ctaType,
    required bool weekendIsDifferent,
    required String weekdayCluster,
    required String weekdayShiftHoursOption,
    required String weekdayStartTime,
    required String weekdayEndTime,
    required int estimatedMonthlyEarnings,
    required int joiningBonus,
    String? weekendCluster,
    String? weekendShiftHoursOption,
    String? weekendStartTime,
    String? weekendEndTime,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'cta_type': ctaType,
      'weekend_is_different': weekendIsDifferent,
      'weekday_cluster': weekdayCluster,
      'weekday_shift_hours_option': weekdayShiftHoursOption,
      'weekday_start_time': weekdayStartTime,
      'weekday_end_time': weekdayEndTime,
      'weekday_days': 'mon_fri',
      'estimated_monthly_earnings': estimatedMonthlyEarnings,
      'joining_bonus': joiningBonus,
    };

    if (weekendIsDifferent && weekendCluster != null) {
      properties['weekend_cluster'] = weekendCluster;
      properties['weekend_shift_hours_option'] = weekendShiftHoursOption;
      properties['weekend_start_time'] = weekendStartTime;
      properties['weekend_end_time'] = weekendEndTime;
      properties['weekend_days'] = 'sat_sun';
    }

    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveFinalConfirmationCta,
      properties,
    );
  }

  /// Track final confirmation error
  static Future<void> trackFinalConfirmationError({
    required String errorType,
  }) async {
    await ClevertapSetup.logEvent(
      TrackingEvents.goLiveFinalConfirmationError,
      {
        ..._getCommonAttributes(),
        'error_type': errorType,
      },
    );
  }
}
