import 'package:flutter/widgets.dart';

/// Narrow seam around `GlobalKey<NavigatorState>` so bifrost handlers can push
/// routes without reaching into `GlobalState` directly.
///
/// The real implementation wraps `MaterialApp.navigatorKey`; tests can pass
/// a recording fake.
abstract class AppNavigator {
  /// Current BuildContext for route openers that need it — e.g. bottom
  /// sheets and dialogs. Null when the navigator isn't mounted.
  BuildContext? get currentContext;

  Future<void> pushNamed(String route, {Object? arguments});
  Future<void> pushReplacementNamed(String route, {Object? arguments});
}

class GlobalKeyAppNavigator implements AppNavigator {
  GlobalKeyAppNavigator(this._key);

  final GlobalKey<NavigatorState> _key;

  @override
  BuildContext? get currentContext => _key.currentContext;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {
    final state = _key.currentState;
    if (state == null) {
      throw StateError('AppNavigator: no live NavigatorState for pushNamed');
    }
    await state.pushNamed(route, arguments: arguments);
  }

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {
    final state = _key.currentState;
    if (state == null) {
      throw StateError(
        'AppNavigator: no live NavigatorState for pushReplacementNamed',
      );
    }
    await state.pushReplacementNamed(route, arguments: arguments);
  }
}
