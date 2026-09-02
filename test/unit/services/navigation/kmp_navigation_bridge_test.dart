import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';

/// Covers [KmpNavigationBridge.exitNativeShell] — the forced-logout teardown call
/// that finishes the native (MQTT-cohort) shell so the Flutter login screen
/// `handle403()` already pushed becomes the foreground surface.
///
/// Two guarantees matter: (1) it crosses the Pigeon channel to the native host,
/// and (2) it is best-effort — a bridge failure is swallowed (logged), never
/// thrown, so it can't block the already-completed logout in `handle403`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Pigeon `NavigationHostApi()` (no suffix) → this BasicMessageChannel name.
  const channelName =
      'dev.flutter.pigeon.snabbit_runner.NavigationHostApi.exitNativeShell';
  // exitNativeShell carries no custom Pigeon types (void, null arg/reply), so the
  // standard codec reproduces the reply envelope the generated client expects.
  const codec = StandardMessageCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMessageHandler(channelName, null);
  });

  test('exitNativeShell crosses the Pigeon channel to the native host',
      () async {
    var invoked = false;
    messenger.setMockMessageHandler(channelName, (message) async {
      invoked = true;
      return codec.encodeMessage(<Object?>[null]); // Pigeon success reply
    });

    await KmpNavigationBridge.instance.exitNativeShell();

    expect(invoked, isTrue);
  });

  test('exitNativeShell swallows a bridge failure and never throws', () async {
    messenger.setMockMessageHandler(channelName, (message) async {
      // Pigeon error envelope (code, message, details) → the generated client
      // throws a PlatformException, which the wrapper must catch and log.
      return codec.encodeMessage(<Object?>['ERR', 'boom', null]);
    });

    // Completing normally is the contract: a throw here would break the logout.
    await expectLater(
        KmpNavigationBridge.instance.exitNativeShell(), completes);
  });
}
