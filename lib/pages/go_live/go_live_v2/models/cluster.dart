/// Model for a hood within a cluster
class Hood {
  final int id;
  final String name;
  final double hungerScore;

  Hood({
    required this.id,
    required this.name,
    required this.hungerScore,
  });

  factory Hood.fromJson(Map<String, dynamic> json) {
    return Hood(
      id: json['id'] as int,
      name: json['name'] as String,
      hungerScore: (json['hunger_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hunger_score': hungerScore,
    };
  }
}

/// Model for a cluster/work area
class GoLiveCluster {
  final int id;
  final String name;
  final int? tcId;
  final double hungerScore;
  final bool isBigCluster;
  final List<Hood>? hoods;
  bool isHigherEarnings;
  final double? distance;

  GoLiveCluster({
    required this.id,
    required this.name,
    required this.tcId,
    required this.hungerScore,
    required this.isBigCluster,
    this.hoods,
    this.isHigherEarnings = false,
    this.distance,
  });

  factory GoLiveCluster.fromJson(Map<String, dynamic> json) {
    return GoLiveCluster(
      id: json['id'] as int,
      name: json['name'] as String,
      tcId: json['tc_id'] as int?,
      hungerScore: (json['hunger_score'] as num).toDouble(),
      isBigCluster: json['is_big_cluster'] as bool,
      hoods: json['hoods'] != null
          ? (json['hoods'] as List<dynamic>)
              .map((e) => Hood.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      isHigherEarnings: json['is_higher_earnings'] as bool? ?? false,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tc_id': tcId,
      'hunger_score': hungerScore,
      'is_big_cluster': isBigCluster,
      'hoods': hoods?.map((h) => h.toJson()).toList(),
      'is_higher_earnings': isHigherEarnings,
      'distance': distance,
    };
  }

  /// Returns true if this cluster has higher earnings
  /// (top 3 by hunger_score in same TC, or top 2 by hunger_score in other regions)
  bool get hasHigherEarnings => isHigherEarnings;

  /// Returns formatted distance text (e.g., "500m", "1.2 km")
  /// Distance from API is in meters
  String? get distanceText {
    if (distance == null) return null;

    final distanceValue = distance!;
    if (distanceValue < 1000) {
      return '${distanceValue.round()}m';
    } else {
      final km = distanceValue / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoLiveCluster &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Response model for GET /v2/go_live/clusters_by_tc
class ClustersResponse {
  final List<GoLiveCluster> clusters;
  final int partnerTcId;
  final List<String> admOptions;

  ClustersResponse({
    required this.clusters,
    required this.partnerTcId,
    required this.admOptions,
  });

  factory ClustersResponse.fromJson(Map<String, dynamic> json) {
    final clusters = (json['clusters'] as List<dynamic>)
        .map((e) => GoLiveCluster.fromJson(e as Map<String, dynamic>))
        .toList();

    final partnerTcId = json['partner_tc_id'] as int;

    // Split clusters into two groups based on tc_id match
    final localClusters = clusters.where((c) => c.tcId == partnerTcId).toList();
    final regionClusters =
        clusters.where((c) => c.tcId != partnerTcId).toList();

    // Sort local clusters by hunger_score (descending) and mark top 3 as higher earnings
    final sortedLocal = List<GoLiveCluster>.from(localClusters)
      ..sort((a, b) => b.hungerScore.compareTo(a.hungerScore));
    final top3LocalIds = sortedLocal.take(3).map((c) => c.id).toSet();

    // Sort region clusters by hunger_score (descending) and mark top 2 as higher earnings
    final sortedRegion = List<GoLiveCluster>.from(regionClusters)
      ..sort((a, b) => b.hungerScore.compareTo(a.hungerScore));
    final top2RegionIds = sortedRegion.take(2).map((c) => c.id).toSet();

    // Apply the isHigherEarnings flag to all clusters
    for (final cluster in clusters) {
      cluster.isHigherEarnings = top3LocalIds.contains(cluster.id) ||
          top2RegionIds.contains(cluster.id);
    }

    return ClustersResponse(
      clusters: clusters,
      partnerTcId: partnerTcId,
      admOptions: (json['adm_options'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
