import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/services/notification_service.dart';

import 'webview/test_channel_mocks.dart';

/// No-op bridge so the router never hits the real KMP Pigeon channels (which do
/// not resolve in a pure-Dart test binding). Mirrors deeplink_router_test — the
/// deeplink dispatch path awaits the bridge, so it must be deterministic here.
class _NoopBridge implements KmpNavigationBridge {
  @override
  void Function()? onDrainRequested;

  @override
  Future<bool> handleResolvedDeeplink(
          String value, Map<String, String> params) async =>
      false;

  @override
  Future<bool> isRootShellForeground() async => false;

  @override
  Future<bool?> isRootShellForegroundOrNull() async => false;

  @override
  Future<bool> waitForRootShellForeground(Duration timeout) async => false;

  @override
  Future<bool> openDeeplinkViaHost(String route,
          [Map<String, String> args = const {}]) async =>
      false;

  @override
  Future<bool> showLoanInShell() async => false;

  @override
  Future<bool> openNativeDestination(String key,
          [Map<String, String> args = const {}]) async =>
      false;

  @override
  Future<Map<String, String>?> openNativeDestinationForResult(String key,
          [Map<String, String> args = const {}]) async =>
      null;

  @override
  Future<void> back() async {}

  @override
  Future<void> returnToNativeHost() async {}

  @override
  Future<void> exitNativeShell() async {}

  @override
  void start() {}
}

/// Focuses on the deeplink-first wiring added to [NotificationService.
/// handleNotificationTap]: a `deeplink` (FCM) or `wzrk_dl` (CleverTap) value is
/// routed through [DeepLinkRouter]; everything else falls through to the legacy
/// `type` switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  final router = DeepLinkRouter.instance;
  final notifications = NotificationService.instance;

  UserProfile testUser() =>
      UserProfile(id: 1, phoneNumber: '9999999999', countryCode: '+91');

  Widget host() {
    final userProvider = UserProfileProvider()..user = testUser();
    return ChangeNotifierProvider<UserProfileProvider>.value(
      value: userProvider,
      child: MaterialApp(
        navigatorKey: GlobalState().navigatorKey,
        routes: {
          '/': (_) => const Scaffold(body: Text('start')),
          PartnerHome.routeName: (_) => const Scaffold(body: Text('home')),
          EarlyPayoutsScreen.routeName: (_) =>
              const Scaffold(body: Text('early-payouts-screen')),
          AppWebViewPage.routeName: (_) =>
              const Scaffold(body: Text('webview')),
        },
      ),
    );
  }

  setUp(() {
    router.debugEnabledOverride = null;
    GlobalState().pendingDeeplink = null;
    router.bridge = _NoopBridge();
  });
  tearDown(() {
    router.debugEnabledOverride = null;
    GlobalState().pendingDeeplink = null;
    router.bridge = KmpNavigationBridge.instance;
  });

  testWidgets('routes the FCM `deeplink` key through the router',
      (tester) async {
    router.debugEnabledOverride = true;
    await tester.pumpWidget(host());

    await notifications.handleNotificationTap(
      {'deeplink': 'snabbitrunner:///early-payouts'},
    );
    await tester.pumpAndSettle();

    expect(find.text('early-payouts-screen'), findsOneWidget);
  });

  testWidgets('routes the CleverTap `wzrk_dl` key through the router',
      (tester) async {
    router.debugEnabledOverride = true;
    await tester.pumpWidget(host());

    await notifications.handleNotificationTap(
      {'wzrk_pn': '1', 'wzrk_dl': 'snabbitrunner:///early-payouts'},
    );
    await tester.pumpAndSettle();

    expect(find.text('early-payouts-screen'), findsOneWidget);
  });

  testWidgets('kill switch off → deeplink ignored, falls through to legacy',
      (tester) async {
    router.debugEnabledOverride = false;
    await tester.pumpWidget(host());

    // Deeplink-only payload, no legacy `type` → legacy switch is a no-op.
    await notifications.handleNotificationTap(
      {'deeplink': 'snabbitrunner:///early-payouts'},
    );
    await tester.pumpAndSettle();

    // No navigation happened; still on the start route.
    expect(find.text('start'), findsOneWidget);
    expect(find.text('early-payouts-screen'), findsNothing);
  });
}
