import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';

void main() {
  group('PreActionNudge.fromMap', () {
    test('accepts snake_case keys from API', () {
      final n = PreActionNudge.fromMap({
        'lifecycle_action_type': 'EARLY_LOGIN',
        'nudge_kind': 'opportunity',
        'icon_url': 'https://example.com/icon.png',
        'label': {
          'key': 'nudge_early_login_avoid_no_show',
          'params': {'time': '08:00 am', 'red_cards': 50},
          'default_text': 'Login by 08:00 am to avoid No Show',
        },
        'gold_coins': null,
        'red_cards': 50,
        'expires_at': '2026-04-16T02:30:00Z',
        'cta_overrides': null,
      });
      expect(n.lifecycleActionType, 'EARLY_LOGIN');
      expect(n.nudgeKind, 'opportunity');
      expect(n.iconUrl, 'https://example.com/icon.png');
      expect(n.redCards, 50);
      expect(
          n.expiresAt?.toUtc().toIso8601String(), '2026-04-16T02:30:00.000Z');
      expect(n.label.key, 'nudge_early_login_avoid_no_show');
      expect(n.label.params?['redCards'], 50);
      expect(n.label.defaultText, 'Login by 08:00 am to avoid No Show');
    });

    test('label params duplicate deadline_time to deadlineTime for templates', () {
      final n = PreActionNudge.fromMap({
        'lifecycle_action_type': 'EARLY_LOGIN',
        'nudge_kind': 'opportunity',
        'icon_url': 'https://example.com/icon.png',
        'label': {
          'key': 'nudge_early_login_earn_before',
          'params': {'deadline_time': '7:30 AM', 'coins': 3},
        },
      });
      expect(n.label.params?['deadlineTime'], '7:30 AM');
      expect(n.label.params?['coins'], 3);
    });

    test('tryFromMap returns non-null for snake_case payload', () {
      final n = PreActionNudge.tryFromMap({
        'lifecycle_action_type': 'EARLY_LOGIN',
        'nudge_kind': 'opportunity',
        'icon_url': 'https://example.com/icon.png',
        'label': {
          'key': 'nudge_early_login_avoid_no_show',
          'params': {},
        },
      });
      expect(n, isNotNull);
      expect(n!.lifecycleActionType, 'EARLY_LOGIN');
    });
  });

  group('GamificationManager.parseNudges', () {
    test('reads pre_action_nudges when preActionNudges absent', () {
      final list = GamificationManager.instance.parseNudges({
        'pre_action_nudges': [
          {
            'lifecycle_action_type': 'EARLY_LOGIN',
            'nudge_kind': 'opportunity',
            'icon_url': 'https://example.com/i.png',
            'label': {'key': 'nudge_early_login_avoid_no_show', 'params': {}},
          },
        ],
      });
      expect(list, hasLength(1));
      expect(list.single.lifecycleActionType, 'EARLY_LOGIN');
    });

    test('reads pre_action_nudges from envelope when missing in widget_data', () {
      final list = GamificationManager.instance.parseNudges(
        const {'lat': 1.0},
        {
          'pre_action_nudges': [
            {
              'lifecycle_action_type': 'EARLY_LOGIN',
              'nudge_kind': 'opportunity',
              'icon_url': 'https://example.com/i.png',
              'label': {'key': 'nudge_early_login_avoid_no_show', 'params': {}},
            },
          ],
        },
      );
      expect(list, hasLength(1));
      expect(list.single.lifecycleActionType, 'EARLY_LOGIN');
    });

    test('widget_data pre_action_nudges wins over envelope', () {
      final list = GamificationManager.instance.parseNudges(
        {
          'pre_action_nudges': [
            {
              'lifecycle_action_type': 'LATE_LOGIN',
              'nudge_kind': 'risk',
              'icon_url': 'https://example.com/i.png',
              'label': {'key': 'nudge_early_login_avoid_no_show', 'params': {}},
            },
          ],
        },
        {
          'pre_action_nudges': [
            {
              'lifecycle_action_type': 'EARLY_LOGIN',
              'nudge_kind': 'opportunity',
              'icon_url': 'https://example.com/i.png',
              'label': {'key': 'nudge_early_login_avoid_no_show', 'params': {}},
            },
          ],
        },
      );
      expect(list.single.lifecycleActionType, 'LATE_LOGIN');
    });
  });

  group('GamificationManager.resolveCtaOverridesFromNudges', () {
    test('maps cta_id case-insensitively for login lookup', () {
      final nudges = [
        PreActionNudge.fromMap({
          'lifecycle_action_type': 'EARLY_LOGIN',
          'nudge_kind': 'opportunity',
          'icon_url': 'https://example.com/i.png',
          'label': {'key': 'k', 'params': {}},
          'cta_overrides': [
            {
              'cta_id': 'LOGIN',
              'label': 'Go',
              'gold_coins': 2,
            },
          ],
        }),
      ];
      final map = GamificationManager.instance.resolveCtaOverridesFromNudges(nudges);
      expect(map['login']?.goldCoins, 2);
    });

    test('parses cta_overrides with object-shaped label (default_text)', () {
      final nudges = [
        PreActionNudge.fromMap({
          'lifecycle_action_type': 'EARLY_LOGIN',
          'nudge_kind': 'opportunity',
          'icon_url': 'https://example.com/i.png',
          'label': {'key': 'nudge_early_login_earn', 'params': {}},
          'cta_overrides': [
            {
              'cta_id': 'login',
              'label': {
                'key': 'login',
                'params': null,
                'default_text': 'Login',
              },
              'gold_coins': 10,
            },
          ],
        }),
      ];
      final map = GamificationManager.instance.resolveCtaOverridesFromNudges(nudges);
      expect(map['login'], isNotNull);
      expect(map['login']!.goldCoins, 10);
      expect(map['login']!.label?.key, 'login');
      expect(map['login']!.label?.defaultText, 'Login');
    });
  });
}
