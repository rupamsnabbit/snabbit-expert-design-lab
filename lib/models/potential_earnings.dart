import 'package:snabbit_runner/models/go_live/earning_model.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class PotentialEarningsTopSection {
  final List<Cluster>? clusters;
  final List<Cluster>? recommendedClusters;
  final Map<String, int>? weekdayMaxEarnings;
  final GoLiveAssets? assets;

  PotentialEarningsTopSection({
    this.clusters,
    this.recommendedClusters,
    this.weekdayMaxEarnings,
    this.assets,
  });

  factory PotentialEarningsTopSection.fromJson(Map<String, dynamic> json) {
    final weekdayMaxEarnings = json['weekday_max_earnings'] ?? {};
    Map<String, int> weekdayMaxEarningsInt = {};
    weekdayMaxEarnings.forEach((key, value) {
      weekdayMaxEarningsInt[key] = anyValueToInt(value) ?? 0;
    });

    final List<Cluster>? regularClusters = json['clusters'] != null
        ? (json['clusters'] as List<dynamic>?)
            ?.map((e) => Cluster.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;

    final List<Cluster>? recommendedClusters =
        json['recommended_clusters'] != null
            ? (json['recommended_clusters'] as List<dynamic>?)
                ?.map((e) => Cluster.fromJson(e as Map<String, dynamic>))
                .toList()
            : null;

    return PotentialEarningsTopSection(
      clusters: regularClusters,
      recommendedClusters: recommendedClusters,
      weekdayMaxEarnings: weekdayMaxEarningsInt,
      assets: json['assets'] != null
          ? GoLiveAssets.fromJson(json['assets'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clusters': clusters?.map((e) => e.toJson()).toList(),
      'recommended_clusters':
          recommendedClusters?.map((e) => e.toJson()).toList(),
      'weekday_max_earnings': weekdayMaxEarnings,
      'assets': assets?.toJson(),
    };
  }

  /// Returns all clusters with recommended clusters prepended
  List<Cluster> getAllClusters() {
    final List<Cluster> allClusters = [];

    // Add recommended clusters first
    if (recommendedClusters != null && recommendedClusters!.isNotEmpty) {
      allClusters.addAll(recommendedClusters!);
    }

    // Add regular clusters
    if (clusters != null && clusters!.isNotEmpty) {
      allClusters.addAll(clusters!);
    }

    return allClusters;
  }

  /// Returns true if there are recommended clusters
  bool get hasRecommendedClusters =>
      recommendedClusters != null && recommendedClusters!.isNotEmpty;
}

class Cluster {
  final int? id;
  final String? name;

  Cluster({
    this.id,
    this.name,
  });

  factory Cluster.fromJson(Map<String, dynamic> json) {
    return Cluster(
      id: json['id'] as int?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class PotentialEarningsBottomSection {
  final int? clusterId;
  final List<String>? modeTransport;
  final List<Hood>? hoods;
  final List<Hood>? recommendedHoods;
  final Map<String, int>? maxEarnings;

  PotentialEarningsBottomSection({
    this.clusterId,
    this.modeTransport,
    this.hoods,
    this.recommendedHoods,
    this.maxEarnings,
  });

  factory PotentialEarningsBottomSection.fromJson(Map<String, dynamic> json) {
    final maxEarnings = json['max_earnings'] ?? {};
    Map<String, int> maxEarningsInt = {};
    maxEarnings.forEach((key, value) {
      maxEarningsInt[key] = anyValueToInt(value) ?? 0;
    });

    final List<Hood>? regularHoods = json['hoods'] != null
        ? (json['hoods'] as List<dynamic>?)
            ?.map((e) => Hood.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;

    final List<Hood>? recommendedHoods = json['recommended_hoods'] != null
        ? (json['recommended_hoods'] as List<dynamic>?)
            ?.map((e) => Hood.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;

    return PotentialEarningsBottomSection(
      clusterId: json['cluster_id'] as int?,
      modeTransport: json['mode_transport'] != null
          ? (json['mode_transport'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList()
          : null,
      hoods: regularHoods,
      recommendedHoods: recommendedHoods,
      maxEarnings: maxEarningsInt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cluster_id': clusterId,
      'mode_transport': modeTransport,
      'hoods': hoods?.map((e) => e.toJson()).toList(),
      'recommended_hoods': recommendedHoods?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cluster && clusterId == other.id;
  }

  /// Returns all hoods with recommended hoods prepended
  List<Hood> getAllHoods() {
    final List<Hood> allHoods = [];

    // Add recommended hoods first
    if (recommendedHoods != null && recommendedHoods!.isNotEmpty) {
      allHoods.addAll(recommendedHoods!);
    }

    // Add regular hoods
    if (hoods != null && hoods!.isNotEmpty) {
      allHoods.addAll(hoods!);
    }

    return allHoods;
  }

  /// Returns true if there are recommended hoods
  bool get hasRecommendedHoods =>
      recommendedHoods != null && recommendedHoods!.isNotEmpty;
}

class Hood {
  final int? hoodId;
  final int? hotspotId;
  final String? hoodName;
  final List<Shift>? shifts;

  Hood({
    this.hoodId,
    this.hoodName,
    this.shifts,
    this.hotspotId,
  });

  factory Hood.fromJson(Map<String, dynamic> json) {
    return Hood(
      hoodId: json['hood_id'],
      hoodName: json['hood_name'],
      hotspotId: json['hotspot_id'],
      shifts: json['shifts'] != null
          ? (json['shifts'] as List<dynamic>?)
              ?.map((e) => Shift.fromJson(e as Map<String, dynamic>))
              .toList()
          : json['shifts'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hood_id': hoodId,
      'hood_name': hoodName,
      'hotspot_id': hotspotId,
      'shifts': shifts?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hood &&
        hoodId == other.hoodId &&
        hoodName == other.hoodName &&
        hotspotId == other.hotspotId;
  }

  @override
  int get hashCode => Object.hash(
        hoodId,
        hoodName,
        hotspotId,
        Object.hashAll(shifts ?? []),
      );
}

class Shift {
  final int? durationHours;
  final List<DateTime>? startTimes;
  final List<EarningModel>? hourlyRates;
  final int? totalPay;
  final bool? isAvailable;
  final bool? isBlocked;

  Shift({
    this.durationHours,
    this.startTimes,
    this.hourlyRates,
    this.totalPay,
    this.isAvailable,
    this.isBlocked,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // Get the current date to combine with the time strings
    final DateTime now = DateTime.now();

    return Shift(
      durationHours: json['duration_hours'],
      startTimes: json['start_times'] != null
          ? (json['start_times'] as List<dynamic>?)
              ?.map((timeString) {
                // Parse the time string (e.g., "06:30:00")
                final List<String> parts = (timeString as String).split(':');
                if (parts.length == 3) {
                  final int hour = int.tryParse(parts[0]) ?? 0;
                  final int minute = int.tryParse(parts[1]) ?? 0;
                  final int second = int.tryParse(parts[2]) ?? 0;
                  // Combine with today's date
                  return DateTime(
                      now.year, now.month, now.day, hour, minute, second);
                }
                return null; // Return null if parsing fails
              })
              .whereType<
                  DateTime>() // Filter out any nulls from parsing failures
              .toList()
          : null,
      hourlyRates: json['hourly_rates'] != null
          ? (json['hourly_rates'] as List<dynamic>?)
              ?.map((e) => EarningModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      totalPay: json['total_pay'],
      isAvailable: json['is_available'],
      isBlocked: json['is_blocked'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'duration_hours': durationHours,
      'start_times': startTimes,
      'total_pay': totalPay,
      'is_available': isAvailable,
      'is_blocked': isBlocked,
      'hourly_rates': hourlyRates?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Shift &&
        durationHours == other.durationHours &&
        totalPay == other.totalPay &&
        isAvailable == other.isAvailable &&
        isBlocked == other.isBlocked;
  }

  @override
  int get hashCode => Object.hash(
        durationHours,
        totalPay,
        isAvailable,
        isBlocked,
      );
}

class GoLiveAssets {
  final String? regularEarnings;
  final String? weekendEarnings;
  final String? willingToWorkWeekends;

  GoLiveAssets({
    this.regularEarnings,
    this.weekendEarnings,
    this.willingToWorkWeekends,
  });

  factory GoLiveAssets.fromJson(Map<String, dynamic> json) {
    return GoLiveAssets(
      regularEarnings: json['regular_earnings'],
      weekendEarnings: json['weekend_earnings'],
      willingToWorkWeekends: json['willing_to_work_weekends'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regular_earnings': regularEarnings,
      'weekend_earnings': weekendEarnings,
      'willing_to_work_weekends': willingToWorkWeekends,
    };
  }
}
