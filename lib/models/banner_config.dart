class BannerConfig {
  final String id;
  final String imageUrl;
  final double height;
  final BannerPlacement? placement;
  final String?
      position; // 'above_referral' or 'below_referral' (for home / referral)
  final String? actionUrl;
  final DateTime startTime;
  final DateTime endTime;

  BannerConfig({
    required this.id,
    required this.imageUrl,
    required this.height,
    required this.placement,
    this.position,
    this.actionUrl,
    required this.startTime,
    required this.endTime,
  });

  factory BannerConfig.fromJson(Map<String, dynamic> json) {
    return BannerConfig(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      height: (json['height'] as num?)?.toDouble() ?? 100.0,
      placement: BannerPlacement.fromJson(json['placement'] as String? ?? ''),
      position: json['position'] as String?,
      actionUrl: json['action_url'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toUtc(),
      endTime: DateTime.parse(json['end_time'] as String).toUtc(),
    );
  }

  /// Check if this banner is currently within its active time window.
  /// Both sides are compared in UTC to avoid timezone mismatch issues.
  bool get isActiveNow {
    final now = DateTime.now().toUtc();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
}

/// Enum for banner placement screens, with JSON (de)serialization.
enum BannerPlacement {
  home('home'),
  payout('payout'),
  referral('referral');

  final String jsonValue;
  const BannerPlacement(this.jsonValue);

  /// Parse from a JSON string value. Returns null for unknown values
  /// so that unparseable banners are silently skipped.
  static BannerPlacement? fromJson(String value) {
    try {
      return BannerPlacement.values.firstWhere(
        (e) => e.jsonValue == value,
      );
    } catch (_) {
      return null;
    }
  }

  /// Convert to JSON string value.
  String toJson() => jsonValue;
}
