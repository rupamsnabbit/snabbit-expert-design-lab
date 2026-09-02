import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

String _defaultEnglishForNudgeKey(String key) {
  switch (key) {
    case 'nudge_long_distance_bonus':
      return '**Accept long distance job** to earn';
    case 'nudge_early_checkin':
      return 'Eligible for Early Checkin';
    case 'nudge_accept_avoid_penalty':
      return '**Accept the job** to avoid penalty';
    case 'nudge_early_login_earn_before':
      return 'Login before {{deadlineTime}} to earn {{coins}} gold coins';
    // sheet_warnings[] / bottom-sheet nudges (LLD §9.1.1)
    case 'nudge_false_attendance_penalty':
      return '**False attendance** — **{{redCards}}** red cards penalty';
    case 'nudge_mark_present_earn':
      return '**Mark present** to earn for the jobs you complete';
    case 'nudge_provisional_absent':
      return '**Mark absent** — confirm to continue';
    default:
      // Last-resort fallback — BE should always send `default_text` on NudgeLabels.
      // If we hit this path, it means a new key was added without a client-side default.
      debugPrint(
          '[resolveNudgeLabel] unknown key "$key" — using generic fallback');
      return '';
  }
}

String resolveNudgeLabel(NudgeLabel label, LanguageProvider lang) {
  if (label.key == 'legacy_literal') {
    return label.params?['text']?.toString() ?? '';
  }
  final serverDefault = label.defaultText?.trim();
  if (serverDefault != null && serverDefault.isNotEmpty) {
    // Must use [getFormattedMessage] so `{{time}}` and other `params` placeholders
    // in `default_text` are substituted (getMessage alone leaves literals visible).
    return lang.getFormattedMessage(
      label.key,
      serverDefault,
      label.params,
    );
  }
  var defaultEn = _defaultEnglishForNudgeKey(label.key);
  // Avoid leaving `{{redCards}}` visible when BE omits params (tests / older payloads).
  if (label.key == 'nudge_false_attendance_penalty' &&
      (label.params == null || label.params!['redCards'] == null)) {
    defaultEn = '**False attendance** — red card penalty may apply';
  }
  return lang.getFormattedMessage(
    label.key,
    defaultEn,
    label.params,
  );
}
