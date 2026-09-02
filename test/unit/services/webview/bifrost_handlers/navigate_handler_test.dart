import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/navigate_handler.dart';
import 'package:snabbit_runner/services/webview/route_registry.dart';

class _NavCall {
  _NavCall(this.route, this.args, this.replace);
  final String route;
  final Object? args;
  final bool replace;
}

class _FakeAppNavigator implements AppNavigator {
  final List<_NavCall> calls = [];
  bool throwOnPush = false;

  @override
  BuildContext? get currentContext => null;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {
    if (throwOnPush) throw StateError('navigator not mounted');
    calls.add(_NavCall(route, arguments, false));
  }

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {
    if (throwOnPush) throw StateError('navigator not mounted');
    calls.add(_NavCall(route, arguments, true));
  }
}

RouteRegistry _registry({ArgsValidator? validator}) {
  return RouteRegistry([
    RouteEntry.named(
      uri: 'snabbit://add-bank-upi',
      routeName: '/add_bank_or_upi_details',
      argsValidator: validator,
    ),
  ]);
}

NavigateHandler _handler({
  required RouteRegistry registry,
  required _FakeAppNavigator navigator,
  Duration debounce = const Duration(milliseconds: 300),
  DateTime Function()? now,
}) {
  return NavigateHandler(
    registry: registry,
    navigator: navigator,
    debounce: debounce,
    now: now ?? DateTime.now,
  );
}

void main() {
  group('NavigateHandler.pattern', () {
    test('is RPC', () {
      final h = _handler(
        registry: _registry(),
        navigator: _FakeAppNavigator(),
      );
      expect(h.pattern, BifrostPattern.rpc);
    });
  });

  group('NavigateHandler — happy path', () {
    test('pushes the mapped native route and returns empty success', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle({'uri': 'snabbit://add-bank-upi'});

      expect(nav.calls, hasLength(1));
      expect(nav.calls.single.route, '/add_bank_or_upi_details');
      expect(nav.calls.single.replace, isFalse);
      expect(result.error, isNull);
      expect(result.data, isNull);
    });

    test('passes data map through when no validator is registered', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      await h.handle({
        'uri': 'snabbit://add-bank-upi',
        'data': {'source': 'rate_card'},
      });

      expect(nav.calls.single.args, {'source': 'rate_card'});
    });

    test('closeBehavior="replace" uses pushReplacementNamed', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      await h.handle({
        'uri': 'snabbit://add-bank-upi',
        'closeBehavior': 'replace',
      });

      expect(nav.calls.single.replace, isTrue);
    });

    test('empty data map is coerced to null arguments', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      await h.handle({'uri': 'snabbit://add-bank-upi', 'data': {}});

      expect(nav.calls.single.args, isNull);
    });
  });

  group('NavigateHandler — typed args', () {
    test('validator producing args passes them as arguments', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(
        registry: _registry(
          validator: (m) => ArgsResult.ok(m['chatId']),
        ),
        navigator: nav,
      );

      await h.handle({
        'uri': 'snabbit://add-bank-upi',
        'data': {'chatId': '123'},
      });

      expect(nav.calls.single.args, '123');
    });

    test('validator rejection surfaces INVALID_ARGS and skips navigation',
        () async {
      final nav = _FakeAppNavigator();
      final h = _handler(
        registry: _registry(
          validator: (_) => ArgsResult.invalid('chatId is required'),
        ),
        navigator: nav,
      );

      final result = await h.handle({'uri': 'snabbit://add-bank-upi'});

      expect(nav.calls, isEmpty);
      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
      expect(result.error?.message, 'chatId is required');
    });
  });

  group('NavigateHandler — error cases', () {
    test('missing uri returns INVALID_ARGS', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle(const {});

      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
      expect(nav.calls, isEmpty);
    });

    test('non-string uri returns INVALID_ARGS', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle({'uri': 42});

      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
      expect(nav.calls, isEmpty);
    });

    test('unregistered uri returns UNKNOWN_ROUTE with details.uri', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle({'uri': 'snabbit://nope'});

      expect(result.error?.code, BifrostErrorCodes.unknownRoute);
      expect(result.error?.details?['uri'], 'snabbit://nope');
      expect(nav.calls, isEmpty);
    });
  });

  group('NavigateHandler — query params', () {
    test('strips the query string for lookup and resolves the base URI',
        () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle({
        'uri': 'snabbit://add-bank-upi?module_id=1&module_name=id-verification',
      });

      expect(result.error, isNull);
      expect(nav.calls.single.route, '/add_bank_or_upi_details');
    });

    test('folds query params into the validator input', () async {
      final nav = _FakeAppNavigator();
      Map<String, dynamic>? seen;
      final h = _handler(
        registry: _registry(validator: (m) {
          seen = m;
          return ArgsResult.ok(m['module_id']);
        }),
        navigator: nav,
      );

      await h.handle({
        'uri': 'snabbit://add-bank-upi?module_id=1&module_name=id-verification',
      });

      expect(seen, {'module_id': '1', 'module_name': 'id-verification'});
      expect(nav.calls.single.args, '1'); // query values are strings
    });

    test('passes query params through as args when no validator', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      await h.handle({'uri': 'snabbit://add-bank-upi?module_id=1&x=foo'});

      expect(nav.calls.single.args, {'module_id': '1', 'x': 'foo'});
    });

    test('explicit data map wins over query params on key conflict', () async {
      final nav = _FakeAppNavigator();
      Map<String, dynamic>? seen;
      final h = _handler(
        registry: _registry(validator: (m) {
          seen = m;
          return ArgsResult.ok(m);
        }),
        navigator: nav,
      );

      await h.handle({
        'uri': 'snabbit://add-bank-upi?module_id=1',
        'data': {'module_id': '2', 'extra': 'x'},
      });

      expect(seen, {'module_id': '2', 'extra': 'x'});
    });

    test('unknown base URI with a query string returns UNKNOWN_ROUTE', () async {
      final nav = _FakeAppNavigator();
      final h = _handler(registry: _registry(), navigator: nav);

      final result = await h.handle({'uri': 'snabbit://nope?x=1'});

      expect(result.error?.code, BifrostErrorCodes.unknownRoute);
      expect(result.error?.details?['uri'], 'snabbit://nope?x=1');
      expect(nav.calls, isEmpty);
    });
  });

  group('NavigateHandler — debounce', () {
    test('second call within the window returns DEBOUNCED and does not nav',
        () async {
      final nav = _FakeAppNavigator();
      var now = DateTime(2026, 4, 21, 12, 0, 0);
      final h = _handler(
        registry: _registry(),
        navigator: nav,
        debounce: const Duration(milliseconds: 300),
        now: () => now,
      );

      await h.handle({'uri': 'snabbit://add-bank-upi'});
      now = now.add(const Duration(milliseconds: 100));
      final second = await h.handle({'uri': 'snabbit://add-bank-upi'});

      expect(nav.calls, hasLength(1));
      expect(second.error?.code, BifrostErrorCodes.debounced);
    });

    test('call after the window navigates normally', () async {
      final nav = _FakeAppNavigator();
      var now = DateTime(2026, 4, 21, 12, 0, 0);
      final h = _handler(
        registry: _registry(),
        navigator: nav,
        debounce: const Duration(milliseconds: 300),
        now: () => now,
      );

      await h.handle({'uri': 'snabbit://add-bank-upi'});
      now = now.add(const Duration(milliseconds: 500));
      await h.handle({'uri': 'snabbit://add-bank-upi'});

      expect(nav.calls, hasLength(2));
    });

    test('UNKNOWN_ROUTE does not consume the debounce window', () async {
      final nav = _FakeAppNavigator();
      var now = DateTime(2026, 4, 21, 12, 0, 0);
      final h = _handler(
        registry: _registry(),
        navigator: nav,
        debounce: const Duration(milliseconds: 300),
        now: () => now,
      );

      await h.handle({'uri': 'snabbit://nope'}); // UNKNOWN_ROUTE
      now = now.add(const Duration(milliseconds: 50));
      await h.handle({'uri': 'snabbit://add-bank-upi'}); // should still navigate

      expect(nav.calls, hasLength(1));
    });
  });
}
