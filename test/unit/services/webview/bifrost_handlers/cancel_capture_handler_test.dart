import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/cancel_capture_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/capture_image_handler.dart';

import '../test_channel_mocks.dart';

/// Fake [PathProviderPlatform] that returns a temp directory for all queries.
class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this._tempPath);

  final String _tempPath;

  @override
  Future<String?> getTemporaryPath() async => _tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempPath;
}

String _testUrlBuilder(String token) =>
    'https://appassets.androidplatform.net/captures/$token.jpg';

Future<PermissionStatus> _alwaysGranted(Permission _) async =>
    PermissionStatus.granted;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cancel_handler_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CancelCaptureHandler', () {
    test('is a fire-and-forget handler named "cancelCapture"', () {
      final captureHandler = CaptureImageHandler(
        captureCallback: () async => null,
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
      );

      final handler = CancelCaptureHandler(captureHandler: captureHandler);
      expect(handler.pattern, BifrostPattern.fireAndForget);
      expect(handler.actionName, 'cancelCapture');
    });

    test('no-op when no capture is in flight', () async {
      var dismissCalled = false;
      final captureHandler = CaptureImageHandler(
        captureCallback: () async => null,
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        dismissCapture: () => dismissCalled = true,
      );

      final handler = CancelCaptureHandler(captureHandler: captureHandler);
      final result = await handler.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNull);
      expect(dismissCalled, isFalse);
    });

    test('calls dismiss when capture is in flight', () async {
      var dismissCalled = false;
      final captureCompleter = Completer<File?>();

      final captureHandler = CaptureImageHandler(
        captureCallback: () => captureCompleter.future,
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        dismissCapture: () => dismissCalled = true,
      );

      // Start a capture (don't await — it blocks until completer resolves).
      final captureFuture = captureHandler.handle(const {});

      // Now cancel while capture is in flight.
      final cancelHandler =
          CancelCaptureHandler(captureHandler: captureHandler);
      await cancelHandler.handle(const {});

      expect(dismissCalled, isTrue);

      // Complete the capture so the future resolves.
      captureCompleter.complete(null);
      final captureResult = await captureFuture;
      expect(captureResult.error!.code, BifrostErrorCodes.userCancelled);
    });

    test('cancel resets so next capture is not blocked', () async {
      final captureCompleter = Completer<File?>();

      final captureHandler = CaptureImageHandler(
        captureCallback: () => captureCompleter.future,
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        dismissCapture: () {},
      );

      // Start and cancel.
      final captureFuture = captureHandler.handle(const {});
      captureHandler.cancel();
      captureCompleter.complete(null);
      await captureFuture;

      // Next capture should NOT get CAPTURE_IN_PROGRESS.
      final secondHandler = CaptureImageHandler(
        captureCallback: () async => null,
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
      );
      final result = await secondHandler.handle(const {});
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
    });
  });
}
