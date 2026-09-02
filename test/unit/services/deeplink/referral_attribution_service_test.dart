import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_service.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_store.dart';
import 'package:snabbit_runner/services/globals.dart';

import '../webview/test_channel_mocks.dart';

class _RecordingSender {
  _RecordingSender([this.statusCode = 200]);

  final int? statusCode;
  bool called = false;
  String? seenReferrerId;
  String? seenCampaignId;

  ValidateLinkSender get fn =>
      ({required String referrerId, String? campaignId}) async {
        called = true;
        seenReferrerId = referrerId;
        seenCampaignId = campaignId;
        return statusCode == null
            ? null
            : Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: statusCode,
              );
      };
}

ValidateLinkSender _sender(int? statusCode) => _RecordingSender(statusCode).fn;

Env _emptyPayoutsEnv() => Env(
      name: 'test-empty-payouts',
      remoteUrl: '',
      onboardingUrl: '',
      atlasUrl: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GlobalState().currentEnv = stagingEnv3;
    await ReferralAttributionStore.save(referrerId: '84649', campaignId: '27');
  });

  group('validateCapturedLink — short-circuits', () {
    test('null attribution short-circuits before sending', () async {
      await ReferralAttributionStore.clear();
      final sender = _RecordingSender();

      await ReferralAttributionService.validateCapturedLink(sender: sender.fn);

      expect(sender.called, isFalse);
    });

    test('empty payoutsUrl skips the send and retains the store', () async {
      GlobalState().currentEnv = _emptyPayoutsEnv();
      final sender = _RecordingSender();

      await ReferralAttributionService.validateCapturedLink(sender: sender.fn);

      expect(sender.called, isFalse);
      expect(await ReferralAttributionStore.read(), isNotNull);
    });
  });

  group('validateCapturedLink — clears (definitive)', () {
    for (final code in [200, 400, 404, 401]) {
      test('$code clears the store', () async {
        await ReferralAttributionService.validateCapturedLink(
          sender: _sender(code),
        );
        expect(await ReferralAttributionStore.read(), isNull);
      });
    }
  });

  group('validateCapturedLink — retains (transient)', () {
    for (final code in [408, 429, 500, 503]) {
      test('$code retains the store', () async {
        await ReferralAttributionService.validateCapturedLink(
          sender: _sender(code),
        );
        expect(await ReferralAttributionStore.read(), isNotNull);
      });
    }

    test('network failure (null response) retains the store', () async {
      await ReferralAttributionService.validateCapturedLink(
        sender: _sender(null),
      );
      expect(await ReferralAttributionStore.read(), isNotNull);
    });

    test('a throwing sender is isolated and retains the store', () async {
      await ReferralAttributionService.validateCapturedLink(
        sender: ({required String referrerId, String? campaignId}) async =>
            throw Exception('boom'),
      );
      expect(await ReferralAttributionStore.read(), isNotNull);
    });
  });

  group('validateCapturedLink — attempt ceiling', () {
    test('increments the attempt count on a transient failure', () async {
      await ReferralAttributionService.validateCapturedLink(
        sender: _sender(500),
      );
      expect((await ReferralAttributionStore.read())?.attemptCount, 1);
    });

    test('retains up to the ceiling', () async {
      for (var i = 0; i < 4; i++) {
        await ReferralAttributionService.validateCapturedLink(
          sender: _sender(500),
        );
      }
      final stored = await ReferralAttributionStore.read();
      expect(stored, isNotNull);
      expect(stored?.attemptCount, 4);
    });

    test('gives up and clears once the ceiling is reached', () async {
      for (var i = 0; i < 5; i++) {
        await ReferralAttributionService.validateCapturedLink(
          sender: _sender(500),
        );
      }
      expect(await ReferralAttributionStore.read(), isNull);
    });
  });
}
