/// Location data model for IoT tracking
class LocationData {
  final int id;
  final String userId;
  final double lat;
  final double long;
  final double accuracy;
  final double? alt;
  final double? altAccuracy;
  final double? heading;
  final double? headingAccuracy;
  final double? speed;
  final double? speedAccuracy;
  final bool isMocked;
  final int collectedAt;

  /// Correlation key shared by all readings collected in the same background
  /// collection cycle. The foreground-fallback's standalone insert stamps its
  /// own fix time here (a singleton group). Null only for rows collected before
  /// the v4 migration.
  final int? collectionCycleId;
  final bool sent;

  LocationData({
    this.id = 0,
    required this.userId,
    required this.lat,
    required this.long,
    required this.accuracy,
    this.alt,
    this.altAccuracy,
    this.heading,
    this.headingAccuracy,
    this.speed,
    this.speedAccuracy,
    this.isMocked = false,
    required this.collectedAt,
    this.collectionCycleId,
    this.sent = false,
  });

  /// Create from database map (database handles int→bool conversion)
  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      lat: map['lat'] as double,
      long: map['long'] as double,
      accuracy: map['accuracy'] as double,
      alt: map['alt'] as double?,
      altAccuracy: map['alt_accuracy'] as double?,
      heading: map['heading'] as double?,
      headingAccuracy: map['heading_accuracy'] as double?,
      speed: map['speed'] as double?,
      speedAccuracy: map['speed_accuracy'] as double?,
      isMocked: map['is_mocked'] as bool? ?? false,
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
      'lat': lat,
      'long': long,
      'accuracy': accuracy,
      if (alt != null) 'alt': alt,
      if (altAccuracy != null) 'alt_accuracy': altAccuracy,
      if (heading != null) 'heading': heading,
      if (headingAccuracy != null) 'heading_accuracy': headingAccuracy,
      if (speed != null) 'speed': speed,
      if (speedAccuracy != null) 'speed_accuracy': speedAccuracy,
      'is_mocked': isMocked,
      'collected_at': collectedAt,
      if (collectionCycleId != null) 'collection_cycle_id': collectionCycleId,
      'sent': sent,
    };
  }

  /// Create copy with updated fields
  LocationData copyWith({
    int? id,
    String? userId,
    double? lat,
    double? long,
    double? accuracy,
    double? alt,
    double? altAccuracy,
    double? heading,
    double? headingAccuracy,
    double? speed,
    double? speedAccuracy,
    bool? isMocked,
    int? collectedAt,
    int? collectionCycleId,
    bool? sent,
  }) {
    return LocationData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lat: lat ?? this.lat,
      long: long ?? this.long,
      accuracy: accuracy ?? this.accuracy,
      alt: alt ?? this.alt,
      altAccuracy: altAccuracy ?? this.altAccuracy,
      heading: heading ?? this.heading,
      headingAccuracy: headingAccuracy ?? this.headingAccuracy,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
      isMocked: isMocked ?? this.isMocked,
      collectedAt: collectedAt ?? this.collectedAt,
      collectionCycleId: collectionCycleId ?? this.collectionCycleId,
      sent: sent ?? this.sent,
    );
  }
}
