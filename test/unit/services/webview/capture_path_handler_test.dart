import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snabbit_runner/services/webview/capture_path_handler.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';

import 'test_channel_mocks.dart';

// ---------------------------------------------------------------------------
// Fakes needed to construct a CapturePathHandler in a unit test (no real
// Android WebView platform). The CustomPathHandler constructor asserts that
// InAppWebViewPlatform.instance is non-null and delegates to it.
// ---------------------------------------------------------------------------

class _FakePlatformCustomPathHandler extends PlatformCustomPathHandler {
  _FakePlatformCustomPathHandler(PlatformCustomPathHandlerCreationParams params)
      : super.implementation(params);

  @override
  PlatformPathHandlerEvents? eventHandler;

  @override
  Future<WebResourceResponse?> handle(String path) async => null;

  @override
  Map<String, dynamic> toJson() => {};

  @override
  Map<String, dynamic> toMap() => {};

  @override
  void dispose() {}
}

class _FakeInAppWebViewPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements InAppWebViewPlatform {
  @override
  PlatformCustomPathHandler createPlatformCustomPathHandler(
    PlatformCustomPathHandlerCreationParams params,
  ) {
    return _FakePlatformCustomPathHandler(params);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  late Directory tempDir;

  setUpAll(() {
    InAppWebViewPlatform.instance = _FakeInAppWebViewPlatform();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_path_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CapturePathHandler', () {
    late CapturePathHandler handler;

    setUp(() {
      handler = CapturePathHandler(path: '/captures/');
    });

    test('returns a 200 response with correct headers for a valid token',
        () async {
      final bytes = List.generate(100, (i) => i % 256);
      final file = File('${tempDir.path}/photo.jpg')
        ..writeAsBytesSync(bytes);
      final token =
          CaptureRegistry.instance.register(file, token: 'path_hit_1');

      final response = await handler.handle('$token.jpg');

      expect(response, isNotNull);
      expect(response!.statusCode, 200);
      expect(response.contentType, 'image/jpeg');
      expect(response.reasonPhrase, 'OK');
      expect(response.headers?['Cache-Control'], 'no-store');
      expect(response.headers?['Content-Length'], '${bytes.length}');
      expect(response.headers?['X-Capture-Token'], token);
      expect(response.data, isNotNull);

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });

    test('returns a null-data response for an unknown token', () async {
      final response = await handler.handle('unknown_token_999.jpg');

      expect(response, isNotNull);
      expect(response!.data, isNull);
    });

    test('returns a distinct 413 (not 404) for an oversize file', () async {
      // Defense-in-depth: capture-time enforcement should prevent this, but
      // if an oversize file is ever served, the web must be able to tell it
      // apart from a missing/expired token (404).
      final file = File('${tempDir.path}/huge.jpg')
        ..writeAsBytesSync(Uint8List(CaptureRegistry.maxCaptureSizeBytes + 1));
      final token =
          CaptureRegistry.instance.register(file, token: 'path_oversize_1');

      final response = await handler.handle('$token.jpg');

      expect(response, isNotNull);
      expect(response!.statusCode, 413);
      expect(response.data, isNull);
      // CORS headers present even on the error response.
      expect(response.headers?['Access-Control-Allow-Origin'], '*');

      await CaptureRegistry.instance.evict(token);
    });

    test('404 responses still carry CORS headers', () async {
      final response = await handler.handle('unknown_cors_check.jpg');

      expect(response, isNotNull);
      expect(response!.statusCode, 404);
      expect(response.headers?['Access-Control-Allow-Origin'], '*');
      expect(response.headers?['Access-Control-Allow-Methods'], 'GET, OPTIONS');
    });

    test('returns a null-data response for an expired token', () async {
      final file = File('${tempDir.path}/expired.jpg')
        ..writeAsBytesSync([0xFF]);
      CaptureRegistry.instance.register(
        file,
        token: 'path_expired_1',
        ttl: Duration.zero,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final response = await handler.handle('path_expired_1.jpg');
      expect(response, isNotNull);
      expect(response!.data, isNull);
    });

    test('returns a null-data response when file has been deleted', () async {
      final file = File('${tempDir.path}/deleted.jpg')
        ..writeAsBytesSync([0xFF]);
      final token =
          CaptureRegistry.instance.register(file, token: 'path_deleted_1');

      // Delete the file out-of-band.
      file.deleteSync();

      final response = await handler.handle('$token.jpg');
      expect(response, isNotNull);
      expect(response!.data, isNull);

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });

    test('strips .jpg extension to find the token', () async {
      final bytes = [0xFF, 0xD8, 0xFF, 0xE0];
      final file = File('${tempDir.path}/strip.jpg')
        ..writeAsBytesSync(bytes);
      final token =
          CaptureRegistry.instance.register(file, token: 'strip_test');

      // Handler receives "strip_test.jpg", should resolve "strip_test".
      final response = await handler.handle('strip_test.jpg');

      expect(response, isNotNull);
      expect(response!.statusCode, 200);
      expect(response.headers?['X-Capture-Token'], 'strip_test');

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });

    test('handles path with directory prefix', () async {
      final bytes = [0xFF, 0xD8];
      final file = File('${tempDir.path}/nested.jpg')
        ..writeAsBytesSync(bytes);
      final token =
          CaptureRegistry.instance.register(file, token: 'nested_token');

      // Path could arrive as "captures/nested_token.jpg" — handler splits
      // on '/' and takes the last segment.
      final response = await handler.handle('captures/nested_token.jpg');

      expect(response, isNotNull);
      expect(response!.statusCode, 200);

      // Cleanup
      await CaptureRegistry.instance.evict(token);
    });
  });
}
