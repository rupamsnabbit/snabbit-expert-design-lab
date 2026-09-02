import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/language_home.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_result.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_store.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';

import '../webview/test_channel_mocks.dart';

/// Fake KMP nav bridge so the host-backed keep-host path is exercised
/// deterministically (the real bridge hits a platform channel).
class _FakeBridge implements KmpNavigationBridge {
  /// Simulates "a native root-shell host is in front": [openDeeplinkViaHost] returns this.
  bool hostAlive = false;

  /// Simulates the shell being the resumed foreground surface: [isRootShellForeground]
  /// returns this (drives the router's cohort-hold gate).
  bool rootShellForeground = false;

  /// Simulates a native destination owning the value: [handleResolvedDeeplink] returns this.
  bool nativeDeeplinkHandled = false;

  /// Simulates a registered native destination opening: [openNativeDestination] returns this
  /// (drives the language-home native path).
  bool nativeDestinationOpened = false;

  /// Simulates the running cohort shell taking the loan request: [showLoanInShell] returns this.
  bool loanInShell = false;

  final List<({String route, Map<String, String> args})> viaHostCalls = [];
  final List<({String key, Map<String, String> args})> nativeDestinationCalls =
      [];
  final List<String> resolvedDeeplinkCalls = [];
  int returnToNativeHostCalls = 0;
  int showLoanInShellCalls = 0;
  int exitNativeShellCalls = 0;

  @override
  void Function()? onDrainRequested;

  @override
  Future<bool> isRootShellForeground() async => rootShellForeground;

  @override
  Future<bool?> isRootShellForegroundOrNull() async => rootShellForeground;

  @override
  Future<bool> waitForRootShellForeground(Duration timeout) async =>
      rootShellForeground;

  @override
  Future<bool> openDeeplinkViaHost(
    String route, [
    Map<String, String> args = const {},
  ]) async {
    viaHostCalls.add((route: route, args: args));
    return hostAlive;
  }

  @override
  Future<bool> handleResolvedDeeplink(
    String value,
    Map<String, String> params,
  ) async {
    resolvedDeeplinkCalls.add(value);
    return nativeDeeplinkHandled;
  }

  @override
  Future<void> returnToNativeHost() async {
    returnToNativeHostCalls++;
  }

  @override
  Future<bool> showLoanInShell() async {
    showLoanInShellCalls++;
    return loanInShell;
  }

  @override
  Future<bool> openNativeDestination(
    String key, [
    Map<String, String> args = const {},
  ]) async {
    nativeDestinationCalls.add((key: key, args: args));
    return nativeDestinationOpened;
  }

  @override
  Future<Map<String, String>?> openNativeDestinationForResult(
    String key, [
    Map<String, String> args = const {},
  ]) async =>
      null;

  @override
  Future<void> back() async {}

  @override
  Future<void> exitNativeShell() async {
    exitNativeShellCalls++;
  }

  @override
  void start() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  final router = DeepLinkRouter.instance;

  UserProfile testUser({bool rateCardV2 = false, bool cohort = false}) =>
      UserProfile(
        id: 1,
        phoneNumber: '9999999999',
        countryCode: '+91',
        isRateCardV2Effective: rateCardV2,
        // Non-null mqtt_config ⇒ MQTT (native-shell) cohort.
        mqttConfig: cohort ? const {'enabled': true} : null,
      );

  /// Host app wired to the singleton navigatorKey + a UserProfileProvider.
  /// Stub routes stand in for the real (heavy) destination screens; the router
  /// pushes by route name, so the names are all that matter. No LoanProvider is
  /// provided — the loan handler's catch path is tested via that absence.
  Widget host({UserProfile? user}) {
    final userProvider = UserProfileProvider();
    if (user != null) userProvider.user = user;
    return ChangeNotifierProvider<UserProfileProvider>.value(
      value: userProvider,
      child: MaterialApp(
        navigatorKey: GlobalState().navigatorKey,
        routes: {
          '/': (_) => const Scaffold(body: Text('start')),
          PartnerHome.routeName: (_) => const Scaffold(body: Text('home')),
          EarlyPayoutsScreen.routeName: (_) =>
              const Scaffold(body: Text('early-payouts-screen')),
          PayoutHome.routeName: (_) =>
              const Scaffold(body: Text('payout-home')),
          AppWebViewPage.routeName: (_) =>
              const Scaffold(body: Text('webview')),
          LanguageHome.routeName: (_) =>
              const Scaffold(body: Text('language-home-screen')),
          ReferralsHome.routeName: (_) =>
              const Scaffold(body: Text('referral-home-screen')),
        },
      ),
    );
  }

  late _FakeBridge fakeBridge;

  setUp(() {
    router.debugEnabledOverride = null;
    GlobalState().pendingDeeplink = null;
    SharedPreferences.setMockInitialValues(
        {}); // for the persisted pending slot
    // Deterministic bridge for every test; host-backed tests flip `hostAlive`.
    fakeBridge = _FakeBridge();
    router.bridge = fakeBridge;
  });
  tearDown(() {
    router.debugEnabledOverride = null;
    GlobalState().pendingDeeplink = null;
    router.bridge = KmpNavigationBridge.instance;
  });

  group('mapOneLinkParams', () {
    test('maps deep_link_value to a path-only uri', () {
      final uri = router.mapOneLinkParams({'deep_link_value': 'early-payouts'});
      expect(uri.toString(), 'snabbitrunner:///early-payouts');
    });

    test('strips a leading slash on the value', () {
      final uri = router.mapOneLinkParams({'deep_link_value': '/seva'});
      expect(uri.toString(), 'snabbitrunner:///seva');
    });

    test('returns null when deep_link_value is missing', () {
      expect(router.mapOneLinkParams({}), isNull);
    });

    test('returns null when deep_link_value is blank', () {
      expect(router.mapOneLinkParams({'deep_link_value': '   '}), isNull);
    });

    test('returns null when deep_link_value is not a String', () {
      expect(router.mapOneLinkParams({'deep_link_value': 123}), isNull);
    });
  });

  test('DeeplinkSource.analyticsName', () {
    expect(DeeplinkSource.notification.analyticsName, 'notification');
    expect(DeeplinkSource.clevertap.analyticsName, 'clevertap');
    expect(DeeplinkSource.onelink.analyticsName, 'onelink');
  });

  group('dispatch — kill switch off', () {
    test('returns notHandled and does not queue', () async {
      router.debugEnabledOverride = false;
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      expect(result, DeepLinkResult.notHandled);
      expect(GlobalState().pendingDeeplink, isNull);
    });
  });

  group('dispatch — queueing', () {
    test('queues when no navigator context (cold start)', () async {
      router.debugEnabledOverride = true;
      // No app pumped → navigatorKey.currentContext is null.
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.onelink,
      );
      expect(result, DeepLinkResult.queued);
      expect(GlobalState().pendingDeeplink, isNotNull);
      expect(GlobalState().pendingDeeplink!.source, DeeplinkSource.onelink);
    });

    testWidgets('queues when logged out (user == null)', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host()); // provider present, user null
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      expect(result, DeepLinkResult.queued);
      expect(GlobalState().pendingDeeplink, isNotNull);
    });
  });

  group('dispatch — navigation (enabled, logged in)', () {
    testWidgets('known native path navigates to its route', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      expect(find.text('early-payouts-screen'), findsOneWidget);
    });

    testWidgets('unknown path falls back to Home', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///does-not-exist'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('monthly-earnings opens webview for a rate-card-v2 runner',
        (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser(rateCardV2: true)));
      await router.dispatch(
        Uri.parse('snabbitrunner:///monthly-earnings'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(find.text('webview'), findsOneWidget);
    });

    testWidgets('monthly-earnings opens native PayoutHome for a v1 runner',
        (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///monthly-earnings'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(find.text('payout-home'), findsOneWidget);
    });

    testWidgets('seva with empty profile URL falls back to Home',
        (tester) async {
      router.debugEnabledOverride = true;
      // testUser() has runnerAppConfig == null → sevaUrl == null.
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///seva'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets(
        'loan (non-cohort) with no LoanProvider falls back to Home (catch path)',
        (tester) async {
      router.debugEnabledOverride = true;
      // Non-cohort → showLoanInShell returns false → the Flutter loan sheet path runs.
      // host() provides UserProfileProvider but NOT LoanProvider, so Provider.of throws
      // and the catch falls back to Home.
      fakeBridge.loanInShell = false;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///loan'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(fakeBridge.showLoanInShellCalls, 1);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('dispatch — host-backed (native shell in front)', () {
    testWidgets('routes a screen deeplink via the host, no local push',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.hostAlive = true;
      await tester.pumpWidget(host(user: testUser()));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      // Handed to the native host; NOT pushed on the Flutter navigator.
      expect(
          fakeBridge.viaHostCalls.single.route, EarlyPayoutsScreen.routeName);
      expect(fakeBridge.viaHostCalls.single.args, isEmpty);
      expect(find.text('early-payouts-screen'), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets(
        'routes a webview deeplink via the host with url/title/fetchLocation',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.hostAlive = true;
      await tester.pumpWidget(host(user: testUser(rateCardV2: true)));
      await router.dispatch(
        Uri.parse('snabbitrunner:///monthly-earnings'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      final call = fakeBridge.viaHostCalls.single;
      expect(call.route, AppWebViewPage.routeName);
      expect(call.args['title'], 'Earnings');
      expect(call.args['fetchLocation'], 'false');
      expect(call.args['url'], contains('v1/payouts/monthly-summary'));
      expect(find.text('webview'), findsNothing);
    });

    testWidgets('loan (cohort, shell up) opens the native sheet via the shell',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = true; // cohort-hold gate open
      fakeBridge.loanInShell = true; // running shell takes the loan request
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///loan'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      expect(fakeBridge.showLoanInShellCalls, 1);
      // Native shell took it — no Flutter loan sheet, no Home fallback, no push.
      expect(find.text('home'), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });
  });

  group('dispatch — host not in front (parity with pre-fix behaviour)', () {
    testWidgets('consults the host, then pushes on Flutter', (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.hostAlive = false;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(
          fakeBridge.viaHostCalls.single.route, EarlyPayoutsScreen.routeName);
      expect(find.text('early-payouts-screen'), findsOneWidget);
    });
  });

  group('dispatch — cohort hold gate', () {
    testWidgets('cohort + shell NOT foreground → deeplink is held (queued)',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = false; // shell still launching
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.queued);
      expect(GlobalState().pendingDeeplink, isNotNull);
      // Held — not pushed behind the shell.
      expect(find.text('early-payouts-screen'), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets(
        'cohort + shell foreground → host-backed handoff (no local push)',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = true;
      fakeBridge.hostAlive = true;
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      final result = await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      expect(
          fakeBridge.viaHostCalls.single.route, EarlyPayoutsScreen.routeName);
      expect(find.text('early-payouts-screen'), findsNothing);
    });

    testWidgets(
        'cohort drain with allowRequeue re-queues while shell not foreground',
        (tester) async {
      // The shell-resume drain must NOT consume the link when the shell isn't
      // foreground yet — it re-queues so a later onResume retries (never pushed behind).
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = false;
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      GlobalState().pendingDeeplink = (
        uri: Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await router.drainPending(allowRequeue: true);
      await tester.pumpAndSettle();
      expect(GlobalState().pendingDeeplink, isNotNull); // re-queued, not lost
      expect(find.text('early-payouts-screen'), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets(
        'persisted pending survives an isolate wipe and drains from storage',
        (tester) async {
      // The OneLink tap spawns a fresh isolate, wiping the in-memory slot. The
      // persisted copy must let the re-launched shell's drain still find the link.
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = false; // queue (+ persist)
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      await router.dispatch(
        Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.onelink,
      );
      expect(GlobalState().pendingDeeplink, isNotNull);
      // Simulate the re-launch wiping in-memory state (persisted copy remains).
      GlobalState().pendingDeeplink = null;
      // Shell now foreground → drain reads the persisted link → host-backed handoff.
      fakeBridge.rootShellForeground = true;
      fakeBridge.hostAlive = true;
      await router.drainPending(allowRequeue: true);
      await tester.pumpAndSettle();
      expect(fakeBridge.viaHostCalls.map((c) => c.route),
          contains(EarlyPayoutsScreen.routeName));
      expect(GlobalState().pendingDeeplink, isNull);
    });

    testWidgets('cohort + shell never came up → drain falls open to Flutter',
        (tester) async {
      // Fail-open: the drain (allowQueue == false) with the shell still not foreground
      // must dispatch to Flutter, not re-queue/drop.
      router.debugEnabledOverride = true;
      fakeBridge.rootShellForeground = false;
      fakeBridge.hostAlive = false;
      await tester.pumpWidget(host(user: testUser(cohort: true)));
      GlobalState().pendingDeeplink = (
        uri: Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );
      await router.drainPending();
      await tester.pumpAndSettle();
      expect(GlobalState().pendingDeeplink, isNull);
      expect(find.text('early-payouts-screen'), findsOneWidget);
    });
  });

  group('dispatch — language-home', () {
    testWidgets('opens the migrated native Language destination',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.nativeDestinationOpened = true; // native Language screen opens
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///language-home'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      // Routed to the native Language screen (openNativeDestination('language')) —
      // no Flutter fallback push, no host-backed handoff.
      expect(fakeBridge.nativeDestinationCalls.single.key, 'language');
      expect(fakeBridge.viaHostCalls, isEmpty);
      expect(find.text('language-home-screen'), findsNothing);
    });

    testWidgets('falls back to Flutter LanguageHome when the native open fails',
        (tester) async {
      // e.g. KMP not ready / no host → openNativeDestination returns false.
      router.debugEnabledOverride = true;
      fakeBridge.nativeDestinationOpened = false;
      fakeBridge.hostAlive = false;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///language-home'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(fakeBridge.nativeDestinationCalls.single.key, 'language');
      expect(find.text('language-home-screen'), findsOneWidget);
    });
  });

  group('dispatch — referral-home', () {
    // The referrals-v2 RC flag (`expert_is_referrals_v2_enabled`) is unavailable in
    // tests (RemoteConfig uninitialised) → getBool returns its safe default (false),
    // so referral routes to the v1 native ReferralsHome (drawer/KMP parity). The v2
    // webview branch reuses the host-aware _openWebview path covered by the webview tests.
    testWidgets('v2 off (default) pushes the native ReferralsHome',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.hostAlive = false;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///referral-home'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(find.text('referral-home-screen'), findsOneWidget);
    });

    testWidgets('v2 off routes via the host when the shell is in front',
        (tester) async {
      router.debugEnabledOverride = true;
      fakeBridge.hostAlive = true;
      await tester.pumpWidget(host(user: testUser()));
      await router.dispatch(
        Uri.parse('snabbitrunner:///referral-home'),
        source: DeeplinkSource.notification,
      );
      await tester.pumpAndSettle();
      expect(fakeBridge.viaHostCalls.single.route, ReferralsHome.routeName);
      expect(find.text('referral-home-screen'), findsNothing);
    });
  });

  group('dispatch — OneLink URL resolution', () {
    testWidgets('resolves deep_link_value from a onelink.me URL',
        (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      final result = await router.dispatch(
        Uri.parse(
          'https://snabbitrunner.onelink.me/fdJ3?deep_link_value=early-payouts',
        ),
        source: DeeplinkSource.clevertap,
      );
      await tester.pumpAndSettle();
      expect(result, DeepLinkResult.handled);
      expect(find.text('early-payouts-screen'), findsOneWidget);
    });

    test('returns notHandled when deep_link_value is missing', () async {
      router.debugEnabledOverride = true;
      final result = await router.dispatch(
        Uri.parse('https://snabbitrunner.onelink.me/fdJ3'),
        source: DeeplinkSource.clevertap,
      );
      expect(result, DeepLinkResult.notHandled);
    });
  });

  group('drainPending', () {
    testWidgets('drains the slot once at Home and clears it', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      GlobalState().pendingDeeplink = (
        uri: Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );

      await router.drainPending();
      await tester.pumpAndSettle();

      expect(find.text('early-payouts-screen'), findsOneWidget);
      expect(GlobalState().pendingDeeplink, isNull);
    });

    testWidgets('no-op when slot is empty', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      await router.drainPending();
      await tester.pumpAndSettle();
      expect(GlobalState().pendingDeeplink, isNull);
      expect(find.text('start'), findsOneWidget);
    });
  });

  group('reportPendingDroppedByForceUpdate', () {
    testWidgets('consumes an in-memory-only pending link WITHOUT navigating',
        (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      // Regression (P-A): must read the in-memory slot like drainPending, not only
      // the persisted one — a link parked only in memory (persist failed, or the
      // persisted copy TTL-expired) would otherwise survive the force-update drop.
      GlobalState().pendingDeeplink = (
        uri: Uri.parse('snabbitrunner:///early-payouts'),
        source: DeeplinkSource.notification,
      );

      await router.reportPendingDroppedByForceUpdate();
      await tester.pumpAndSettle();

      expect(GlobalState().pendingDeeplink, isNull); // consumed once
      expect(find.text('start'), findsOneWidget); // dropped, NOT dispatched
      expect(find.text('early-payouts-screen'), findsNothing);
    });

    testWidgets('no-op when nothing is pending', (tester) async {
      router.debugEnabledOverride = true;
      await tester.pumpWidget(host(user: testUser()));
      await router.reportPendingDroppedByForceUpdate();
      await tester.pumpAndSettle();
      expect(GlobalState().pendingDeeplink, isNull);
      expect(find.text('start'), findsOneWidget);
    });
  });

  group('captureReferralAttribution', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('captures and persists the referrer from a OneLink', () async {
      router.captureReferralAttributionForTest({
        'deep_link_sub1': '84649',
        'deep_link_sub2': '27',
      });
      await pumpEventQueue();

      final stored = await ReferralAttributionStore.read();
      expect(stored?.referrerId, '84649');
      expect(stored?.campaignId, '27');
    });

    test('is a no-op for a non-referral OneLink', () async {
      router.captureReferralAttributionForTest({
        'deep_link_value': 'early-payouts',
      });
      await pumpEventQueue();

      expect(await ReferralAttributionStore.read(), isNull);
    });

    test('a second, different referrer overwrites (last-wins)', () async {
      router.captureReferralAttributionForTest({'deep_link_sub1': '111'});
      await pumpEventQueue();
      router.captureReferralAttributionForTest({'deep_link_sub1': '222'});
      await pumpEventQueue();

      expect((await ReferralAttributionStore.read())?.referrerId, '222');
    });
  });
}
