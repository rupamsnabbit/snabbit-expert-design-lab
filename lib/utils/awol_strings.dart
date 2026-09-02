import '../providers/language_provider.dart';

/// i18n keys and default English strings for AWOL widgets and overlays.
class AwolStrings {
  AwolStrings._();

  // ── i18n Keys ──────────────────────────────────

  // Breach
  static const String breachTitleKey = 'awol_breach_title';
  static const String breachWarningKey = 'awol_breach_warning';
  static const String breachBadgeKey = 'awol_hotspot_breach_badge';

  // Re-entered
  static const String reEnteredTitleKey = 'awol_re_entered_title';
  static const String reEnteredWarningKey = 'awol_re_entered_warning';
  static const String reEnteredBadgeKey = 'awol_back_in_hotspot_badge';

  // Job AWOL
  static const String jobTitleKey = 'awol_job_title';
  static const String jobWarningKey = 'awol_job_warning';
  static const String jobBadgeKey = 'awol_job_badge';

  // Red card nudge
  static const String breachOutsideHotspotKey = 'awol_breach_outside_hotspot';
  static const String breachRedCardReceivedSingularKey = 'awol_breach_red_card_received_singular';
  static const String breachRedCardReceivedPluralKey = 'awol_breach_red_card_received_plural';

  // Common
  static const String showDirectionsKey = 'awol_show_directions';
  static const String understoodKey = 'awol_understood';
  static const String miniTitleKey = 'awol_mini_title';

  // ── Default English Strings ────────────────────

  // Breach
  static const String breachTitleDefault = 'Please return to hotspot within';
  static const String breachWarningDefault =
      "You will face a penalty if you don't return before the timer expires.";
  static const String breachBadgeDefault = 'HOTSPOT BREACH';

  // Re-entered
  static const String reEnteredTitleDefault = 'Re-entered hotspot';
  static const String reEnteredWarningDefault =
      'You exited the hotspot once today. Repeated breaches may result in:';
  static const String reEnteredBadgeDefault = 'BACK IN HOTSPOT';

  // Job AWOL
  static const String jobTitleDefault = 'Please go to the job location';
  static const String jobWarningDefault =
      "You'll receive a penalty if you don't start moving soon";
  static const String jobBadgeDefault = 'MOVEMENT REQUIRED';

  // Red card nudge
  static const String breachOutsideHotspotDefault = 'Outside Hotspot';
  static const String breachRedCardReceivedSingularDefault = 'RED CARD RECEIVED';
  static const String breachRedCardReceivedPluralDefault = 'RED CARDS RECEIVED';

  // Common
  static const String showDirectionsDefault = 'Show Directions';
  static const String understoodDefault = 'I understood';
  static const String miniTitleDefault = 'Snabbit Alert';

  /// Resolves singular/plural red-card-received label via [lp].
  /// Single source of truth — used by both the overlay converter and the breach widget.
  static String redCardReceivedLabel(LanguageProvider lp, int? count) {
    return (count ?? 0) == 1
        ? lp.getMessage(breachRedCardReceivedSingularKey, breachRedCardReceivedSingularDefault)
        : lp.getMessage(breachRedCardReceivedPluralKey, breachRedCardReceivedPluralDefault);
  }
}
