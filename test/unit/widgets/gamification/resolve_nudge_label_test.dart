import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';

void main() {
  group('resolveNudgeLabel', () {
    final lang = LanguageProvider();

    test('default_text substitutes params e.g. {{time}}', () {
      expect(
        resolveNudgeLabel(
          NudgeLabel(
            key: 'nudge_early_login_avoid_no_show',
            params: const {'time': '08:00 am', 'red_cards': 50},
            defaultText: 'Login by {{time}} to avoid No Show',
          ),
          lang,
        ),
        'Login by 08:00 am to avoid No Show',
      );
    });

    test('sheet warning keys use English defaults when not in bundle', () {
      expect(
        resolveNudgeLabel(
          const NudgeLabel(key: 'nudge_mark_present_earn', params: {}),
          lang,
        ),
        '**Mark present** to earn for the jobs you complete',
      );
      expect(
        resolveNudgeLabel(
          const NudgeLabel(key: 'nudge_provisional_absent', params: {}),
          lang,
        ),
        '**Mark absent** — confirm to continue',
      );
    });

    test('nudge_false_attendance_penalty substitutes redCards when present', () {
      expect(
        resolveNudgeLabel(
          const NudgeLabel(
            key: 'nudge_false_attendance_penalty',
            params: {'redCards': 2},
          ),
          lang,
        ),
        '**False attendance** — **2** red cards penalty',
      );
    });

    test('nudge_false_attendance_penalty omits placeholder when redCards absent', () {
      expect(
        resolveNudgeLabel(
          const NudgeLabel(key: 'nudge_false_attendance_penalty', params: {}),
          lang,
        ),
        '**False attendance** — red card penalty may apply',
      );
    });
  });
}
