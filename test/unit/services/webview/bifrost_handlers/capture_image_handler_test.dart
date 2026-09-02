import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/capture_image_handler.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';

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

/// Tracks calls and returns a configurable result.
class _MockImageCapturer {
  int callCount = 0;
  File? result;

  Future<File?> call() async {
    callCount++;
    return result;
  }
}

String _testUrlBuilder(String token) =>
    'https://appassets.androidplatform.net/captures/$token.jpg';

/// Default: always grants camera permission.
Future<PermissionStatus> _alwaysGranted(Permission _) async =>
    PermissionStatus.granted;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  late Directory tempDir;
  late _MockImageCapturer capturer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_handler_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    capturer = _MockImageCapturer();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// No-op error reporter — avoids needing Firebase initialised in tests.
  Future<void> noOpReporter(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {}

  CaptureImageHandler buildHandler({
    PermissionRequester? permissionRequester,
  }) =>
      CaptureImageHandler(
        captureCallback: capturer.call,
        urlBuilder: _testUrlBuilder,
        permissionRequester: permissionRequester ?? _alwaysGranted,
        errorReporter: noOpReporter,
      );

  group('CaptureImageHandler', () {
    test('is an RPC handler named "captureImage"', () {
      final h = buildHandler();
      expect(h.pattern, BifrostPattern.rpc);
      expect(h.actionName, 'captureImage');
    });

    test('returns url and token on successful capture', () async {
      // Create a "captured" image file.
      final sourceFile = File('${tempDir.path}/source.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      capturer.result = sourceFile;

      final h = buildHandler();
      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!['url'], isA<String>());
      expect(result.data!['token'], isA<String>());
      expect(
        (result.data!['url'] as String)
            .startsWith('https://appassets.androidplatform.net/captures/'),
        isTrue,
      );
      expect(
        (result.data!['url'] as String).endsWith('.jpg'),
        isTrue,
      );

      // The token should be resolvable in the registry.
      final token = result.data!['token'] as String;
      final resolved = CaptureRegistry.instance.resolve(token);
      expect(resolved, isNotNull);

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });

    test('returns USER_CANCELLED when capturer returns null', () async {
      capturer.result = null;

      final h = buildHandler();
      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(capturer.callCount, 1);
    });

    test('returns FILE_TOO_LARGE when the capture exceeds the size cap',
        () async {
      // A source just over the servable cap; the handler copies it and
      // checks the target size before registering.
      final big = File('${tempDir.path}/big.jpg')
        ..writeAsBytesSync(Uint8List(CaptureRegistry.maxCaptureSizeBytes + 1));
      capturer.result = big;

      final h = buildHandler();
      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.code, BifrostErrorCodes.fileTooLarge);
      // details carry the sizes so the web can message the user.
      expect(result.error!.details?['maxBytes'],
          CaptureRegistry.maxCaptureSizeBytes);
      expect(result.error!.details?['fileSizeBytes'],
          CaptureRegistry.maxCaptureSizeBytes + 1);
    });

    test('returns USER_CANCELLED when cancelled during the permission sheet',
        () async {
      // permission denied → sheet shown → web sends cancelCapture mid-sheet.
      late final CaptureImageHandler h;
      h = CaptureImageHandler(
        captureCallback: capturer.call,
        urlBuilder: _testUrlBuilder,
        permissionRequester: (_) async => PermissionStatus.permanentlyDenied,
        onPermissionDenied: (_) async {
          // Simulate the web aborting while the sheet is open.
          h.cancel();
          return false; // sheet dismissed without granting
        },
        errorReporter: noOpReporter,
      );

      final result = await h.handle(const {});

      expect(result.error, isNotNull);
      // The mid-sheet cancel must resolve as USER_CANCELLED, not
      // PERMISSION_DENIED, and the camera is never opened.
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(capturer.callCount, 0);
    });

    test('returns CAPTURE_IN_PROGRESS for concurrent requests', () async {
      // Use a completer-style delay so we can issue a second request while
      // the first is still pending.
      final h = CaptureImageHandler(
        captureCallback: () async {
          // Simulate a slow capture.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return null;
        },
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        errorReporter: noOpReporter,
      );

      // Fire first request (don't await).
      final first = h.handle(const {});

      // Immediately fire second request — first is still in flight.
      final second = await h.handle(const {});

      expect(second.error, isNotNull);
      expect(second.error!.code, BifrostErrorCodes.captureInProgress);

      // Wait for first to finish.
      final firstResult = await first;
      expect(firstResult.error!.code, BifrostErrorCodes.userCancelled);
    });

    test('resets reentrancy guard after completion', () async {
      capturer.result = null;
      final h = buildHandler();

      // First call — cancelled.
      final r1 = await h.handle(const {});
      expect(r1.error!.code, BifrostErrorCodes.userCancelled);

      // Second call should not be blocked.
      final r2 = await h.handle(const {});
      expect(r2.error!.code, BifrostErrorCodes.userCancelled);

      expect(capturer.callCount, 2);
    });

    test('returns INTERNAL_ERROR when capture throws', () async {
      final h = CaptureImageHandler(
        captureCallback: () async {
          throw Exception('Camera hardware failure');
        },
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        errorReporter: noOpReporter,
      );

      final result = await h.handle(const {});

      expect(result.error, isNotNull);
      expect(result.error!.code, BifrostErrorCodes.internalError);
    });

    test('resets reentrancy guard even if capture throws', () async {
      final h = CaptureImageHandler(
        captureCallback: () async {
          throw Exception('Camera hardware failure');
        },
        urlBuilder: _testUrlBuilder,
        permissionRequester: _alwaysGranted,
        errorReporter: noOpReporter,
      );

      // First call — caught internally, returns INTERNAL_ERROR.
      final r1 = await h.handle(const {});
      expect(r1.error!.code, BifrostErrorCodes.internalError);

      // Guard should be reset via finally block — next call on the SAME
      // handler instance should not return CAPTURE_IN_PROGRESS.
      final r2 = await h.handle(const {});
      expect(r2.error!.code, BifrostErrorCodes.internalError);
    });

    test('copies file to captures dir, not using original path', () async {
      final sourceFile = File('${tempDir.path}/original.jpg')
        ..writeAsBytesSync([0xFF, 0xD8]);
      capturer.result = sourceFile;

      final h = buildHandler();
      final result = await h.handle(const {});

      final token = result.data!['token'] as String;
      final resolved = CaptureRegistry.instance.resolve(token);

      // The resolved file should NOT be the original path.
      expect(resolved!.path, isNot(sourceFile.path));
      expect(resolved.path, contains('/captures/'));

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });

    test('url builder receives the correct token', () async {
      final sourceFile = File('${tempDir.path}/url_test.jpg')
        ..writeAsBytesSync([0xFF]);
      capturer.result = sourceFile;

      String? capturedToken;
      final h = CaptureImageHandler(
        captureCallback: capturer.call,
        urlBuilder: (token) {
          capturedToken = token;
          return 'https://test.com/$token.jpg';
        },
        permissionRequester: _alwaysGranted,
        errorReporter: noOpReporter,
      );

      final result = await h.handle(const {});
      expect(capturedToken, isNotNull);
      expect(capturedToken, result.data!['token']);

      // Cleanup
      await CaptureRegistry.instance.evict(result.data!['token'] as String);
    });
  });

  group('CaptureImageHandler permission gate', () {
    test('returns PERMISSION_DENIED when camera permission is denied',
        () async {
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.denied,
      );

      final result = await h.handle(const {});

      expect(result.data, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.code, BifrostErrorCodes.permissionDenied);
      expect(result.error!.details?['permission'], 'camera');
      expect(result.error!.details?['status'], 'denied');

      // The capturer should never have been called.
      expect(capturer.callCount, 0);
    });

    test(
        'returns PERMISSION_DENIED when camera permission is permanentlyDenied',
        () async {
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.permanentlyDenied,
      );

      final result = await h.handle(const {});

      expect(result.error!.code, BifrostErrorCodes.permissionDenied);
      expect(result.error!.details?['status'], 'permanentlyDenied');
      expect(capturer.callCount, 0);
    });

    test('returns PERMISSION_DENIED when camera permission is restricted',
        () async {
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.restricted,
      );

      final result = await h.handle(const {});

      expect(result.error!.code, BifrostErrorCodes.permissionDenied);
      expect(result.error!.details?['status'], 'restricted');
      expect(capturer.callCount, 0);
    });

    test('proceeds with capture when permission is granted', () async {
      capturer.result = null;
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.granted,
      );

      final result = await h.handle(const {});

      // Permission passed → capture was called → user cancelled.
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(capturer.callCount, 1);
    });

    test('proceeds with capture when permission is limited', () async {
      capturer.result = null;
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.limited,
      );

      final result = await h.handle(const {});
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(capturer.callCount, 1);
    });

    test('proceeds with capture when permission is provisional', () async {
      capturer.result = null;
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.provisional,
      );

      final result = await h.handle(const {});
      expect(result.error!.code, BifrostErrorCodes.userCancelled);
      expect(capturer.callCount, 1);
    });

    test('resets reentrancy guard after permission denial', () async {
      final h = buildHandler(
        permissionRequester: (_) async => PermissionStatus.denied,
      );

      // First call — permission denied.
      final r1 = await h.handle(const {});
      expect(r1.error!.code, BifrostErrorCodes.permissionDenied);

      // Second call should NOT return CAPTURE_IN_PROGRESS.
      final r2 = await h.handle(const {});
      expect(r2.error!.code, BifrostErrorCodes.permissionDenied);
    });
  });
}
