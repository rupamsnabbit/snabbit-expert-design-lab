import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analyticsChannel = MethodChannel('com.snabbit.runner/analytics');
  final channelMethods = <String>[];

  setUp(() {
    OnboardingAnalytics.resetForTest();
    MixpanelSetup.resetForTest();
    channelMethods.clear();
    // Mock the KMP analytics channel so identifyOnLogin's MethodChannel
    // calls resolve cleanly instead of throwing MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async {
      channelMethods.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
  });

  group('OnboardingAnalytics super properties', () {
    test('registerSuperProperties stores values', () {
      OnboardingAnalytics.registerSuperProperties({
        'app_version': '1.2.3',
        'os_version': 'Android 14',
      });

      final props = OnboardingAnalytics.superPropsForTest;
      expect(props['app_version'], '1.2.3');
      expect(props['os_version'], 'Android 14');
    });

    test('registerSuperProperties merges; later wins on conflict', () {
      OnboardingAnalytics.registerSuperProperties({'k': 'first'});
      OnboardingAnalytics.registerSuperProperties({'k': 'second', 'b': 1});

      final props = OnboardingAnalytics.superPropsForTest;
      expect(props['k'], 'second');
      expect(props['b'], 1);
    });
  });

  group('OnboardingAnalytics.maskPhone', () {
    test('masks a 10-digit phone to first-5 + 5*X', () {
      expect(OnboardingAnalytics.maskPhone('8606612345'), '86066XXXXX');
    });

    test('short phone (<5 chars) returned as-is', () {
      expect(OnboardingAnalytics.maskPhone('123'), '123');
    });

    test('exactly 5 chars: no Xs appended', () {
      expect(OnboardingAnalytics.maskPhone('12345'), '12345');
    });

    test('maskPhone is pure — does not touch super props', () {
      OnboardingAnalytics.maskPhone('8606612345');
      expect(OnboardingAnalytics.superPropsForTest.containsKey('phone_masked'),
          false);
    });
  });

  group('OnboardingAnalytics resend counter', () {
    test('incrementResendCount bumps counter only (not super)', () {
      expect(OnboardingAnalytics.resendCount, 0);

      OnboardingAnalytics.incrementResendCount();
      expect(OnboardingAnalytics.resendCount, 1);

      OnboardingAnalytics.incrementResendCount();
      expect(OnboardingAnalytics.resendCount, 2);

      expect(OnboardingAnalytics.superPropsForTest.containsKey('resend_count'),
          false);
    });

    test('resetResendCount zeroes counter', () {
      OnboardingAnalytics.incrementResendCount();
      OnboardingAnalytics.incrementResendCount();

      OnboardingAnalytics.resetResendCount();

      expect(OnboardingAnalytics.resendCount, 0);
    });
  });

  group('OnboardingAnalytics.identifyOnLogin', () {
    test(
        'registers cluster/region/runner ids as super props so they '
        'fan out to CleverTap via logEvent', () async {
      await OnboardingAnalytics.identifyOnLogin(UserProfile(
        id: 7,
        phoneNumber: '8606612345',
        countryCode: '+91',
        clusterId: 11,
        regionId: 22,
      ));

      final props = OnboardingAnalytics.superPropsForTest;
      expect(props['runner_id'], 7);
      expect(props['cluster_id'], 11);
      expect(props['region_id'], 22);
    });

    test('identify reaches the channel before any setUserProperty (§5.8)',
        () async {
      await OnboardingAnalytics.identifyOnLogin(UserProfile(
        id: 7,
        phoneNumber: '8606612345',
        countryCode: '+91',
        clusterId: 11,
        regionId: 22,
      ));

      // people.set() must target the runner distinct_id, so identify must
      // cross before the profile write (batch setUserProperties).
      expect(channelMethods.contains('identify'), isTrue);
      expect(channelMethods.contains('setUserProperties'), isTrue);
      expect(
        channelMethods.indexOf('identify'),
        lessThan(channelMethods.indexOf('setUserProperties')),
      );
    });
  });
}
