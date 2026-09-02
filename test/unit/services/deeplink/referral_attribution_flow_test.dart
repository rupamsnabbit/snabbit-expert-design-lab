import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_service.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_store.dart';
import 'package:snabbit_runner/services/globals.dart';

import '../webview/test_channel_mocks.dart';

class _RecordingSender {
  _RecordingSender([this.statusCode = 200]);

  final int? statusCode;
  bool called = false;
  String? seenReferrerId;

  ValidateLinkSender get fn =>
      ({required String referrerId, String? campaignId}) async {
        called = true;
        seenReferrerId = referrerId;
        return statusCode == null
            ? null
            : Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: statusCode,
              );
      };
}

Env _emptyPayoutsEnv() => Env(
      name: 'test-empty-payouts',
      remoteUrl: '',
      onboardingUrl: '',
      atlasUrl: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  final router = DeepLinkRouter.instance;

  // Simulates the AppsFlyer UDL capture path: router persists only.
  Future<void> capture(Map<String, dynamic> raw) async {
    router.captureReferralAttributionForTest(raw);
    await pumpEventQueue();
  }

  // Simulates the SelectLanguageV2.initState drain.
  Future<void> drain({ValidateLinkSender? sender}) =>
      ReferralAttributionService.validateCapturedLink(
        sender: sender ?? _RecordingSender().fn,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GlobalState().currentEnv = stagingEnv3;
  });

  test('capture persists (no send at capture time)', () async {
    final sender = _RecordingSender();
    await capture({'deep_link_sub1': '84649', 'deep_link_sub2': '27'});

    // Persisted, but nothing sent — router is persist-only now.
    final stored = await ReferralAttributionStore.read();
    expect(stored?.referrerId, '84649');
    expect(stored?.campaignId, '27');
    expect(sender.called, isFalse);
  });

  test('capture → drain succeeds → cleared', () async {
    await capture({'deep_link_sub1': '84649'});
    await drain(sender: _RecordingSender(200).fn);
    expect(await ReferralAttributionStore.read(), isNull);
  });

  test('capture → transient drain → retained with attempt 1', () async {
    await capture({'deep_link_sub1': '84649'});
    await drain(sender: _RecordingSender(500).fn);
    final stored = await ReferralAttributionStore.read();
    expect(stored, isNotNull);
    expect(stored?.attemptCount, 1);
  });

  test('capture → 5 transient drains → gives up and clears', () async {
    await capture({'deep_link_sub1': '84649'});
    for (var i = 0; i < 5; i++) {
      await drain(sender: _RecordingSender(500).fn);
    }
    expect(await ReferralAttributionStore.read(), isNull);
  });

  test('no capture → drain is a no-op (no send)', () async {
    final sender = _RecordingSender();
    await drain(sender: sender.fn);
    expect(sender.called, isFalse);
  });

  test('non-numeric referrer is never persisted → drain no-op', () async {
    final sender = _RecordingSender();
    await capture({'deep_link_sub1': 'runner_abc'});
    expect(await ReferralAttributionStore.read(), isNull);

    await drain(sender: sender.fn);
    expect(sender.called, isFalse);
  });

  test('two captures before drain → latest wins on the wire', () async {
    final sender = _RecordingSender(200);
    await capture({'deep_link_sub1': '111'});
    await capture({'deep_link_sub1': '222'});

    await drain(sender: sender.fn);
    expect(sender.seenReferrerId, '222');
    expect(await ReferralAttributionStore.read(), isNull);
  });

  test('empty payoutsUrl → drain skips send, retains for later', () async {
    final sender = _RecordingSender();
    await capture({'deep_link_sub1': '84649'});
    GlobalState().currentEnv = _emptyPayoutsEnv();

    await drain(sender: sender.fn);
    expect(sender.called, isFalse);
    expect(await ReferralAttributionStore.read(), isNotNull);
  });
}
