import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Debug-only HTTP inspector (Chucker Flutter) — the Flutter port of the
/// Chucker Android inspector.
///
/// Captures Dio traffic routed through [HttpService] and exposes an on-device
/// inspector UI, reachable via Chucker's in-app notification or the app-level
/// draggable floating button (see [wrap]).
///
/// SAFETY — must never run, persist data, or surface UI on a production device:
/// * Every entry point short-circuits when [kDebugMode] is `false`, so the AOT
///   tree-shaker drops this code (and the unreferenced Chucker symbols) from
///   profile/release builds.
/// * As a second layer, Chucker's own [ChuckerFlutter.showOnRelease] defaults
///   to `false`; its interceptor/notification no-op outside debug regardless.
///
/// Coverage note: only Dart-side Dio traffic is captured. KMP-native requests
/// (SnabbitHttpClient via NetworkChannel) are invisible to any Flutter
/// inspector and would need a native OkHttp/Ktor interceptor instead.
///
/// Navigator wiring: in debug, [GlobalState.navigatorKey] is set to
/// [ChuckerFlutter.navigatorKey] so Chucker can open its inspector against the
/// app's root navigator (see globals.dart).
class DebugNetworkInspector {
  DebugNetworkInspector._();

  static final DebugNetworkInspector instance = DebugNetworkInspector._();

  /// Attaches the Chucker interceptor to [dio]. No-op in profile/release
  /// builds, and idempotent if called more than once on the same client.
  void attach(Dio dio) {
    if (!kDebugMode) return;
    final alreadyAttached =
        dio.interceptors.any((i) => i is ChuckerDioInterceptor);
    if (alreadyAttached) return;
    dio.interceptors.add(ChuckerDioInterceptor());
  }

  /// Opens the inspector UI. No-op in profile/release builds.
  void showInspector() {
    if (!kDebugMode) return;
    ChuckerFlutter.showChuckerScreen();
  }

  /// Kept for the [MaterialApp.builder] call site, but now returns [child] unchanged: the draggable
  /// launcher moved to the single NATIVE button (visible over both Flutter and CMP screens).
  Widget wrap(Widget? child) => child ?? const SizedBox.shrink();

  static const MethodChannel _nativeBridge =
      MethodChannel('com.snabbit.runner/chucker_debug');

  /// Observes the chucker_flutter inspector route so native can hide/re-show the NET button around
  /// it. Register in [MaterialApp.navigatorObservers] (debug only).
  final _InspectorRouteObserver routeObserver = _InspectorRouteObserver();

  /// Binds the native → Dart bridge: the native inspector button's "Flutter" action opens
  /// chucker_flutter here (native hides the button; we tell it to re-show on close via the observer).
  /// No-op in profile/release.
  void bindNativeBridge() {
    if (!kDebugMode) return;
    _nativeBridge.setMethodCallHandler((call) async {
      if (call.method == 'showFlutterInspector') {
        routeObserver.armForNextPush();
        showInspector();
      }
      return null;
    });
  }
}

/// Tracks the chucker_flutter inspector route (armed right before it's pushed) and pings native when
/// it pops — so the native NET button, which floats over MainActivity and can't be caught by the
/// Activity-level `shouldSkip`, is hidden only while the inspector is on screen. Debug-only.
class _InspectorRouteObserver extends NavigatorObserver {
  bool _armed = false;
  Route<dynamic>? _inspectorRoute;

  void armForNextPush() => _armed = true;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_armed) {
      _armed = false;
      _inspectorRoute = route;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _inspectorRoute)) {
      _inspectorRoute = null;
      DebugNetworkInspector._nativeBridge.invokeMethod('flutterInspectorClosed');
    }
  }
}
