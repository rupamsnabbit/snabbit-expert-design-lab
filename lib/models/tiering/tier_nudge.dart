/// Visual theme of a home-screen tier nudge (`tier_nudge.theme` on the wire).
enum NudgeTheme {
  generic,
  benefits,
  motivation,
  tierSpecific;

  static NudgeTheme fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'BENEFITS':
        return NudgeTheme.benefits;
      case 'MOTIVATION':
        return NudgeTheme.motivation;
      case 'TIER_SPECIFIC':
        return NudgeTheme.tierSpecific;
      case 'GENERIC':
      default:
        return NudgeTheme.generic;
    }
  }
}

/// The `tier_nudge` object attached to the `current_state` widget payload
/// (`RunnerRtDataProvider.widgetInfo.data['tier_nudge']`).
///
/// One nudge per response; [nudgeName] doubles as the localization key, and
/// [nudgeDetails] carries the nudge-specific values (`coin_amount` for job
/// nudges, the coins body for `WEEKLY_TIER_SUMMARY`, …).
class TierNudge {
  final String? nudgeName;
  final String? navigationRoute;
  final String? imageUrl;
  final NudgeTheme theme;
  final Map<String, dynamic>? nudgeDetails;

  TierNudge({
    this.nudgeName,
    this.navigationRoute,
    this.imageUrl,
    this.theme = NudgeTheme.generic,
    this.nudgeDetails,
  });

  factory TierNudge.fromJson(Map<String, dynamic> json) {
    final details = json['nudge_details'];
    return TierNudge(
      nudgeName: json['nudge_name']?.toString(),
      navigationRoute: json['navigation_route']?.toString(),
      imageUrl: json['image_url']?.toString(),
      theme: NudgeTheme.fromWire(json['theme']?.toString()),
      nudgeDetails: details is Map ? Map<String, dynamic>.from(details) : null,
    );
  }
}
