import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';

void main() {
  group('parseRateCardVersion', () {
    test('returns v1 for "V1"', () {
      expect(parseRateCardVersion('V1'), RateCardVersion.v1);
    });

    test('returns v1 for "v1" (case-insensitive)', () {
      expect(parseRateCardVersion('v1'), RateCardVersion.v1);
    });

    test('returns v2 for "V2"', () {
      expect(parseRateCardVersion('V2'), RateCardVersion.v2);
    });

    test('returns v1 for null (missing / backend omitted field)', () {
      expect(parseRateCardVersion(null), RateCardVersion.v1);
    });

    test('returns v1 for empty or whitespace string', () {
      expect(parseRateCardVersion(''), RateCardVersion.v1);
      expect(parseRateCardVersion('  '), RateCardVersion.v1);
    });

    test('returns v1 for unexpected string (conservative default)', () {
      expect(parseRateCardVersion('V99'), RateCardVersion.v1);
    });

    test('returns v1 for non-string type (conservative default)', () {
      expect(parseRateCardVersion(42), RateCardVersion.v1);
    });
  });

  group('shouldShowVishwaasBanner', () {
    test('returns true for v1', () {
      expect(shouldShowVishwaasBanner(RateCardVersion.v1), isTrue);
    });

    test('returns false for v2', () {
      expect(shouldShowVishwaasBanner(RateCardVersion.v2), isFalse);
    });
  });

  group('isOptedForNewRateCard', () {
    test('returns false for v1', () {
      expect(isOptedForNewRateCard(RateCardVersion.v1), isFalse);
    });

    test('returns true for v2', () {
      expect(isOptedForNewRateCard(RateCardVersion.v2), isTrue);
    });
  });
}
