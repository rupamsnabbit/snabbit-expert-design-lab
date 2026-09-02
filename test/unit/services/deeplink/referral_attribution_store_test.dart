import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReferralAttribution.fromOneLinkParams', () {
    test('parses referrerId and campaignId from sub1/sub2', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '84649',
        'deep_link_sub2': '27',
      });

      expect(result, isNotNull);
      expect(result!.referrerId, '84649');
      expect(result.campaignId, '27');
    });

    test('trims surrounding whitespace on both values', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '  84649  ',
        'deep_link_sub2': '  27  ',
      });

      expect(result!.referrerId, '84649');
      expect(result.campaignId, '27');
    });

    test('campaignId is null when sub2 is absent', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '84649',
      });

      expect(result!.referrerId, '84649');
      expect(result.campaignId, isNull);
    });

    test('campaignId is null when sub2 is blank', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '84649',
        'deep_link_sub2': '   ',
      });

      expect(result!.campaignId, isNull);
    });

    test('campaignId is null when sub2 is not a String', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '84649',
        'deep_link_sub2': 42,
      });

      expect(result!.campaignId, isNull);
    });

    test('campaignId is null when sub2 is non-numeric', () {
      final result = ReferralAttribution.fromOneLinkParams({
        'deep_link_sub1': '84649',
        'deep_link_sub2': 'camp_diwali',
      });

      expect(result!.referrerId, '84649');
      expect(result.campaignId, isNull);
    });

    test('returns null when sub1 is absent', () {
      expect(
        ReferralAttribution.fromOneLinkParams(
            {'deep_link_value': 'referral-home'}),
        isNull,
      );
    });

    test('returns null when sub1 is blank', () {
      expect(
        ReferralAttribution.fromOneLinkParams({'deep_link_sub1': '   '}),
        isNull,
      );
    });

    test('returns null when sub1 is not a String', () {
      expect(
        ReferralAttribution.fromOneLinkParams({'deep_link_sub1': 99}),
        isNull,
      );
    });

    test('returns null when sub1 is non-numeric', () {
      expect(
        ReferralAttribution.fromOneLinkParams({'deep_link_sub1': 'runner_123'}),
        isNull,
      );
    });
  });

  group('ReferralAttributionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save then read round-trips referrerId and campaignId', () async {
      await ReferralAttributionStore.save(
        referrerId: '84649',
        campaignId: '27',
      );

      final result = await ReferralAttributionStore.read();

      expect(result!.referrerId, '84649');
      expect(result.campaignId, '27');
    });

    test('save with null campaignId reads back null campaignId', () async {
      await ReferralAttributionStore.save(referrerId: '84649');

      final result = await ReferralAttributionStore.read();

      expect(result!.referrerId, '84649');
      expect(result.campaignId, isNull);
    });

    test('save with null campaignId clears a previously stored campaignId',
        () async {
      await ReferralAttributionStore.save(
        referrerId: '84649',
        campaignId: '27',
      );
      await ReferralAttributionStore.save(referrerId: '84649');

      final result = await ReferralAttributionStore.read();

      expect(result!.campaignId, isNull);
    });

    test('read returns null when nothing is stored', () async {
      expect(await ReferralAttributionStore.read(), isNull);
    });

    test('clear removes the stored attribution', () async {
      await ReferralAttributionStore.save(
        referrerId: '84649',
        campaignId: '27',
      );

      await ReferralAttributionStore.clear();

      expect(await ReferralAttributionStore.read(), isNull);
    });

    test('read defaults attemptCount to 0', () async {
      await ReferralAttributionStore.save(referrerId: '84649');

      expect((await ReferralAttributionStore.read())!.attemptCount, 0);
    });

    test('incrementAttempt bumps the stored count', () async {
      await ReferralAttributionStore.save(referrerId: '84649');

      await ReferralAttributionStore.incrementAttempt();
      await ReferralAttributionStore.incrementAttempt();

      expect((await ReferralAttributionStore.read())!.attemptCount, 2);
    });

    test('save resets a previously accumulated attemptCount', () async {
      await ReferralAttributionStore.save(referrerId: '84649');
      await ReferralAttributionStore.incrementAttempt();

      await ReferralAttributionStore.save(referrerId: '84649');

      expect((await ReferralAttributionStore.read())!.attemptCount, 0);
    });
  });
}
