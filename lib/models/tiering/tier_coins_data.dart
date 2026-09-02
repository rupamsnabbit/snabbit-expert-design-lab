import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

/// Root payload for the tier-coins progress card (`TierNudgeProgressCard`).
///
/// Mirrors the API shape:
/// ```json
/// {
///   "coin_balance": 1250,
///   "coins": { "current_week": 3, "weeks": [ ... ] }
/// }
/// ```
class TierCoinsData {
  final int? coinBalance;
  final TierCoinsProgress? coins;

  TierCoinsData({
    this.coinBalance,
    this.coins,
  });

  factory TierCoinsData.fromJson(Map<String, dynamic> json) {
    return TierCoinsData(
      coinBalance: anyValueToInt(json['coin_balance']),
      coins: json['coins'] is Map<String, dynamic>
          ? TierCoinsProgress.fromJson(json['coins'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Weekly coin-earning progress (the `coins` object).
class TierCoinsProgress {
  final int? currentWeek;
  final List<TierWeek>? weeks;

  TierCoinsProgress({
    this.currentWeek,
    this.weeks,
  });

  factory TierCoinsProgress.fromJson(Map<String, dynamic> json) {
    return TierCoinsProgress(
      currentWeek: anyValueToInt(json['current_week']),
      weeks: json['weeks'] is List
          ? (json['weeks'] as List)
              .whereType<Map<String, dynamic>>()
              .map(TierWeek.fromJson)
              .toList()
          : null,
    );
  }

  /// The [TierWeek] whose [TierWeek.week] equals [currentWeek], or null when
  /// there is no match. Drives the card's active-week progress + milestones.
  TierWeek? get activeWeek {
    final week = currentWeek;
    final list = weeks;
    if (week == null || list == null) return null;
    for (final w in list) {
      if (w.week == week) return w;
    }
    return null;
  }
}

/// A single week's earnings plus, for the in-progress week, its milestone
/// [targets].
class TierWeek {
  final int? week;
  final int? earned;
  final TierWeekState? state;
  final List<TierTarget>? targets;

  TierWeek({
    this.week,
    this.earned,
    this.state,
    this.targets,
  });

  factory TierWeek.fromJson(Map<String, dynamic> json) {
    return TierWeek(
      week: anyValueToInt(json['week']),
      earned: anyValueToInt(json['earned']),
      state: TierWeekState.fromString(json['state']?.toString()),
      targets: json['targets'] is List
          ? (json['targets'] as List)
              .whereType<Map<String, dynamic>>()
              .map(TierTarget.fromJson)
              .toList()
          : null,
    );
  }
}

/// A milestone on the progress bar: earn [amount] coins to reach [tier].
class TierTarget {
  final int? amount;
  final Tier? tier;

  TierTarget({
    this.amount,
    this.tier,
  });

  factory TierTarget.fromJson(Map<String, dynamic> json) {
    return TierTarget(
      amount: anyValueToInt(json['amount']),
      tier: Tier.fromString(json['tier']?.toString()),
    );
  }
}

/// Lifecycle of a [TierWeek] as reported by the API (`state`).
enum TierWeekState {
  completed,
  inProgress;

  static TierWeekState? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return TierWeekState.completed;
      case 'in_progress':
        return TierWeekState.inProgress;
      default:
        return null;
    }
  }
}
