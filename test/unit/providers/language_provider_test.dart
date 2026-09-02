import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

Response _resp(int? statusCode, dynamic data) => Response(
      requestOptions: RequestOptions(path: '/i18n'),
      statusCode: statusCode,
      data: data,
    );

LanguageProvider _providerReturning(Response? response) =>
    LanguageProvider(fetcher: (_) async => response);

void main() {
  // fetchMessages now mirrors the i18n map to KMP via a MethodChannel
  // (LocalizationChannel.pushMessages). Stub it so the push succeeds silently —
  // otherwise its best-effort error path drags in GlobalState/AudioPlayer.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.snabbit.runner/localization'),
      (_) async => null,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.snabbit.runner/localization'),
      null,
    );
  });

  group('LanguageProvider.fetchMessages', () {
    test('on 200 stores messages and tracks the loaded language code',
        () async {
      final provider = _providerReturning(_resp(200, {'hello': 'Namaste'}));

      await provider.fetchMessages('HINDI');

      expect(provider.error, isNull);
      expect(provider.currentLanguageCode, 'HINDI');
      expect(provider.getMessage('hello', 'Hi'), 'Namaste');
    });

    test('on non-200 sets error and leaves the loaded code unchanged',
        () async {
      final provider = _providerReturning(_resp(500, null));

      await provider.fetchMessages('HINDI');

      expect(provider.error, contains('500'));
      expect(provider.currentLanguageCode, isNull);
    });

    test('on null response sets error and leaves the loaded code unchanged',
        () async {
      final provider = _providerReturning(null);

      await provider.fetchMessages('HINDI');

      expect(provider.error, contains('null'));
      expect(provider.currentLanguageCode, isNull);
    });

    test('only a successful fetch updates the loaded code', () async {
      Response? response = _resp(200, {'k': 'English'});
      final provider = LanguageProvider(fetcher: (_) async => response);

      await provider.fetchMessages('ENGLISH');
      expect(provider.currentLanguageCode, 'ENGLISH');

      // A failed fetch must NOT advance the loaded code.
      response = _resp(500, null);
      await provider.fetchMessages('HINDI');
      expect(provider.currentLanguageCode, 'ENGLISH');
      expect(provider.error, contains('500'));

      // A later success does advance it (and clears the error).
      response = _resp(200, {'k': 'Hindi'});
      await provider.fetchMessages('HINDI');
      expect(provider.currentLanguageCode, 'HINDI');
      expect(provider.error, isNull);
      expect(provider.getMessage('k', 'x'), 'Hindi');
    });

    test('notifies listeners on each fetch', () async {
      final provider = _providerReturning(_resp(200, {'a': 'b'}));
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.fetchMessages('ENGLISH');

      expect(notifications, 1);
    });
  });

  group('LanguageProvider message helpers', () {
    late LanguageProvider provider;

    setUp(() async {
      provider = LanguageProvider(
        fetcher: (_) async => _resp(200, {
          'greet': 'Hello {{name}}',
          'plain': 'Plain',
        }),
      );
      await provider.fetchMessages('ENGLISH');
    });

    test('getMessage returns the message or the default fallback', () {
      expect(provider.getMessage('plain', 'x'), 'Plain');
      expect(provider.getMessage('missing', 'fallback'), 'fallback');
    });

    test('getFormattedMessage substitutes placeholders (and no-ops on null)',
        () {
      expect(
        provider.getFormattedMessage('greet', 'Hi {{name}}', {'name': 'Ravi'}),
        'Hello Ravi',
      );
      expect(provider.getFormattedMessage('plain', 'x', null), 'Plain');
    });

    test('getFormattedMessage2 wraps values in braces (and no-ops on null)',
        () {
      expect(
        provider.getFormattedMessage2('greet', 'Hi {{name}}', {'name': 'Ravi'}),
        'Hello {{Ravi}}',
      );
      expect(provider.getFormattedMessage2('plain', 'x', null), 'Plain');
    });

    test('getMessages returns the full message map', () {
      expect(provider.getMessages()['plain'], 'Plain');
    });
  });
}
