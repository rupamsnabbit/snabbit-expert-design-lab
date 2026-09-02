import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/pages/language_home.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/navigate_handler.dart';
import 'package:snabbit_runner/services/webview/webview_routes.dart';

class _BlockingNavigator implements AppNavigator {
  Completer<void>? pushCompleter;

  @override
  BuildContext? get currentContext => null;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {
    expect(route, LanguageHome.routeName);
    pushCompleter = Completer<void>();
    await pushCompleter!.future;
  }

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {
    fail('change-language should not use replace in normal web flow');
  }
}

void main() {
  group('defaultWebViewRouteRegistry change-language', () {
    test('is registered and maps to LanguageHome', () {
      final entry = defaultWebViewRouteRegistry().find('snabbit://change-language');
      expect(entry, isNotNull);
    });

    test('opener awaits pushNamed so navigate RPC blocks until pop', () async {
      final nav = _BlockingNavigator();
      final entry = defaultWebViewRouteRegistry().find('snabbit://change-language')!;
      final handler = NavigateHandler(
        registry: defaultWebViewRouteRegistry(),
        navigator: nav,
        debounce: Duration.zero,
      );

      final handleFuture = handler.handle({'uri': 'snabbit://change-language'});
      await Future<void>.delayed(Duration.zero);
      expect(nav.pushCompleter, isNotNull);

      var rpcCompleted = false;
      unawaited(handleFuture.then((_) => rpcCompleted = true));
      await Future<void>.delayed(Duration.zero);
      expect(rpcCompleted, isFalse);

      nav.pushCompleter!.complete();
      await handleFuture;
      expect(rpcCompleted, isTrue);
    });
  });
}
