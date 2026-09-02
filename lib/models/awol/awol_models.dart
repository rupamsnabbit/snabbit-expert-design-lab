import 'package:snabbit_runner/models/common/countdown_model.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Translatable text from the backend — compatible with LanguageProvider.
///
/// In the overlay (separate isolate), use [defaultText] directly.
/// In the main app, use with:
/// `languageProvider.getFormattedMessage(text.key, text.defaultText, text.params)`
class TranslatableText {
  final String key;
  final String defaultText;
  final Map<String, dynamic> params;

  TranslatableText({
    required this.key,
    required this.defaultText,
    this.params = const {},
  });

  factory TranslatableText.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TranslatableText(key: '', defaultText: '');
    return TranslatableText(
      key: json['key'] ?? '',
      defaultText: json['default'] ?? '',
      params: json['params'] is Map<String, dynamic>
          ? {for (final e in (json['params'] as Map<String, dynamic>).entries) if (e.value != null) e.key: e.value}
          : {},
    );
  }
}

/// Hotspot location info — used for Google Maps directions.
class HotspotInfo {
  final String? name;
  final double? latitude;
  final double? longitude;

  HotspotInfo({this.name, this.latitude, this.longitude});

  factory HotspotInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HotspotInfo();
    return HotspotInfo(
      name: json['name'],
      latitude: anyValueToDouble(json['latitude']),
      longitude: anyValueToDouble(json['longitude']),
    );
  }
}


/// A single consequence item (icon + text) shown in re-entered state.
class AwolConsequence {
  final String? iconUrl;
  final TranslatableText? text;

  AwolConsequence({this.iconUrl, this.text});

  factory AwolConsequence.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AwolConsequence();
    return AwolConsequence(
      iconUrl: json['icon_url'],
      text: json['text'] is Map<String, dynamic>
          ? TranslatableText.fromJson(json['text'])
          : null,
    );
  }
}

/// AWOL breach/re-entered state enum.
enum AwolState {
  breach,
  reEntered,
  job;

  static AwolState fromString(String? value) {
    switch (value) {
      case 'RE_ENTERED':
        return AwolState.reEntered;
      case 'JOB':
        return AwolState.job;
      case 'BREACH':
      default:
        return AwolState.breach;
    }
  }
}

/// Root data model for the AWOL overlay — parsed from `widgetInfo.data['awol']`.
class AwolData {
  final String? eventId;
  final AwolState state;
  final int? breachCount;
  final DateTime? detectedAt;
  final CountdownData? countdown;
  final HotspotInfo? hotspot;
  final TranslatableText? title;
  final TranslatableText? warningText;
  final List<AwolConsequence> consequences;
  final String? imageUrl;
  final TranslatableText? badgeText;
  final int? redCardsTotal;

  AwolData({
    this.eventId,
    this.state = AwolState.breach,
    this.breachCount,
    this.detectedAt,
    this.countdown,
    this.hotspot,
    this.title,
    this.warningText,
    this.consequences = const [],
    this.imageUrl,
    this.badgeText,
    this.redCardsTotal,
  });

  bool get isBreach => state == AwolState.breach;
  bool get isJob => state == AwolState.job;

  factory AwolData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AwolData();
    return AwolData(
      eventId: json['event_id']?.toString(),
      state: AwolState.fromString(json['state']),
      breachCount: anyValueToInt(json['breach_count']),
      detectedAt: (json['detected_at']?.toString().isNotEmpty ?? false)
          ? DateTime.tryParse(json['detected_at'].toString())
          : null,
      countdown: json['countdown'] is Map<String, dynamic>
          ? CountdownData.fromJson(json['countdown'])
          : null,
      hotspot: json['hotspot'] is Map<String, dynamic>
          ? HotspotInfo.fromJson(json['hotspot'])
          : null,
      title: json['title'] is Map<String, dynamic>
          ? TranslatableText.fromJson(json['title'])
          : null,
      warningText: json['warning_text'] is Map<String, dynamic>
          ? TranslatableText.fromJson(json['warning_text'])
          : null,
      consequences: json['consequences'] is List
          ? (json['consequences'] as List)
              .map((c) => AwolConsequence.fromJson(
                  c is Map<String, dynamic> ? c : null))
              .toList()
          : [],
      imageUrl: json['image_url']?.toString(),
      badgeText: json['badge_text'] is Map<String, dynamic>
          ? TranslatableText.fromJson(json['badge_text'])
          : null,
      redCardsTotal: anyValueToInt(json['red_cards_total']) ??
          anyValueToInt(json['redCardsTotal']),
    );
  }
}
