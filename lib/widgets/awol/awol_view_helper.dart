import '../../models/awol/awol_models.dart';
import '../../providers/language_provider.dart';
import '../../utils/awol_strings.dart';

/// Shared presentation logic for AWOL widgets.
/// Resolves text, badges, and colors from AwolData + LanguageProvider.
class AwolViewHelper {
  final AwolData data;
  final LanguageProvider lp;

  AwolViewHelper({required this.data, required this.lp});

  // ── Text resolution ────────────────────────────

  String get title {
    final text = data.title;
    if (text == null) return _fallbackTitle;
    return lp.getFormattedMessage(text.key, text.defaultText, text.params);
  }

  String get warning {
    final text = data.warningText;
    if (text == null) return _fallbackWarning;
    return lp.getFormattedMessage(text.key, text.defaultText, text.params);
  }

  String get badge {
    final bt = data.badgeText;
    if (bt != null) return lp.getMessage(bt.key, bt.defaultText);
    return lp.getMessage(_fallbackBadgeKey, _fallbackBadgeDefault);
  }

  String get _fallbackTitle {
    if (data.isJob) return lp.getMessage(AwolStrings.jobTitleKey, AwolStrings.jobTitleDefault);
    if (data.isBreach) return lp.getMessage(AwolStrings.breachTitleKey, AwolStrings.breachTitleDefault);
    return lp.getMessage(AwolStrings.reEnteredTitleKey, AwolStrings.reEnteredTitleDefault);
  }

  String get _fallbackWarning {
    if (data.isJob) return lp.getMessage(AwolStrings.jobWarningKey, AwolStrings.jobWarningDefault);
    if (data.isBreach) return lp.getMessage(AwolStrings.breachWarningKey, AwolStrings.breachWarningDefault);
    return lp.getMessage(AwolStrings.reEnteredWarningKey, AwolStrings.reEnteredWarningDefault);
  }

  String get _fallbackBadgeKey {
    if (data.isJob) return AwolStrings.jobBadgeKey;
    if (data.isBreach) return AwolStrings.breachBadgeKey;
    return AwolStrings.reEnteredBadgeKey;
  }

  String get _fallbackBadgeDefault {
    if (data.isJob) return AwolStrings.jobBadgeDefault;
    if (data.isBreach) return AwolStrings.breachBadgeDefault;
    return AwolStrings.reEnteredBadgeDefault;
  }

}
