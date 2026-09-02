import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs no-op handlers for platform channels that are not available
/// in a pure-Dart test environment but get triggered by singletons like
/// [MonitoringServiceStore] / [GlobalState].
///
/// Call once in [main] or [setUpAll] **after**
/// `TestWidgetsFlutterBinding.ensureInitialized()`.
void installTestChannelMocks() {
  const MethodChannel('xyz.luan/audioplayers')
      .setMockMethodCallHandler((call) async {
    // AudioPlayer constructor calls 'create' — return a fake player id.
    if (call.method == 'create') return {'playerId': 'test_player'};
    return null;
  });
  const MethodChannel('xyz.luan/audioplayers.global')
      .setMockMethodCallHandler((call) async => null);
  const MethodChannel('cx_flutter_plugin')
      .setMockMethodCallHandler((call) async => null);
}
