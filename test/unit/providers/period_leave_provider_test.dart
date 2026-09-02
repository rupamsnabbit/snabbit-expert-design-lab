import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/period_leave_availability.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/services/bcp/bcp_config.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  final List<int> statusScript;
  int _i = 0;
  _ScriptedAdapter(this.statusScript);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final status =
        _i < statusScript.length ? statusScript[_i++] : statusScript.last;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'mock': true})),
      status,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }
}

Future<void> _triggerBlockOn(String path) async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.snabbit.com/',
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = _ScriptedAdapter([435]);
  dio.interceptors.add(BcpGate.instance.interceptor);
  try {
    await dio.get(path);
  } on DioException {
    // expected
  }
}

BcpConfig _periodLeaveCfg() => BcpConfig.parse(
      enabled: true,
      persistAcrossSessions: false,
      triggerStatus: 435,
      defaultWindowSec: 30,
      endpointsJson:
          '[{"path":"api/v1/runners/me/period_leave/availability","back_disabled":false,"show_error_page":false}]',
    );

void main() {
  setUp(() => BcpGate.resetForTest());
  tearDown(() => BcpGate.resetForTest());

  group('PeriodLeaveProvider', () {
    test('applyParsedForTest updates fields and periodLeaveAvailable', () {
      final p = PeriodLeaveProvider();
      p.applyParsedForTest(
        PeriodLeaveAvailability.fromJson({
          'max_period_leaves': 4,
          'period_leaves_taken': 1,
          'available': true,
        }),
      );
      expect(p.periodLeaveTotal, 4);
      expect(p.periodLeaveRemaining, 3);
      expect(p.periodLeaveAvailable, true);
    });

    test('periodLeaveAvailable prefers explicit backend false', () {
      final p = PeriodLeaveProvider();
      p.applyParsedForTest(
        PeriodLeaveAvailability.fromJson({
          'max_period_leaves': 5,
          'period_leaves_taken': 0,
          'available': false,
        }),
      );
      expect(p.periodLeaveAvailable, false);
    });

    test('periodLeaveAvailable uses remaining when backend absent', () {
      final p = PeriodLeaveProvider();
      p.applyParsedForTest(
        PeriodLeaveAvailability.fromJson({
          'max_period_leaves': 2,
          'period_leaves_taken': 1,
        }),
      );
      expect(p.periodLeaveAvailable, true);
    });
  });

  group('PeriodLeaveProvider.degradedFromBcp', () {
    test('defaults to false', () {
      final p = PeriodLeaveProvider();
      expect(p.degradedFromBcp, false);
    });

    test('flips to true after a fetch failure inside the BCP block window',
        () async {
      BcpGate.testInstance(
        configReader: _periodLeaveCfg,
        storeFactory: () async => null,
      );
      await BcpGate.instance.hydrate();
      await _triggerBlockOn('api/v1/runners/me/period_leave/availability');

      final p = PeriodLeaveProvider();
      p.markFetchFailedForTest();
      expect(p.degradedFromBcp, true);
    });

    test('stays false on fetch failure when no BCP block is active', () async {
      BcpGate.testInstance(
        configReader: _periodLeaveCfg,
        storeFactory: () async => null,
      );
      await BcpGate.instance.hydrate();

      final p = PeriodLeaveProvider();
      p.markFetchFailedForTest();
      expect(p.degradedFromBcp, false);
    });

    test('resets to false on a successful parse', () async {
      BcpGate.testInstance(
        configReader: _periodLeaveCfg,
        storeFactory: () async => null,
      );
      await BcpGate.instance.hydrate();
      await _triggerBlockOn('api/v1/runners/me/period_leave/availability');

      final p = PeriodLeaveProvider();
      p.markFetchFailedForTest();
      expect(p.degradedFromBcp, true);

      p.applyParsedForTest(PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 3,
        'period_leaves_taken': 0,
        'available': true,
      }));
      expect(p.degradedFromBcp, false);
    });

    test('notifies listeners only when degraded flag changes', () async {
      BcpGate.testInstance(
        configReader: _periodLeaveCfg,
        storeFactory: () async => null,
      );
      await BcpGate.instance.hydrate();
      await _triggerBlockOn('api/v1/runners/me/period_leave/availability');

      final p = PeriodLeaveProvider();
      var notifications = 0;
      p.addListener(() => notifications++);

      p.markFetchFailedForTest();
      expect(notifications, 1);

      p.markFetchFailedForTest();
      expect(notifications, 1,
          reason: 'no notification when value is unchanged');
    });
  });
}
