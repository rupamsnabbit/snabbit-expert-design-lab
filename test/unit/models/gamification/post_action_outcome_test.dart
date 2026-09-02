import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/post_action_outcome.dart';

void main() {
  group('PostActionOutcome.tryFromMap', () {
    test('parses when lifecycle_action_type is omitted', () {
      final o = PostActionOutcome.tryFromMap({
        'status': OutcomeStatus.waived,
        'title_label': {
          'key': 'outcome_waived_title',
          'default_text': 'No red card applied',
        },
      });
      expect(o, isNotNull);
      expect(o!.lifecycleActionType, '');
      expect(o.status, OutcomeStatus.waived);
      expect(o.isWaived, isTrue);
      expect(o.label.key, 'outcome_waived_title');
    });

    test('returns null when status is missing', () {
      expect(
        PostActionOutcome.tryFromMap({
          'lifecycle_action_type': 'ACCEPT_JOB_PENALTY',
          'title_label': {'key': 'k'},
        }),
        isNull,
      );
    });

    test('returns null when status is empty string', () {
      expect(
        PostActionOutcome.tryFromMap({
          'status': '',
          'title_label': {'key': 'k'},
        }),
        isNull,
      );
    });

    test('parses snake_case lifecycle_action_type with status', () {
      final o = PostActionOutcome.tryFromMap({
        'lifecycle_action_type': 'ACCEPT_JOB_PENALTY',
        'status': OutcomeStatus.penalty,
        'title_label': {'key': 'penalty_title'},
        'red_cards': 1,
      });
      expect(o, isNotNull);
      expect(o!.lifecycleActionType, 'ACCEPT_JOB_PENALTY');
      expect(o.status, OutcomeStatus.penalty);
      expect(o.redCards, 1);
    });

    test('parses icon_url for title bar image', () {
      final o = PostActionOutcome.tryFromMap({
        'status': OutcomeStatus.reward,
        'title_label': {'key': 't'},
        'gold_coins': 1,
        'icon_url': 'https://assets.example.com/ribbon.png',
      });
      expect(o, isNotNull);
      expect(o!.iconUrl, 'https://assets.example.com/ribbon.png');
    });
  });
}
