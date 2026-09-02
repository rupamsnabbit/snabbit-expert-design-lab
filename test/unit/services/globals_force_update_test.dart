import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/app_config.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/app_strings.dart';

import 'webview/test_channel_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  final state = GlobalState();

  Future<void> reset({int skipped = 0}) async {
    SharedPreferences.setMockInitialValues({
      AppStrings.versionCodeSkipped: skipped,
    });
    state.prefs = await SharedPreferences.getInstance();
    state.appConfig = null;
    state.latestVersionCode = null;
    state.runnerMinAndroidVersion = null;
    state.runnerSkipAndroidVersion = null;
  }

  setUp(() async => reset());

  group('isAndroidUpdateRequired — global (app_config) floor', () {
    test('below global floor forces update (not-logged-in: runner null)',
        () async {
      state.appConfig = AppConfig(minAndroidVersion: 10);
      state.latestVersionCode = 5;
      expect(state.runnerMinAndroidVersion, isNull);
      expect(state.isAndroidUpdateRequired(), isTrue);
    });

    test('at/above global floor does not force', () async {
      state.appConfig = AppConfig(minAndroidVersion: 10);
      state.latestVersionCode = 15;
      expect(state.isAndroidUpdateRequired(), isFalse);
    });

    test('invalid version code forces update', () async {
      state.appConfig = AppConfig(invalidVersionCodes: [15]);
      state.latestVersionCode = 15;
      expect(state.isAndroidUpdateRequired(), isTrue);
    });
  });

  group('isAndroidUpdateRequired — runner (/me) floor', () {
    test('below runner floor forces update (no global floor)', () async {
      state.runnerMinAndroidVersion = 10;
      state.latestVersionCode = 5;
      expect(state.isAndroidUpdateRequired(), isTrue);
    });

    test('at/above runner floor does not force', () async {
      state.runnerMinAndroidVersion = 10;
      state.latestVersionCode = 15;
      expect(state.isAndroidUpdateRequired(), isFalse);
    });
  });

  group('isAndroidUpdateRequired — both floors (stricter wins)', () {
    test('runner floor stricter than global', () async {
      state.appConfig = AppConfig(minAndroidVersion: 10);
      state.runnerMinAndroidVersion = 20;
      state.latestVersionCode = 15; // below runner, above global
      expect(state.isAndroidUpdateRequired(), isTrue);
    });

    test('global floor stricter than runner', () async {
      state.appConfig = AppConfig(minAndroidVersion: 20);
      state.runnerMinAndroidVersion = 10;
      state.latestVersionCode = 15; // below global, above runner
      expect(state.isAndroidUpdateRequired(), isTrue);
    });

    test('above both floors does not force', () async {
      state.appConfig = AppConfig(minAndroidVersion: 10);
      state.runnerMinAndroidVersion = 20;
      state.latestVersionCode = 25;
      expect(state.isAndroidUpdateRequired(), isFalse);
    });
  });

  group('isSkipAndroidUpdateRequired — global + runner floors', () {
    test('below global skip floor, not yet skipped → prompt', () async {
      await reset();
      state.appConfig = AppConfig(skipAndroidVersion: 10);
      state.latestVersionCode = 5;
      expect(state.isSkipAndroidUpdateRequired(), isTrue);
    });

    test('below runner skip floor, not yet skipped → prompt', () async {
      await reset();
      state.runnerSkipAndroidVersion = 10;
      state.latestVersionCode = 5;
      expect(state.isSkipAndroidUpdateRequired(), isTrue);
    });

    test('runner skip floor stricter than global', () async {
      await reset();
      state.appConfig = AppConfig(skipAndroidVersion: 10);
      state.runnerSkipAndroidVersion = 20;
      state.latestVersionCode = 15;
      expect(state.isSkipAndroidUpdateRequired(), isTrue);
    });

    test('already skipped at/above the floor → no prompt', () async {
      await reset(skipped: 12);
      state.appConfig = AppConfig(skipAndroidVersion: 10);
      state.latestVersionCode = 5;
      expect(state.isSkipAndroidUpdateRequired(), isFalse);
    });

    test('above the skip floor → no prompt', () async {
      await reset();
      state.appConfig = AppConfig(skipAndroidVersion: 10);
      state.latestVersionCode = 15;
      expect(state.isSkipAndroidUpdateRequired(), isFalse);
    });
  });
}
