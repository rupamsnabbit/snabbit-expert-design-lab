class OverlayConfig {
  final String? title;
  final String? message;
  final List<CTAConfig> ctaList;
  final bool dismissOnOutsideTouch;
  final int? autoDismissSec;
  final String position;
  final Map<String, dynamic>? countdown;
  final Map<String, dynamic>? hotspot;
  final List<Map<String, dynamic>>? consequences;
  final String? imageUrl;
  final String? badgeText;
  final String? miniTitle;
  final String? timerColorMode;
  final int? jobStartTimestampMs;
  final List<Map<String, dynamic>>? preActionNudges;
  final int? redCardsTotal;
  final String? redCardReceivedLabel;
  final String? nudgeOutsideHotspot;

  OverlayConfig({
    this.title,
    this.message,
    this.ctaList = const [],
    this.dismissOnOutsideTouch = false,
    this.autoDismissSec,
    this.position = 'center',
    this.countdown,
    this.hotspot,
    this.consequences,
    this.imageUrl,
    this.badgeText,
    this.miniTitle,
    this.timerColorMode,
    this.jobStartTimestampMs,
    this.preActionNudges,
    this.redCardsTotal,
    this.redCardReceivedLabel,
    this.nudgeOutsideHotspot,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'message': message,
        'ctaList': ctaList.map((c) => c.toMap()).toList(),
        'dismissOnOutsideTouch': dismissOnOutsideTouch,
        'autoDismissSec': autoDismissSec,
        'position': position,
        'countdown': countdown,
        'hotspot': hotspot,
        'consequences': consequences,
        'imageUrl': imageUrl,
        'badgeText': badgeText,
        'miniTitle': miniTitle,
        'timerColorMode': timerColorMode,
        'jobStartTimestampMs': jobStartTimestampMs,
        'preActionNudges': preActionNudges,
        'redCardsTotal': redCardsTotal,
        'redCardReceivedLabel': redCardReceivedLabel,
        'nudgeOutsideHotspot': nudgeOutsideHotspot,
      };
}

class CTAConfig {
  final String actionId;
  final String label;
  final String style;
  final Map<String, dynamic> data;

  CTAConfig({
    required this.actionId,
    required this.label,
    this.style = 'secondary',
    this.data = const {},
  });

  Map<String, dynamic> toMap() => {
        'actionId': actionId,
        'label': label,
        'style': style,
        'data': data,
      };
}
