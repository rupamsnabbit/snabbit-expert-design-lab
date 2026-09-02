import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/route_registry.dart';

class _NoopNavigator implements AppNavigator {
  @override
  BuildContext? get currentContext => null;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {}

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {}
}

RouteEntry _stubEntry(String uri) => RouteEntry(
      uri: uri,
      opener: (_, __, {required replace}) async {},
    );

void main() {
  group('RouteRegistry', () {
    test('find returns the matching entry', () {
      final registry = RouteRegistry([
        _stubEntry('snabbit://a'),
        _stubEntry('snabbit://b'),
      ]);

      expect(registry.find('snabbit://a')?.uri, 'snabbit://a');
      expect(registry.find('snabbit://b')?.uri, 'snabbit://b');
    });

    test('find returns null for unregistered URIs', () {
      final registry = RouteRegistry([_stubEntry('snabbit://a')]);
      expect(registry.find('snabbit://missing'), isNull);
    });

    test('lookup is case-sensitive', () {
      final registry = RouteRegistry([_stubEntry('snabbit://AddBank')]);

      expect(registry.find('snabbit://addbank'), isNull);
      expect(registry.find('snabbit://AddBank'), isNotNull);
    });

    test('registeredUris exposes the configured URI list', () {
      final registry = RouteRegistry([
        _stubEntry('snabbit://a'),
        _stubEntry('snabbit://b'),
      ]);

      expect(
        registry.registeredUris.toSet(),
        {'snabbit://a', 'snabbit://b'},
      );
    });
  });

  group('ArgsResult', () {
    test('ok with an arg', () {
      const r = ArgsResult.ok('x');
      expect(r.args, 'x');
      expect(r.error, isNull);
    });

    test('ok with no arg defaults to null', () {
      const r = ArgsResult.ok();
      expect(r.args, isNull);
      expect(r.error, isNull);
    });

    test('invalid produces an INVALID_ARGS BifrostError with the reason', () {
      final r = ArgsResult.invalid('chatId must be a string');
      expect(r.args, isNull);
      expect(r.error?.code, 'INVALID_ARGS');
      expect(r.error?.message, 'chatId must be a string');
    });
  });

  group('RouteEntry.named factory', () {
    test('pushes the routeName on the navigator without awaiting pop',
        () async {
      final nav = _RecordingNavigator();
      final entry = RouteEntry.named(
        uri: 'snabbit://x',
        routeName: '/real_route',
      );

      await entry.opener(nav, {'k': 'v'}, replace: false);

      expect(nav.pushCalls.single.route, '/real_route');
      expect(nav.pushCalls.single.arguments, {'k': 'v'});
      expect(nav.replaceCalls, isEmpty);
    });

    test('replace: true uses pushReplacementNamed', () async {
      final nav = _RecordingNavigator();
      final entry = RouteEntry.named(
        uri: 'snabbit://x',
        routeName: '/real_route',
      );

      await entry.opener(nav, null, replace: true);

      expect(nav.pushCalls, isEmpty);
      expect(nav.replaceCalls.single.route, '/real_route');
    });

    test('fire-and-forget: opener resolves before pushNamed completes',
        () async {
      final nav = _SlowNavigator();
      final entry = RouteEntry.named(
        uri: 'snabbit://x',
        routeName: '/slow',
      );

      final stopwatch = Stopwatch()..start();
      await entry.opener(nav, null, replace: false);
      stopwatch.stop();

      // Opener returns immediately even though _SlowNavigator blocks
      // pushNamed for 200ms.
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });

  group('RouteEntry.sheet factory', () {
    test('throws StateError when there is no live context', () async {
      final entry = RouteEntry.sheet(
        uri: 'snabbit://x',
        builder: (_) => const SizedBox.shrink(),
      );

      await expectLater(
        () => entry.opener(_NoopNavigator(), null, replace: false),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _PushCall {
  _PushCall(this.route, this.arguments);
  final String route;
  final Object? arguments;
}

class _RecordingNavigator implements AppNavigator {
  final List<_PushCall> pushCalls = [];
  final List<_PushCall> replaceCalls = [];

  @override
  BuildContext? get currentContext => null;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {
    pushCalls.add(_PushCall(route, arguments));
  }

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {
    replaceCalls.add(_PushCall(route, arguments));
  }
}

class _SlowNavigator implements AppNavigator {
  @override
  BuildContext? get currentContext => null;

  @override
  Future<void> pushNamed(String route, {Object? arguments}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> pushReplacementNamed(String route, {Object? arguments}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
