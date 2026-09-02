import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/open_url_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';

const _logger = NullBifrostLogger();

void main() {
  group('OpenUrlHandler', () {
    test('launches allowed http URL and reports success via callback',
        () async {
      final callbacks = <(String, bool)>[];
      final launches = <Uri>[];
      final handler = OpenUrlHandler(logger: _logger,
        onExternalUrlOpened: (url, ok) => callbacks.add((url, ok)),
        launcher: (uri, {required mode}) async {
          launches.add(uri);
          return true;
        },
      );

      await handler.handle({'url': 'https://example.com/x'});

      expect(launches, hasLength(1));
      expect(launches.single.host, 'example.com');
      expect(callbacks.single, ('https://example.com/x', true));
    });

    test('launches https, geo, mailto — all allowed schemes', () async {
      final launched = <String>[];
      final handler = OpenUrlHandler(logger: _logger,launcher: (uri, {required mode}) async {
        launched.add(uri.scheme);
        return true;
      });

      for (final url in [
        'https://example.com',
        'http://example.com',
        'geo:12.97,77.59',
        'mailto:ops@snabbit.com',
      ]) {
        await handler.handle({'url': url});
      }

      expect(launched, ['https', 'http', 'geo', 'mailto']);
    });

    test('rejects javascript: scheme and reports failure', () async {
      final callbacks = <(String, bool)>[];
      var launched = false;
      final handler = OpenUrlHandler(logger: _logger,
        onExternalUrlOpened: (url, ok) => callbacks.add((url, ok)),
        launcher: (uri, {required mode}) async {
          launched = true;
          return true;
        },
      );

      await handler.handle({'url': 'javascript:alert(1)'});

      expect(launched, isFalse);
      expect(callbacks.single, ('javascript:alert(1)', false));
    });

    test('ignores missing url without invoking the callback', () async {
      final callbacks = <(String, bool)>[];
      final handler = OpenUrlHandler(logger: _logger,
        onExternalUrlOpened: (url, ok) => callbacks.add((url, ok)),
        launcher: (uri, {required mode}) async => true,
      );

      await handler.handle(const {});
      await handler.handle({'url': ''});
      await handler.handle({'url': 42});

      expect(callbacks, isEmpty);
    });

    test('surfaces launcher failure (returned false) via callback', () async {
      final callbacks = <(String, bool)>[];
      final handler = OpenUrlHandler(logger: _logger,
        onExternalUrlOpened: (url, ok) => callbacks.add((url, ok)),
        launcher: (uri, {required mode}) async => false,
      );

      await handler.handle({'url': 'https://example.com'});

      expect(callbacks.single, ('https://example.com', false));
    });

    test('catches launcher exceptions and reports failure', () async {
      final callbacks = <(String, bool)>[];
      final handler = OpenUrlHandler(logger: _logger,
        onExternalUrlOpened: (url, ok) => callbacks.add((url, ok)),
        launcher: (uri, {required mode}) async => throw StateError('platform died'),
      );

      await handler.handle({'url': 'https://example.com'});

      expect(callbacks.single, ('https://example.com', false));
    });
  });
}
