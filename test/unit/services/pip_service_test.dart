import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/pip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methodChannel = MethodChannel('com.snabbit.runner/pip');

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  group('setPipEnabled', () {
    test('pushes the MQTT/KMP-cohort disable (enabled:false)', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await PipService.setPipEnabled(false);

      expect(received?.method, 'setPipEnabled');
      expect(received?.arguments, {'enabled': false});
    });

    test('pushes the Flutter-cohort enable (enabled:true)', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        received = call;
        return null;
      });

      await PipService.setPipEnabled(true);

      expect(received?.method, 'setPipEnabled');
      expect(received?.arguments, {'enabled': true});
    });

    test('never throws when the platform side errors', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'boom');
      });

      await expectLater(PipService.setPipEnabled(true), completes);
    });
  });
}
