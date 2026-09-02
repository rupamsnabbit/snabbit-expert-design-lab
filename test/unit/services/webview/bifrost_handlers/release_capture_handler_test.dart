import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/release_capture_handler.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';

import '../test_channel_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('release_handler_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReleaseCaptureHandler', () {
    test('is a fire-and-forget handler named "releaseCapture"', () {
      final h = ReleaseCaptureHandler();
      expect(h.pattern, BifrostPattern.fireAndForget);
      expect(h.actionName, 'releaseCapture');
    });

    test('evicts a valid token from the registry', () async {
      final file = File('${tempDir.path}/to_release.jpg')
        ..writeAsBytesSync([0xFF]);
      final token = CaptureRegistry.instance.register(
        file,
        token: 'release_test_1',
      );

      // Verify it's registered.
      expect(CaptureRegistry.instance.resolve(token), isNotNull);

      final h = ReleaseCaptureHandler();
      final result = await h.handle({'token': token});

      expect(result.data, isNull);
      expect(result.error, isNull);
      // Token should no longer resolve.
      expect(CaptureRegistry.instance.resolve(token), isNull);
      // File should be deleted.
      expect(file.existsSync(), isFalse);
    });

    test('returns empty result for unknown token', () async {
      final h = ReleaseCaptureHandler();
      final result = await h.handle({'token': 'nonexistent_release_token'});

      expect(result.data, isNull);
      expect(result.error, isNull);
    });

    test('returns empty result when token is null', () async {
      final h = ReleaseCaptureHandler();
      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNull);
    });

    test('returns empty result when token is empty string', () async {
      final h = ReleaseCaptureHandler();
      final result = await h.handle({'token': ''});

      expect(result.data, isNull);
      expect(result.error, isNull);
    });

    test('returns empty result when token is non-string', () async {
      final h = ReleaseCaptureHandler();
      // The `as String?` cast in the handler will return null for non-string.
      final result = await h.handle({'token': 42});

      expect(result.data, isNull);
      expect(result.error, isNull);
    });
  });
}
