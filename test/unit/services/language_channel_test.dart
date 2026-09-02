import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/language_channel.dart';

// Dart reads the flag without the `flutter.` prefix; the plugin stores it with
// the prefix (mirrors LanguagePlugin.writePendingLanguage on the native side).
const _pendingKey = 'pending_language_preference';
const _pendingStoreKey = 'flutter.pending_language_preference';

Response _ok(dynamic data) => Response(
      requestOptions: RequestOptions(path: '/i18n'),
      statusCode: 200,
      data: data,
    );

Response _fail() => Response(
      requestOptions: RequestOptions(path: '/i18n'),
      statusCode: 500,
      data: null,
    );

Future<void> _pumpHarness(
  WidgetTester tester, {
  required LanguageProvider languageProvider,
}) async {
  // Providers sit ABOVE MaterialApp so Provider.of(navigatorContext) finds them.
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<UserProfileProvider>.value(
          value: UserProfileProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: GlobalState().navigatorKey,
        home: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reconcilePendingLanguage', () {
    testWidgets('applies a differing pending language and clears the flag',
        (tester) async {
      SharedPreferences.setMockInitialValues({_pendingStoreKey: 'HINDI'});
      final lang = LanguageProvider(fetcher: (_) async => _ok({'k': 'Hindi'}));
      await _pumpHarness(tester, languageProvider: lang);

      await LanguageChannel.reconcilePendingLanguage();

      expect(lang.currentLanguageCode, 'HINDI');
      expect(lang.getMessage('k', 'x'), 'Hindi');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
    });

    testWidgets('clears the flag without refetching when already loaded',
        (tester) async {
      SharedPreferences.setMockInitialValues({_pendingStoreKey: 'HINDI'});
      var fetchCount = 0;
      final lang = LanguageProvider(fetcher: (_) async {
        fetchCount++;
        return _ok({'k': 'Hindi'});
      });
      // Pre-load HINDI so the pending code already matches.
      await lang.fetchMessages('HINDI');
      await _pumpHarness(tester, languageProvider: lang);

      await LanguageChannel.reconcilePendingLanguage();

      expect(fetchCount, 1); // no extra fetch beyond the pre-load
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
    });

    testWidgets('keeps the flag when the i18n reload fails', (tester) async {
      SharedPreferences.setMockInitialValues({_pendingStoreKey: 'HINDI'});
      final lang = LanguageProvider(fetcher: (_) async => _fail());
      await _pumpHarness(tester, languageProvider: lang);

      await LanguageChannel.reconcilePendingLanguage();

      expect(lang.currentLanguageCode, isNull); // not applied
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), 'HINDI'); // retained for retry
    });

    testWidgets('keeps the flag when there is no navigator context',
        (tester) async {
      SharedPreferences.setMockInitialValues({_pendingStoreKey: 'HINDI'});
      // No pumpWidget → GlobalState().navigatorKey.currentContext is null.

      await LanguageChannel.reconcilePendingLanguage();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), 'HINDI');
    });

    test('is a no-op when no language is pending', () async {
      SharedPreferences.setMockInitialValues({});

      await LanguageChannel.reconcilePendingLanguage();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_pendingKey), isNull);
    });
  });
}
