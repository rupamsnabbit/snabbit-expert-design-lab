import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/select_language_init_provider.dart';

void main() {
  group('SelectLanguageInitProvider.fcmSignature', () {
    test('joins version code and token', () {
      expect(
        SelectLanguageInitProvider.fcmSignature(
          versionCode: '163',
          token: 'tok-abc',
        ),
        '163|tok-abc',
      );
    });

    test('is stable for identical inputs', () {
      final a = SelectLanguageInitProvider.fcmSignature(
        versionCode: '163',
        token: 'tok-abc',
      );
      final b = SelectLanguageInitProvider.fcmSignature(
        versionCode: '163',
        token: 'tok-abc',
      );
      expect(a, b);
    });
  });

  group('SelectLanguageInitProvider.needsReport', () {
    test('reports when nothing was ever persisted', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: null,
          currentVersionCode: '163',
        ),
        isTrue,
      );
    });

    test('skips when the persisted report covers this build', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '163|tok-abc',
          currentVersionCode: '163',
        ),
        isFalse,
      );
    });

    test('reports after an upgrade — the case this exists for', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '163|tok-abc',
          currentVersionCode: '164',
        ),
        isTrue,
      );
    });

    test('reports after a downgrade too', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '164|tok-abc',
          currentVersionCode: '163',
        ),
        isTrue,
      );
    });

    test('a cleared signature (token rotation) reports again', () {
      // onTokenRefresh removes the key, which surfaces here as null.
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: null,
          currentVersionCode: '163',
        ),
        isTrue,
      );
    });

    test('a version that is a prefix of the persisted one still reports', () {
      // Guards the startsWith check: '16' must not match '163|...'.
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '163|tok-abc',
          currentVersionCode: '16',
        ),
        isTrue,
      );
    });

    test('a longer current version does not match a shorter persisted one', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '16|tok-abc',
          currentVersionCode: '163',
        ),
        isTrue,
      );
    });

    test('an empty persisted value reports', () {
      expect(
        SelectLanguageInitProvider.needsReport(
          persisted: '',
          currentVersionCode: '163',
        ),
        isTrue,
      );
    });
  });
}
