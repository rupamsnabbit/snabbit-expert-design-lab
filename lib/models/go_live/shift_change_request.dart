
class ShiftChangeRequestData {
  final int? clusterId;
  final String? startTime;
  final int? hoodId;
  final String? adm;
  final int? duration;
  final bool? weekend;
  final int? weekendEarning;
  final int? weekdayEarning;

  ShiftChangeRequestData({
    this.clusterId,
    this.startTime,
    this.hoodId,
    this.adm,
    this.duration,
    this.weekend,
    this.weekendEarning,
    this.weekdayEarning,
  });

  factory ShiftChangeRequestData.fromJson(Map<String, dynamic> json) {
    return ShiftChangeRequestData(
      clusterId: json['cluster_id'],
      startTime: json['start_time'],
      hoodId: json['hood_id'],
      adm: json['adm'],
      duration: json['duration'],
      weekend: json['weekend'],
      weekendEarning: json['weekend_earning'],
      weekdayEarning: json['weekday_earning'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cluster_id': clusterId ?? 0,
      'start_time': startTime ?? '',
      'hood_id': hoodId ?? 0,
      'adm': adm ?? '',
      'duration': duration ?? 0,
      'weekend': weekend ?? false,
      'weekend_earning': weekendEarning ?? 0,
      'weekday_earning': weekdayEarning ?? 0,
    };
  }
}