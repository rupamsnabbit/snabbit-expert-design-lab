import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';

import 'test_channel_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_registry_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CaptureRegistry', () {
    test('register returns a non-empty token', () async {
      final file = File('${tempDir.path}/img.jpg')..writeAsBytesSync([0xFF]);
      final token = CaptureRegistry.instance.register(file);

      expect(token, isNotEmpty);

      // Cleanup
      CaptureRegistry.instance.evict(token);
    });

    test('register uses the provided token when given', () async {
      final file = File('${tempDir.path}/img.jpg')..writeAsBytesSync([0xFF]);
      final token =
          CaptureRegistry.instance.register(file, token: 'my_custom_token');

      expect(token, 'my_custom_token');

      // Cleanup
      CaptureRegistry.instance.evict(token);
    });

    test('resolve returns the file for a valid token', () async {
      final file = File('${tempDir.path}/img.jpg')..writeAsBytesSync([0xFF]);
      final token = CaptureRegistry.instance.register(file, token: 'valid1');

      final resolved = CaptureRegistry.instance.resolve(token);

      expect(resolved, isNotNull);
      expect(resolved!.path, file.path);

      // Cleanup
      CaptureRegistry.instance.evict(token);
    });

    test('resolve returns null for an unknown token', () {
      final resolved =
          CaptureRegistry.instance.resolve('unknown_token_xyz_123');
      expect(resolved, isNull);
    });

    test('resolve returns null and evicts an expired token', () async {
      final file = File('${tempDir.path}/expired.jpg')
        ..writeAsBytesSync([0xFF]);
      final token = CaptureRegistry.instance.register(
        file,
        token: 'expired1',
        ttl: Duration.zero,
      );

      // Wait a tiny bit so the TTL is definitely past.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final resolved = CaptureRegistry.instance.resolve(token);
      expect(resolved, isNull);

      // Second resolve should also be null (entry was removed).
      final second = CaptureRegistry.instance.resolve(token);
      expect(second, isNull);
    });

    test('evict removes the entry and deletes the file', () async {
      final file = File('${tempDir.path}/to_evict.jpg')
        ..writeAsBytesSync([0xFF]);
      final token = CaptureRegistry.instance.register(
        file,
        token: 'evict1',
      );

      expect(CaptureRegistry.instance.resolve(token), isNotNull);

      await CaptureRegistry.instance.evict(token);

      expect(CaptureRegistry.instance.resolve(token), isNull);
      // File should be deleted (best-effort).
      expect(file.existsSync(), isFalse);
    });

    test('evict is a no-op for unknown tokens', () async {
      // Should not throw.
      await CaptureRegistry.instance.evict('nonexistent_token_abc');
    });
  });

  group('CaptureRegistry.sweepStale', () {
    test('clears all capture files regardless of age', () async {
      final capturesDir = Directory('${tempDir.path}/captures')..createSync();
      final old = File('${capturesDir.path}/old.jpg')
        ..writeAsBytesSync([0xFF, 0xD8]);
      // Backdate one; age must not matter — everything is cleared.
      await old.setLastModified(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      final recent = File('${capturesDir.path}/recent.jpg')
        ..writeAsBytesSync([0xFF, 0xD8]);

      await CaptureRegistry.sweepStale(capturesDir);

      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isFalse);
      expect(capturesDir.existsSync(), isFalse);
    });

    test('no-ops when directory does not exist', () async {
      final missing = Directory('${tempDir.path}/does_not_exist');
      // Should not throw.
      await CaptureRegistry.sweepStale(missing);
    });
  });
}
