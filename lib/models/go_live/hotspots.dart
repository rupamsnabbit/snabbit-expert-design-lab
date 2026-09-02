import 'package:snabbit_runner/models/hood.dart';

class HotspotsResponse {
  final List<HotSpot>? hotspots;
  final String? clusterName;
  final int? clusterId;

  HotspotsResponse({
    this.hotspots,
    this.clusterName,
    this.clusterId,
  });

  factory HotspotsResponse.fromJson(Map<String,dynamic>? json) {
    return HotspotsResponse(
      hotspots: json?['hotspots']!=null? (json?['hotspots'] as List<dynamic>)
          .map((e) => HotSpot.fromMap(e as Map<String, dynamic>))
          .toList():null,
      clusterName: json?['cluster_name'],
      clusterId: json?['cluster_id'],
    );
  }
}