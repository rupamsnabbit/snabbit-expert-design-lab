import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Bidirectional bridge for the runner `current_state` envelope. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/RunnerStatePlugin.kt`
/// and lands in the KMP `RunnerStateStore` (a `MutableStateFlow`) that the
/// Expert App 2.0 Compose Multiplatform surfaces observe.
///
///  - Dart → KMP: [pushState] mirrors every state settle.
///  - KMP → Dart: [bindRefreshHandler] installs a handler that Compose VMs
///    can fire via `RunnerStateStore.requestRefresh()` to ask Dart to re-fetch
///    `current_state` now (e.g. pull-to-refresh, mount mid-shift). The result
///    flows back through [pushState], so KMP doesn't await a reply.
///
/// Modelled on `NetworkConfigChannel`: a thin static writer.
/// `RunnerRtDataProvider` is the single source of truth and pushes on every
/// state settle; this class only carries the bytes across.
///
/// [pushState] is best-effort — any channel failure is swallowed and logged
/// (sanitized) so a bridge hiccup can never disturb Dart-side polling, mirroring
/// the failure-isolation rule used by `KmpAnalyticsChannel`.
class RunnerStateChannel {
  RunnerStateChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/runner_state');

  /// Pushes the full `current_state` envelope (already JSON-encoded) to KMP —
  /// `widget_name` / `widget_data` plus top-level siblings (`sheet_warnings`,
  /// `gold_coins_total`, `red_cards_total`) that KMP read models fold in.
  /// Never throws — failures are logged and absorbed.
  static Future<void> pushState(String json) {
    return _channel.invokeMethod<void>('pushState', <String, Object?>{
      'json': json,
    }).catchError((e) => _logFailure('pushState', e));
  }

  /// Tells KMP the server cancelled the active OT offer (`AUTO_OT_CANCELLED` push) so the Compose
  /// Auto-OT sheet flips to "expired" — mirrors the Flutter provider's `handleAutoOtCancellation`.
  /// Best-effort: the KMP coordinator applies its own active-offer guard, and any channel failure
  /// is swallowed + logged so it never disturbs Dart-side handling.
  static Future<void> autoOtCancelled() {
    return _channel
        .invokeMethod<void>('autoOtCancelled')
        .catchError((e) => _logFailure('autoOtCancelled', e));
  }

  /// Wire the `requestRefresh` handler that KMP fires when a Compose surface
  /// wants fresh data. Call once from [RunnerRtDataProvider]'s constructor.
  /// A second call replaces the previous handler (latest wins).
  ///
  /// A handler throw is swallowed + logged so a Dart-side bug never blows up
  /// the platform channel and breaks subsequent `pushState` calls.
  static void bindRefreshHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestRefresh') {
        try {
          await handler();
        } catch (e) {
          _logFailure('requestRefresh', e);
        }
        return null;
      }
      throw MissingPluginException('No handler for ${call.method}');
    });
  }

  /// Records the *kind* of failure (PlatformException code or runtime type)
  /// but never the exception message — a `current_state` envelope carries PII
  /// (customer name, phone) and a future plugin change could echo args into
  /// `PlatformException.details`. Defense-in-depth: don't emit them anywhere.
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('runner_state_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
