// Regression test for the "Login button instead of Accept on a new-job screen"
// bug (ECPO-173 follow-up, runner 3238961).
//
// Root cause: applyCachedStateIfFresh() updated `widgetInfo` from the FCM job
// push cache but did NOT rebuild `widgetUtil`. _fetchData then captured
// oldWidgetName from the (updated) widgetInfo but oldBottomButton from the
// (stale) widgetUtil, and the RUNNER_NEW_JOB bottom-button preservation logic
// re-applied the stale "Login" button — so the new-job screen rendered with a
// "Login" CTA and never installed "Accept".
//
// Fix: rebuild widgetUtil in lockstep with widgetInfo in the cache path.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/widgets_util.dart';

/// Stands in for the real provider on the fetch branch: counts the attempt and
/// fails the way a dead network would, without dragging the HTTP stack (and its
/// platform plugins) into a unit test.
class _ThrowingFetchProvider extends RunnerRtDataProvider {
  _ThrowingFetchProvider()
    : super(
        periodLeave: PeriodLeaveProvider(),
        userProfile: UserProfileProvider(),
      );

  int fetchAttempts = 0;

  @override
  Future<void> fetchCurrentState() async {
    fetchAttempts++;
    throw StateError('current_state unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The provider fires monitoring logs (expert_state_sync) via platform
    // channels that don't exist in a unit test. Stub them so the fire-and-forget
    // logInfo calls don't raise unhandled MissingPluginExceptions.
    for (final name in const [
      'cx_flutter_plugin',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  group('RunnerRtDataProvider.applyCachedStateIfFresh', () {
    test('rebuilds widgetUtil in lockstep so a stale Login button is NOT carried '
        'into a RUNNER_NEW_JOB state', () async {
      final provider = RunnerRtDataProvider(
        periodLeave: PeriodLeaveProvider(),
        userProfile: UserProfileProvider(),
      );

      // Stale state: runner was on the hotspot-login screen, whose bottom
      // button is the "Login" CTA (AutoLoginBottomActionButton).
      provider.widgetInfo = WidgetInfo(name: 'RUNNER_LOGIN_HOTSPOT', data: {});
      provider.widgetUtil = getRunnerStateWidgetUtil(provider.widgetInfo);
      expect(
        provider.widgetUtil?.bottomButton,
        isNotNull,
        reason: 'RUNNER_LOGIN_HOTSPOT must provide a Login bottom button',
      );

      // An FCM job push wrote a fresh RUNNER_NEW_JOB current_state to the cache.
      SharedPreferences.setMockInitialValues({
        'cached_current_state': jsonEncode({
          'widget_name': 'RUNNER_NEW_JOB',
          'widget_data': {},
        }),
        'cached_current_state_ts':
            DateTime.now().millisecondsSinceEpoch - 1000, // 1s old => fresh
      });

      await provider.applyCachedStateIfFresh();

      // The cached state was applied...
      expect(provider.widgetInfo?.name, 'RUNNER_NEW_JOB');
      // ...and widgetUtil was rebuilt in lockstep, so the stale "Login" button
      // is gone (slot null => NewJobAssigned installs "Accept"). Pre-fix this
      // slot still held the Login button and the screen showed "Login".
      expect(
        provider.widgetUtil?.bottomButton,
        isNull,
        reason:
            'cache-apply must reset the bottom button to match the new widget',
      );
    });

    test('contract: RUNNER_NEW_JOB starts with an empty bottom-button slot', () {
      final w = getRunnerStateWidgetUtil(
        WidgetInfo(name: 'RUNNER_NEW_JOB', data: {}),
      );
      expect(
        w.bottomButton,
        isNull,
        reason:
            'NewJobAssigned relies on an empty slot to install its Accept button',
      );
    });
  });

  group('RunnerRtDataProvider.showLunchSelection fold', () {
    RunnerRtDataProvider makeProvider() => RunnerRtDataProvider(
      periodLeave: PeriodLeaveProvider(),
      userProfile: UserProfileProvider(),
    );

    void seedCache(Map<String, dynamic> envelope) {
      SharedPreferences.setMockInitialValues({
        'cached_current_state': jsonEncode(envelope),
        'cached_current_state_ts':
            DateTime.now().millisecondsSinceEpoch - 1000, // 1s old => fresh
      });
    }

    test('bg-cache apply folds show_lunch_selection, and an envelope without '
        'the key clears it (older backend never flashes the banner)', () async {
      final provider = makeProvider();
      expect(provider.showLunchSelection, isFalse, reason: 'default hidden');

      seedCache({
        'widget_name': 'RUNNER_WAIT_HOTSPOT',
        'widget_data': {},
        'show_lunch_selection': true,
      });
      await provider.applyCachedStateIfFresh();
      expect(provider.showLunchSelection, isTrue);

      seedCache({'widget_name': 'RUNNER_WAIT_HOTSPOT', 'widget_data': {}});
      await provider.applyCachedStateIfFresh();
      expect(provider.showLunchSelection, isFalse);
    });

    test('a non-boolean value keeps the banner hidden', () async {
      final provider = makeProvider();
      seedCache({
        'widget_name': 'RUNNER_WAIT_HOTSPOT',
        'widget_data': {},
        'show_lunch_selection': 'maybe',
      });
      await provider.applyCachedStateIfFresh();
      expect(provider.showLunchSelection, isFalse);
    });

    test('cohort-parity guard: a string "true" stays hidden (the KMP projector '
        'rejects string-typed values for the same reason)', () async {
      final provider = makeProvider();
      seedCache({
        'widget_name': 'RUNNER_WAIT_HOTSPOT',
        'widget_data': {},
        'show_lunch_selection': 'true',
      });
      await provider.applyCachedStateIfFresh();
      expect(provider.showLunchSelection, isFalse);
    });

    test(
      'resetForNewSession clears the flag so it cannot leak across logins',
      () async {
        final provider = makeProvider();
        seedCache({
          'widget_name': 'RUNNER_WAIT_HOTSPOT',
          'widget_data': {},
          'show_lunch_selection': true,
        });
        await provider.applyCachedStateIfFresh();
        expect(provider.showLunchSelection, isTrue);

        provider.resetForNewSession();

        expect(provider.showLunchSelection, isFalse);
      },
    );

    test('bridge snapshot folds the flag for the mqtt cohort '
        '(camelCase alias honoured)', () {
      final provider = makeProvider();
      provider.beginMqttCohortAttempt(); // bridge applies only for the cohort

      provider.applyBridgeSnapshot(
        jsonEncode({
          'widget_name': 'RUNNER_WAIT_HOTSPOT',
          'widget_data': {},
          'showLunchSelection': true,
        }),
      );
      expect(provider.showLunchSelection, isTrue);

      provider.applyBridgeSnapshot(
        jsonEncode({'widget_name': 'RUNNER_WAIT_HOTSPOT', 'widget_data': {}}),
      );
      expect(provider.showLunchSelection, isFalse);
    });
  });

  group('RunnerRtDataProvider lunch_banner_shown impression', () {
    // Owned by the provider, not the banner widget: a widget-held guard resets on
    // dispose and would re-count every return to the home.
    late List<String> tracked;

    setUp(() {
      tracked = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.snabbit.runner/analytics'),
            (call) async {
              if (call.method == 'track') {
                tracked.add((call.arguments as Map)['name'] as String);
              }
              return null;
            },
          );
    });

    RunnerRtDataProvider makeProvider() => RunnerRtDataProvider(
      periodLeave: PeriodLeaveProvider(),
      userProfile: UserProfileProvider(),
    );

    test('fires once on the hidden->shown edge, not on a repeat of the same '
        'value', () async {
      final provider = makeProvider();
      expect(tracked, isEmpty);

      provider.showLunchSelection = true;
      provider.showLunchSelection = true; // same value, no re-fire
      await Future<void>.delayed(Duration.zero);

      expect(tracked, ['lunch_banner_shown']);
    });

    test('a real off->on re-flip counts again', () async {
      final provider = makeProvider()..showLunchSelection = true;
      provider.showLunchSelection = false;
      provider.showLunchSelection = true;
      await Future<void>.delayed(Duration.zero);

      expect(tracked, ['lunch_banner_shown', 'lunch_banner_shown']);
    });

    test('resetForNewSession clears without counting an impression', () async {
      final provider = makeProvider()..showLunchSelection = true;
      tracked.clear();

      provider.resetForNewSession();
      await Future<void>.delayed(Duration.zero);

      expect(provider.showLunchSelection, isFalse);
      expect(tracked, isEmpty);
    });
  });

  group('RunnerRtDataProvider.refreshCurrentStateAfterWebview', () {
    /// Records every call on the KMP realtime bridge so the cohort branch can
    /// be observed without a native plugin.
    List<String> stubRealtimeChannel() {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.snabbit.runner/realtime'),
            (call) async {
              calls.add(call.method);
              return null;
            },
          );
      return calls;
    }

    RunnerRtDataProvider makeProvider() => RunnerRtDataProvider(
      periodLeave: PeriodLeaveProvider(),
      userProfile: UserProfileProvider(),
    );

    test('realtime cohort WAKEs the MQTT engine instead of polling — the '
        'cohort must never re-introduce a Dart current_state fetch', () async {
      final calls = stubRealtimeChannel();
      final provider = makeProvider();
      provider.beginMqttCohortAttempt();
      provider.confirmMqttCohort();

      await provider.refreshCurrentStateAfterWebview();
      // wake() is fire-and-forget inside the method; let its invoke land.
      await Future<void>.delayed(Duration.zero);

      expect(calls, contains('wake'));
    });

    test('a pending (not yet confirmed) cohort attempt also WAKEs — the gate '
        'is _mqttCohortActive, so there is no mount/confirm race', () async {
      final calls = stubRealtimeChannel();
      final provider = makeProvider();
      provider.beginMqttCohortAttempt(); // pending, NOT confirmed

      await provider.refreshCurrentStateAfterWebview();
      await Future<void>.delayed(Duration.zero);

      expect(calls, contains('wake'));
    });

    test('a failing fetch is swallowed, not rethrown — callers fire this from '
        'dispose() and cannot catch an unhandled async error', () async {
      stubRealtimeChannel();
      // Flutter cohort => the fetch branch. fetchCurrentState is overridden to
      // throw rather than driving the real HTTP stack, so this asserts the
      // catch and nothing else.
      final provider = _ThrowingFetchProvider();

      await expectLater(provider.refreshCurrentStateAfterWebview(), completes);
      expect(provider.fetchAttempts, 1, reason: 'the fetch branch was taken');
    });

    test('the Flutter cohort fetches, never wakes the engine', () async {
      final calls = stubRealtimeChannel();
      final provider = _ThrowingFetchProvider();

      await provider.refreshCurrentStateAfterWebview();
      await Future<void>.delayed(Duration.zero);

      expect(calls, isEmpty);
      expect(provider.fetchAttempts, 1);
    });
  });

  group('RunnerRtDataProvider mqtt-cohort double-open guard', () {
    test(
      'beginMqttCohortAttempt starts once, then no-ops while pending or '
      'confirmed — a re-fired login route cannot stack a second KMP host',
      () {
        final provider = RunnerRtDataProvider(
          periodLeave: PeriodLeaveProvider(),
          userProfile: UserProfileProvider(),
        );

        // First attempt starts (stands the poll down synchronously).
        expect(provider.beginMqttCohortAttempt(), isTrue);
        // A re-fire while the attempt is still PENDING is a no-op.
        expect(provider.beginMqttCohortAttempt(), isFalse);

        // Once CONFIRMED, a re-fire is still a no-op — the cohort is on KMP.
        provider.confirmMqttCohort();
        expect(provider.isMqttCohort, isTrue);
        expect(provider.beginMqttCohortAttempt(), isFalse);
      },
    );
  });
}
