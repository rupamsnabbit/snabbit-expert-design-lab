import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/models/common/countdown_model.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/models/overlay/overlay_config.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/awol_strings.dart';

extension AwolOverlayConverter on AwolData {
  OverlayConfig toOverlayConfig(
    LanguageProvider lp, {
    double? jobLat,
    double? jobLng,
    int? jobStartTimestampMs,
    List<PreActionNudge> nudges = const [],
  }) {
    // JOB-AWOL anchors the native timer to this absolute timestamp; without it
    // the overlay degrades to a frozen 00:00. Callers must filter beforehand.
    assert(!isJob || jobStartTimestampMs != null,
        'JOB-AWOL requires a non-null jobStartTimestampMs');

    final titleText = title != null
        ? lp.getFormattedMessage(title!.key, title!.defaultText, title!.params)
        : null;
    final warningTextStr = warningText != null
        ? lp.getFormattedMessage(warningText!.key, warningText!.defaultText, warningText!.params)
        : null;

    Map<String, dynamic>? countdownMap;
    if (countdown != null) {
      countdownMap = {
        'remaining_seconds': countdown!.remainingSecondsOrDefault,
        'total_seconds': countdown!.totalSecondsOrDefault,
        if (countdown!.triggerAt != null)
          'trigger_at': countdown!.triggerAt!.millisecondsSinceEpoch,
      };
    } else if (isJob) {
      countdownMap = {
        'remaining_seconds': 0,
        'total_seconds': CountdownData.defaultTotalSeconds,
      };
    }

    return OverlayConfig(
      title: titleText,
      message: warningTextStr,
      ctaList: _buildCtaList(lp, jobLat: jobLat, jobLng: jobLng),
      countdown: countdownMap,
      hotspot: hotspot != null
          ? {
              'name': hotspot!.name,
              'latitude': hotspot!.latitude,
              'longitude': hotspot!.longitude,
            }
          : null,
      consequences: consequences
          .map((c) => {
                'icon_url': c.iconUrl,
                'text': c.text != null
                    ? lp.getFormattedMessage(c.text!.key, c.text!.defaultText, c.text!.params)
                    : null,
              })
          .toList(),
      imageUrl: imageUrl
          ?? (isBreach || isJob
              ? RemoteConfigAssets.awolEnterHotspot
              : RemoteConfigAssets.awolBackInHotspot),
      badgeText: badgeText != null
          ? lp.getMessage(badgeText!.key, badgeText!.defaultText)
          : (isJob
              ? lp.getMessage(AwolStrings.jobBadgeKey, AwolStrings.jobBadgeDefault)
              : isBreach
                  ? lp.getMessage(AwolStrings.breachBadgeKey, AwolStrings.breachBadgeDefault)
                  : lp.getMessage(AwolStrings.reEnteredBadgeKey, AwolStrings.reEnteredBadgeDefault)),
      miniTitle: lp.getMessage(AwolStrings.miniTitleKey, AwolStrings.miniTitleDefault),
      timerColorMode: isJob ? 'traffic' : 'red',
      jobStartTimestampMs: isJob ? jobStartTimestampMs : null,
      redCardReceivedLabel: AwolStrings.redCardReceivedLabel(lp, redCardsTotal),
      nudgeOutsideHotspot: lp.getMessage(AwolStrings.breachOutsideHotspotKey, AwolStrings.breachOutsideHotspotDefault),
      preActionNudges: nudges.isEmpty ? null : nudges.map((n) => {
        'lifecycleActionType': n.lifecycleActionType,
        'nudgeKind': n.nudgeKind,
        'iconUrl': n.iconUrl,
        'labelText': n.label.isValid
            ? lp.getFormattedMessage(n.label.key, n.label.defaultText ?? '', n.label.params ?? {})
            : null,
        'redCards': n.redCards,
        'goldCoins': n.goldCoins,
      }).toList(),
      redCardsTotal: redCardsTotal,
    );
  }

  List<CTAConfig> _buildCtaList(LanguageProvider lp, {double? jobLat, double? jobLng}) {
    if (isBreach || isJob) {
      // For JOB: use job coordinates from widgetData; for BREACH: use hotspot
      final double? dirLat = isJob ? jobLat : hotspot?.latitude;
      final double? dirLng = isJob ? jobLng : hotspot?.longitude;
      final String? dirName = isJob ? null : hotspot?.name;

      return [
        if (dirLat != null && dirLng != null)
          CTAConfig(
            actionId: 'show_directions',
            label: lp.getMessage(AwolStrings.showDirectionsKey, AwolStrings.showDirectionsDefault),
            style: 'primary',
            data: {
              'lat': dirLat,
              'lng': dirLng,
              'name': dirName,
            },
          ),
        CTAConfig(
          actionId: 'understood',
          label: lp.getMessage(AwolStrings.understoodKey, AwolStrings.understoodDefault),
          style: 'secondary',
        ),
      ];
    } else {
      // Re-entered: single "I understood" button
      return [
        CTAConfig(
          actionId: 'understood',
          label: lp.getMessage(AwolStrings.understoodKey, AwolStrings.understoodDefault),
          style: 'primary',
        ),
      ];
    }
  }
}
