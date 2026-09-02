import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/debug/runner_app_current_state_stubs.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/runner_http.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RunnerAppCurrentStateStubs catalog', () {
    test('every preset has widget_name and widget_data map', () {
      for (final stub in RunnerAppCurrentStateStub.values) {
        final m = RunnerAppCurrentStateStubs.body(stub);
        expect(m['widget_name'], isNotNull);
        expect(m['widget_name'], isNotEmpty);
        expect(m['widget_data'], isA<Map<String, dynamic>>());
      }
    });
  });

  group('RunnerHttp.runnerAppCurrentState debug stub', () {
    test(
      'returns 200 with GlobalState body when stub is set in debug mode',
      () async {
      final gs = GlobalState();
      final previous = gs.debugStubRunnerAppCurrentStateBody;
      addTearDown(() {
        gs.debugStubRunnerAppCurrentStateBody = previous;
      });

      gs.debugStubRunnerAppCurrentStateBody = {
        'widget_name': 'RUNNER_LOGOUT',
        'widget_data': <String, dynamic>{},
      };

      final response = await RunnerHttp.runnerAppCurrentState();

      expect(response, isNotNull);
      expect(response!.statusCode, 200);
      expect(response.data, isA<Map<String, dynamic>>());
      expect(response.data['widget_name'], 'RUNNER_LOGOUT');
      },
      skip: kDebugMode
          ? false
          : 'Stub is only compiled for debug mode (kDebugMode)',
    );
  });
}
