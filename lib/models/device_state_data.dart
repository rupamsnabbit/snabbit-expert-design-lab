import 'package:snabbit_runner/utils/common_methods.dart';

/// Device state data model for IoT tracking
class DeviceStateData {
  final int id;
  final String userId;
  final bool? locationServicesOn;
  final bool? mobileDataOn;
  final String? networkType;
  final int collectedAt;

  /// Correlation key shared by all readings collected in the same background
  /// collection cycle. Null for rows collected before the v4 migration.
  final int? collectionCycleId;
  final bool sent;

  DeviceStateData({
    this.id = 0,
    required this.userId,
    this.locationServicesOn,
    this.mobileDataOn,
    this.networkType,
    required this.collectedAt,
    this.collectionCycleId,
    this.sent = false,
  });

  /// Create from database map (database handles int→bool conversion)
  factory DeviceStateData.fromMap(Map<String, dynamic> map) {
    return DeviceStateData(
      id: anyValueToInt(map['id']) ?? 0,
      userId: map['user_id'],
      locationServicesOn: map['location_services_on'],
      mobileDataOn: map['mobile_data_on'],
      networkType: map['network_type'],
      collectedAt: anyValueToInt(map['collected_at']) ?? 0,
      collectionCycleId: anyValueToInt(map['collection_cycle_id']),
      sent: map['sent'] ?? false,
    );
  }

  /// Convert to database map (database handles bool→int conversion)
  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'user_id': userId,
      'location_services_on': locationServicesOn,
      'mobile_data_on': mobileDataOn,
      'network_type': networkType,
      'collected_at': collectedAt,
      if (collectionCycleId != null) 'collection_cycle_id': collectionCycleId,
      'sent': sent,
    };
  }

  /// Create copy with updated fields
  DeviceStateData copyWith({
    int? id,
    String? userId,
    bool? locationServicesOn,
    bool? mobileDataOn,
    String? networkType,
    int? collectedAt,
    int? collectionCycleId,
    bool? sent,
  }) {
    return DeviceStateData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      locationServicesOn: locationServicesOn ?? this.locationServicesOn,
      mobileDataOn: mobileDataOn ?? this.mobileDataOn,
      networkType: networkType ?? this.networkType,
      collectedAt: collectedAt ?? this.collectedAt,
      collectionCycleId: collectionCycleId ?? this.collectionCycleId,
      sent: sent ?? this.sent,
    );
  }
}
