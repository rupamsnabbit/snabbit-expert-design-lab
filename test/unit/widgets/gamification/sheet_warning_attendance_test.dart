import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/models/gamification/sheet_warning.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';

void main() {
  group('filterSheetWarnings', () {
    test('returns only rows matching lifecycleActionType', () {
      final a = SheetWarning.fromMap({
        'lifecycleActionType': 'FALSE_ATTENDANCE',
        'ctaOverrides': [],
      });
      final b = SheetWarning.fromMap({
        'lifecycleActionType': 'CONFIRM_MARK_PRESENT',
        'ctaOverrides': [],
      });
      final all = [a, b];
      expect(
        filterSheetWarnings(all, AttendanceSheetLifecycle.falseAttendance),
        [a],
      );
      expect(
        filterSheetWarnings(all, AttendanceSheetLifecycle.confirmMarkPresent),
        [b],
      );
    });
  });

  group('ctaOverridesForSheet', () {
    test('merges ctaIds from filtered warnings', () {
      final w = SheetWarning.fromMap({
        'lifecycleActionType': 'FALSE_ATTENDANCE',
        'ctaOverrides': [
          {'ctaId': 'go_back', 'label': 'Back'},
          {'ctaId': 'mark_absent', 'label': 'Absent', 'redCards': 2},
        ],
      });
      final map = ctaOverridesForSheet([w]);
      expect(map['go_back']?.label?.key, 'legacy_literal');
      expect(map['go_back']?.label?.params?['text'], 'Back');
      expect(map['mark_absent']?.redCards, 2);
    });
  });

  group('attendanceButtonLabelFromCta', () {
    test('uses CtaOverride.label when valid NudgeLabel', () {
      final lang = LanguageProvider();
      final o = CtaOverride(
        ctaId: 'mark_absent',
        label: const NudgeLabel(
            key: 'legacy_literal', params: {'text': 'Custom'}),
      );
      expect(
        attendanceButtonLabelFromCta(o, lang, 'yes', 'Yes'),
        'Custom',
      );
    });

    test('falls back to getMessage when label null', () {
      final lang = LanguageProvider();
      expect(
        attendanceButtonLabelFromCta(
          const CtaOverride(ctaId: 'x'),
          lang,
          'yes',
          'Yes',
        ),
        'Yes',
      );
      expect(
        attendanceButtonLabelFromCta(null, lang, 'no', 'No'),
        'No',
      );
    });
  });

  group('stub sheetWarnings', () {
    test('parses all stub rows including attendance types', () {
      final raw = [
        {
          'lifecycle_action_type': 'FALSE_ATTENDANCE',
          'cta_overrides': [
            {'cta_id': 'go_back'},
            {'cta_id': 'mark_absent', 'red_cards': 2},
          ],
        },
      ];
      final list = GamificationManager.instance.parseSheetWarnings(raw);
      expect(list, hasLength(1));
      final fp = filterSheetWarnings(
        list,
        AttendanceSheetLifecycle.falseAttendance,
      );
      expect(fp, hasLength(1));
      final m = ctaOverridesForSheet(fp);
      expect(m['mark_absent']?.redCards, 2);
    });
  });
}
