import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';

/// Sample `sheet_warnings[]` rows (same shape as backend JSON) for parse tests.
/// Extra fields like `nudge_kind`, `label`, `icon_url` are ignored by
/// [SheetWarning] — only `lifecycle_action_type`, `cta_overrides`, and
/// `expires_at` are parsed.
const List<Map<String, dynamic>> _sampleSheetWarningsRaw = [
  {
    'lifecycle_action_type': 'ACCEPT_JOB_PENALTY',
    'expires_at': null,
    'cta_overrides': [
      {
        'cta_id': 'go_back',
        'label': 'Go back',
        'gold_coins': null,
        'red_cards': null,
      },
      {
        'cta_id': 'accept_job',
        'label': 'Accept Job',
        'gold_coins': null,
        'red_cards': 2,
      },
    ],
  },
  {
    'lifecycle_action_type': 'FALSE_ATTENDANCE',
    'expires_at': null,
    'cta_overrides': [
      {
        'cta_id': 'go_back',
        'label': null,
        'gold_coins': null,
        'red_cards': null,
      },
      {
        'cta_id': 'mark_absent',
        'label': 'Absent',
        'gold_coins': null,
        'red_cards': 2,
      },
    ],
  },
  {
    'lifecycle_action_type': 'CONFIRM_MARK_PRESENT',
    'expires_at': null,
    'cta_overrides': [
      {
        'cta_id': 'go_back',
        'label': null,
      },
      {
        'cta_id': 'mark_present',
        'label': null,
      },
    ],
  },
  {
    'lifecycle_action_type': 'PROVISIONAL_MARK_ABSENT',
    'expires_at': null,
    'cta_overrides': [
      {
        'cta_id': 'go_back',
        'label': null,
      },
      {
        'cta_id': 'mark_absent',
        'label': null,
      },
    ],
  },
];

void main() {
  group('GamificationManager.parseSheetWarnings', () {
    test('returns empty for non-list', () {
      expect(GamificationManager.instance.parseSheetWarnings(null), isEmpty);
      expect(GamificationManager.instance.parseSheetWarnings('x'), isEmpty);
      expect(GamificationManager.instance.parseSheetWarnings({}), isEmpty);
    });

    test('parses stub sample as SheetWarning rows', () {
      final list = GamificationManager.instance
          .parseSheetWarnings(_sampleSheetWarningsRaw);
      expect(list, hasLength(4));
      expect(list.first.lifecycleActionType, 'ACCEPT_JOB_PENALTY');
      expect(list.first.ctaOverrides, hasLength(2));
      expect(list.first.ctaOverrides!.first.ctaId, 'go_back');
      expect(list.first.ctaOverrides!.last.redCards, 2);

      final falseAttendance = filterSheetWarnings(
        list,
        AttendanceSheetLifecycle.falseAttendance,
      );
      expect(falseAttendance, hasLength(1));
      expect(falseAttendance.single.ctaOverrides?.map((e) => e.ctaId),
          containsAll(['go_back', 'mark_absent']));
    });

    test('drops stale rows by expiresAt', () {
      final raw = [
        {
          'lifecycleActionType': 'X',
          'expiresAt': '2000-01-01T00:00:00.000Z',
          'ctaOverrides': [],
        },
      ];
      expect(GamificationManager.instance.parseSheetWarnings(raw), isEmpty);
    });
  });
}
