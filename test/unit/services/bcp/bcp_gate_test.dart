import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/bcp/bcp_config.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/bcp/bcp_store.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  final List<int> statusScript;
  int _i = 0;
  int callCount = 0;

  _ScriptedAdapter(this.statusScript);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    callCount++;
    final status = _i < statusScript.length
        ? statusScript[_i++]
        : statusScript.last;
    final body = utf8.encode(jsonEncode({'mock': true}));
    return ResponseBody.fromBytes(
      body,
      status,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }
}

class _NavSpy {
  final List<bool> calls = [];
  void onNavigate(bool backDisabled) => calls.add(backDisabled);
}

BcpConfig _cfg({
  bool enabled = true,
  bool persistAcrossSessions = false,
  int triggerStatus = 435,
  int defaultWindowSec = 30,
  String endpointsJson =
      '[{"path":"api/v1/runners/me/app/current_state","back_disabled":true},'
      '{"path":"api/v1/runners/me/sos/active","back_disabled":false}]',
}) {
  return BcpConfig.parse(
    enabled: enabled,
    persistAcrossSessions: persistAcrossSessions,
    triggerStatus: triggerStatus,
    defaultWindowSec: defaultWindowSec,
    endpointsJson: endpointsJson,
  );
}

Dio _dioWith(BcpGate gate, _ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.snabbit.com/',
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(gate.interceptor);
  return dio;
}

Future<int?> _status(Dio dio, String path) async {
  try {
    final r = await dio.get(path);
    return r.statusCode;
  } on DioException catch (e) {
    return e.response?.statusCode;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BcpGate.resetForTest();
  });

  tearDown(() {
    BcpGate.resetForTest();
  });

  group('Passthrough', () {
    test('passes through when config.enabled is false', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(enabled: false),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      final adapter = _ScriptedAdapter([435]);
      final dio = _dioWith(gate, adapter);

      final res = await dio.get('api/v1/runners/me/app/current_state');
      expect(res.statusCode, 435);
      expect(adapter.callCount, 1);
      expect(gate.blockUntilSnapshot, isEmpty);
    });

    test('passes through non-allowlisted path even on 435', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      final adapter = _ScriptedAdapter([435]);
      final dio = _dioWith(gate, adapter);

      final res = await dio.get('api/v1/runners/me/profile');
      expect(res.statusCode, 435);
      expect(gate.blockUntilSnapshot, isEmpty);
    });
  });

  group('Block recording', () {
    test('records block on real 435 and persists nothing when persist disabled',
        () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final adapter = _ScriptedAdapter([435]);
      final dio = _dioWith(gate, adapter);

      final res = await dio.get('api/v1/runners/me/app/current_state?lat=1&lng=2');
      expect(res.statusCode, 435);
      expect(adapter.callCount, 1);
      expect(spy.calls, [true]);
      expect(
        gate.blockUntilSnapshot,
        contains('api/v1/runners/me/app/current_state'),
      );
    });

    test('subsequent call within window short-circuits without network', () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final adapter = _ScriptedAdapter([435]);
      final dio = _dioWith(gate, adapter);

      await dio.get('api/v1/runners/me/app/current_state?lat=1&lng=2');
      expect(adapter.callCount, 1);

      final s2 = await _status(dio, 'api/v1/runners/me/app/current_state?lat=5&lng=6');
      expect(s2, 435);
      expect(adapter.callCount, 1, reason: 'second call must not hit network');
      expect(spy.calls, [true, true],
          reason: 'every 435 (real + synthetic) navigates');
    });

    test('expired block lets next call through', () async {
      var now = DateTime(2026, 5, 27, 12, 0, 0);
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
        clock: () => now,
      );
      await gate.hydrate();
      final adapter = _ScriptedAdapter([435, 200]);
      final dio = _dioWith(gate, adapter);

      await dio.get('api/v1/runners/me/sos/active');
      expect(adapter.callCount, 1);

      now = now.add(const Duration(seconds: 31));

      final res2 = await dio.get('api/v1/runners/me/sos/active');
      expect(res2.statusCode, 200);
      expect(adapter.callCount, 2);
      expect(gate.blockUntilSnapshot, isEmpty,
          reason: 'expired entry removed on next request');
    });

    test('back_disabled flag propagated from matched endpoint', () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await dio.get('api/v1/runners/me/sos/active');
      expect(spy.calls, [false]);
    });

    test('synthetic 435 does not re-record block (idempotent)', () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));

      await dio.get('api/v1/runners/me/sos/active');
      final firstExpiry =
          gate.blockUntilSnapshot['api/v1/runners/me/sos/active']!;

      await Future.delayed(const Duration(milliseconds: 5));
      await _status(dio, 'api/v1/runners/me/sos/active');
      final secondExpiry =
          gate.blockUntilSnapshot['api/v1/runners/me/sos/active']!;

      expect(secondExpiry, firstExpiry,
          reason: 'synthetic 435 should not extend the window');
    });
  });

  group('Persistence', () {
    test('hydrate loads persisted blocks when enabled', () async {
      final future = DateTime.now().add(const Duration(seconds: 30));
      SharedPreferences.setMockInitialValues({
        BcpStore.storageKey: jsonEncode({
          'api/v1/runners/me/app/current_state':
              future.millisecondsSinceEpoch,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(persistAcrossSessions: true),
        storeFactory: () async => BcpStore(prefs),
        navigator: spy.onNavigate,
      );
      await gate.hydrate();

      expect(
        gate.blockUntilSnapshot,
        contains('api/v1/runners/me/app/current_state'),
      );

      final adapter = _ScriptedAdapter([200]);
      final dio = _dioWith(gate, adapter);
      final s = await _status(dio, 'api/v1/runners/me/app/current_state?lat=1');
      expect(s, 435);
      expect(adapter.callCount, 0,
          reason: 'persisted block short-circuits cold-start request');
      expect(spy.calls, [true]);
    });

    test('skips store reads when persist disabled', () async {
      var storeFactoryCalls = 0;
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async {
          storeFactoryCalls++;
          return null;
        },
      );
      await gate.hydrate();
      expect(storeFactoryCalls, 0);
    });

    test('writes are debounced into a single save', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(persistAcrossSessions: true),
        storeFactory: () async => BcpStore(prefs),
        persistDebounce: const Duration(milliseconds: 50),
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435, 435]));

      await dio.get('api/v1/runners/me/sos/active');
      await dio.get('api/v1/runners/me/app/current_state');
      // Both 435s recorded; nothing flushed yet.
      expect(prefs.getString(BcpStore.storageKey), isNull);

      await gate.flushPersistForTest();
      final raw = prefs.getString(BcpStore.storageKey)!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded.keys, containsAll([
        'api/v1/runners/me/sos/active',
        'api/v1/runners/me/app/current_state',
      ]));
    });

    test('refresh flipping persist true->false clears storage', () async {
      SharedPreferences.setMockInitialValues({
        BcpStore.storageKey: jsonEncode({
          'api/v1/runners/me/sos/active':
              DateTime.now().add(const Duration(seconds: 60))
                  .millisecondsSinceEpoch,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      var persist = true;
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(persistAcrossSessions: persist),
        storeFactory: () async => BcpStore(prefs),
      );
      await gate.hydrate();
      expect(prefs.containsKey(BcpStore.storageKey), isTrue);

      persist = false;
      await gate.refresh();

      expect(prefs.containsKey(BcpStore.storageKey), isFalse);
    });
  });

  group('Refresh', () {
    test('drops blocks for endpoints removed from allowlist', () async {
      var endpointsJson =
          '[{"path":"api/v1/runners/me/sos/active","back_disabled":false}]';
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(endpointsJson: endpointsJson),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));

      await dio.get('api/v1/runners/me/sos/active');
      expect(
        gate.blockUntilSnapshot,
        contains('api/v1/runners/me/sos/active'),
      );

      endpointsJson = '[]';
      await gate.refresh();
      expect(gate.blockUntilSnapshot, isEmpty);
    });
  });

  group('isBlocked', () {
    test('returns false when feature disabled', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(enabled: false),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      expect(gate.isBlocked('api/v1/runners/me/sos/active'), false);
    });

    test('returns false for non-allowlisted path', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      expect(gate.isBlocked('api/v1/runners/me/profile'), false);
    });

    test('returns true within block window after a real 435', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/sos/active');
      expect(gate.isBlocked('api/v1/runners/me/sos/active'), true);
    });

    test('returns false after the window expires', () async {
      var now = DateTime(2026, 5, 27, 12, 0, 0);
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
        clock: () => now,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/sos/active');
      expect(gate.isBlocked('api/v1/runners/me/sos/active'), true);

      now = now.add(const Duration(seconds: 31));
      expect(gate.isBlocked('api/v1/runners/me/sos/active'), false);
    });

    test('matches paths with query strings and host prefixes', () async {
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(),
        storeFactory: () async => null,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/app/current_state?lat=1');
      expect(
        gate.isBlocked('https://api.snabbit.com/api/v1/runners/me/app/current_state?lat=9'),
        true,
      );
    });
  });

  group('show_error_page suppression', () {
    test('435 on showErrorPage:false endpoint records block but skips navigator',
        () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(
          endpointsJson:
              '[{"path":"api/v1/runners/me/period_leave/availability","back_disabled":false,"show_error_page":false}]',
        ),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/period_leave/availability');
      expect(spy.calls, isEmpty,
          reason: 'navigator must not be called when showErrorPage is false');
      expect(gate.isBlocked('api/v1/runners/me/period_leave/availability'),
          true,
          reason: 'block window must still be recorded');
    });

    test('synthetic 435 within window also skips navigator', () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(
          endpointsJson:
              '[{"path":"api/v1/runners/me/period_leave/availability","back_disabled":false,"show_error_page":false}]',
        ),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/period_leave/availability');
      await _status(dio, 'api/v1/runners/me/period_leave/availability');
      expect(spy.calls, isEmpty);
    });

    test('showErrorPage:true endpoint still navigates on 435', () async {
      final spy = _NavSpy();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(
          endpointsJson:
              '[{"path":"api/v1/runners/me/app/current_state","back_disabled":true}]',
        ),
        storeFactory: () async => null,
        navigator: spy.onNavigate,
      );
      await gate.hydrate();
      final dio = _dioWith(gate, _ScriptedAdapter([435]));
      await _status(dio, 'api/v1/runners/me/app/current_state');
      expect(spy.calls, [true]);
    });
  });

  group('Cold-start race', () {
    test('onRequest awaits in-flight hydration before checking blocks', () async {
      final future = DateTime.now().add(const Duration(seconds: 60));
      SharedPreferences.setMockInitialValues({
        BcpStore.storageKey: jsonEncode({
          'api/v1/runners/me/sos/active': future.millisecondsSinceEpoch,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final gate = BcpGate.testInstance(
        configReader: () => _cfg(persistAcrossSessions: true),
        storeFactory: () async {
          await Future.delayed(const Duration(milliseconds: 30));
          return BcpStore(prefs);
        },
      );
      // Kick off hydration but DO NOT await — fire request immediately.
      // ignore: unawaited_futures
      gate.hydrate();
      final adapter = _ScriptedAdapter([200]);
      final dio = _dioWith(gate, adapter);
      final s = await _status(dio, 'api/v1/runners/me/sos/active');
      expect(s, 435);
      expect(adapter.callCount, 0,
          reason: 'hydration awaited before block check');
    });
  });
}
