/// Battery data model for IoT tracking
class BatteryData {
  final int id;
  final String userId;
  final int percentage;
  final int collectedAt;

  /// Correlation key shared by all readings collected in the same background
  /// collection cycle. Null for rows collected before the v4 migration.
  final int? collectionCycleId;
  final bool sent;

  BatteryData({
    this.id = 0,
    required this.userId,
    required this.percentage,
    required this.collectedAt,
    this.collectionCycleId,
    this.sent = false,
  });

  /// Create from database map (database handles int→bool conversion)
  factory BatteryData.fromMap(Map<String, dynamic> map) {
    return BatteryData(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      percentage: map['percentage'] as int,
      collectedAt: map['collected_at'] as int,
      collectionCycleId: map['collection_cycle_id'] as int?,
      sent: map['sent'] as bool? ?? false,
    );
  }

  /// Convert to database map (database handles bool→int conversion)
  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'user_id': userId,
      'percentage': percentage,
      'collected_at': collectedAt,
      if (collectionCycleId != null) 'collection_cycle_id': collectionCycleId,
      'sent': sent,
    };
  }

  /// Create copy with updated fields
  BatteryData copyWith({
    int? id,
    String? userId,
    int? percentage,
    int? collectedAt,
    int? collectionCycleId,
    bool? sent,
  }) {
    return BatteryData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      percentage: percentage ?? this.percentage,
      collectedAt: collectedAt ?? this.collectedAt,
      collectionCycleId: collectionCycleId ?? this.collectionCycleId,
      sent: sent ?? this.sent,
    );
  }
}
