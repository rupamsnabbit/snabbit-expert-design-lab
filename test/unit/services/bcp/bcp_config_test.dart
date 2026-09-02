import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/bcp/bcp_config.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';

void main() {
  group('BcpConfig.parse', () {
    test('builds disabled config from defaults', () {
      final cfg = BcpConfig.parse(
        enabled: false,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: '[]',
      );
      expect(cfg.enabled, false);
      expect(cfg.persistAcrossSessions, false);
      expect(cfg.triggerStatus, 435);
      expect(cfg.defaultWindowSec, 30);
      expect(cfg.endpoints, isEmpty);
    });

    test('clamps trigger status below 400 to fallback 435', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 200,
        defaultWindowSec: 30,
        endpointsJson: '[]',
      );
      expect(cfg.triggerStatus, 435);
    });

    test('clamps trigger status above 599 to fallback 435', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 700,
        defaultWindowSec: 30,
        endpointsJson: '[]',
      );
      expect(cfg.triggerStatus, 435);
    });

    test('clamps default window below 1 to fallback 30', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 0,
        endpointsJson: '[]',
      );
      expect(cfg.defaultWindowSec, 30);
    });

    test('clamps default window above 600 to fallback 30', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 9999,
        endpointsJson: '[]',
      );
      expect(cfg.defaultWindowSec, 30);
    });
  });

  group('BcpConfig.parse endpoints', () {
    test('parses well-formed endpoint list with per-entry window', () {
      const jsonStr = '''[
        { "path": "api/v1/runners/me/app/current_state", "back_disabled": true, "window_sec": 45 },
        { "path": "api/v1/runners/me/sos/active", "back_disabled": false }
      ]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints, hasLength(2));
      expect(cfg.endpoints[0].path, 'api/v1/runners/me/app/current_state');
      expect(cfg.endpoints[0].backDisabled, true);
      expect(cfg.endpoints[0].windowSec, 45);
      expect(cfg.endpoints[1].path, 'api/v1/runners/me/sos/active');
      expect(cfg.endpoints[1].backDisabled, false);
      expect(cfg.endpoints[1].windowSec, 30, reason: 'falls back to defaultWindowSec');
    });

    test('drops entries with missing or empty path', () {
      const jsonStr = '''[
        { "back_disabled": false },
        { "path": "", "back_disabled": false },
        { "path": "api/v1/valid", "back_disabled": false }
      ]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints, hasLength(1));
      expect(cfg.endpoints.first.path, 'api/v1/valid');
    });

    test('drops non-map entries', () {
      const jsonStr = '''["not-a-map", 42, { "path": "api/v1/valid", "back_disabled": false }]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints, hasLength(1));
    });

    test('clamps per-entry window_sec out of range to default', () {
      const jsonStr = '''[
        { "path": "api/v1/a", "back_disabled": false, "window_sec": -5 },
        { "path": "api/v1/b", "back_disabled": false, "window_sec": 9999 }
      ]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 42,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints[0].windowSec, 42);
      expect(cfg.endpoints[1].windowSec, 42);
    });

    test('back_disabled defaults to false when missing', () {
      const jsonStr = '''[{ "path": "api/v1/x" }]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints.first.backDisabled, false);
    });

    test('show_error_page defaults to true when missing', () {
      const jsonStr = '''[{ "path": "api/v1/x" }]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints.first.showErrorPage, true);
    });

    test('show_error_page reads false when explicitly set', () {
      const jsonStr =
          '''[{ "path": "api/v1/x", "show_error_page": false }]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints.first.showErrorPage, false);
    });

    test('non-bool show_error_page falls back to true', () {
      const jsonStr =
          '''[{ "path": "api/v1/x", "show_error_page": "nope" }]''';
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: jsonStr,
      );
      expect(cfg.endpoints.first.showErrorPage, true);
    });

    test('malformed JSON yields empty endpoints, other fields intact', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: true,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: 'not-json',
      );
      expect(cfg.endpoints, isEmpty);
      expect(cfg.enabled, true,
          reason: 'kill switch must survive bad endpoints JSON');
      expect(cfg.persistAcrossSessions, true);
    });

    test('non-array JSON yields empty endpoints', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: '{"path":"oops"}',
      );
      expect(cfg.endpoints, isEmpty);
    });

    test('empty string endpoints yields empty list', () {
      final cfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: '',
      );
      expect(cfg.endpoints, isEmpty);
    });
  });

  group('BcpConfig.matchFor', () {
    final cfg = BcpConfig.parse(
      enabled: true,
      persistAcrossSessions: false,
      triggerStatus: 435,
      defaultWindowSec: 30,
      endpointsJson: '''[
        { "path": "api/v1/runners/me/app/current_state", "back_disabled": true },
        { "path": "api/v1/runners/me/sos/active", "back_disabled": false },
        { "path": "api/v1/runners/shifts/admin/", "back_disabled": false }
      ]''',
    );

    test('matches current_state exactly', () {
      final m = cfg.matchFor('api/v1/runners/me/app/current_state');
      expect(m, isNotNull);
      expect(m!.backDisabled, true);
    });

    test('matches current_state with query stripped already (caller normalizes)', () {
      final m = cfg.matchFor(
          bcpNormalizePath(
              'https://api.snabbit.com/api/v1/runners/me/app/current_state?lat=1&lng=2'));
      expect(m, isNotNull);
      expect(m!.path, 'api/v1/runners/me/app/current_state');
    });

    test('matches admin path with runner id appended', () {
      final m = cfg.matchFor('api/v1/runners/shifts/admin/12345');
      expect(m, isNotNull);
      expect(m!.path, 'api/v1/runners/shifts/admin/');
    });

    test('returns null for non-allowlisted path', () {
      final m = cfg.matchFor('api/v1/runners/me/profile');
      expect(m, isNull);
    });

    test('returns null when endpoints list is empty', () {
      final emptyCfg = BcpConfig.parse(
        enabled: true,
        persistAcrossSessions: false,
        triggerStatus: 435,
        defaultWindowSec: 30,
        endpointsJson: '[]',
      );
      expect(emptyCfg.matchFor('api/v1/anything'), isNull);
    });
  });

  group('bcpNormalizePath', () {
    test('strips query string', () {
      expect(bcpNormalizePath('api/v1/x?a=1&b=2'), 'api/v1/x');
    });

    test('strips https host', () {
      expect(
        bcpNormalizePath('https://api.snabbit.com/api/v1/x'),
        'api/v1/x',
      );
    });

    test('strips host and query', () {
      expect(
        bcpNormalizePath('https://api.snabbit.com/api/v1/x?lat=1'),
        'api/v1/x',
      );
    });

    test('strips leading slash', () {
      expect(bcpNormalizePath('/api/v1/x'), 'api/v1/x');
    });

    test('leaves already-normalized path untouched', () {
      expect(bcpNormalizePath('api/v1/x'), 'api/v1/x');
    });
  });

  group('BcpConfig.defaults', () {
    test('production defaults are enabled with the three gated endpoints', () {
      expect(BcpConfig.defaults[RemoteConfigKeys.expertBcpEnabled], true);
      expect(
          BcpConfig.defaults[RemoteConfigKeys.expertBcpPersistAcrossSessions], false);
      expect(BcpConfig.defaults[RemoteConfigKeys.expertBcpTriggerStatus], 435);
      expect(BcpConfig.defaults[RemoteConfigKeys.expertBcpDefaultWindowSec], 30);

      final parsed = BcpConfig.parse(
        enabled: BcpConfig.defaults[RemoteConfigKeys.expertBcpEnabled] as bool,
        persistAcrossSessions: BcpConfig
            .defaults[RemoteConfigKeys.expertBcpPersistAcrossSessions] as bool,
        triggerStatus:
            BcpConfig.defaults[RemoteConfigKeys.expertBcpTriggerStatus] as int,
        defaultWindowSec:
            BcpConfig.defaults[RemoteConfigKeys.expertBcpDefaultWindowSec] as int,
        endpointsJson:
            BcpConfig.defaults[RemoteConfigKeys.expertBcpEndpoints] as String,
      );
      expect(parsed.endpoints.map((e) => e.path).toList(), [
        'api/v1/runners/me/app/current_state',
        'api/v1/runners/me/period_leave/availability',
        'api/v1/runners/me/emergency_logout/availability',
      ]);
      expect(
        parsed.matchFor('api/v1/runners/me/app/current_state')!.backDisabled,
        true,
      );

      // Drawer-open availability endpoints opt out of full-screen navigation;
      // the foreground current_state endpoint stays opted in.
      expect(
        parsed
            .matchFor('api/v1/runners/me/app/current_state')!
            .showErrorPage,
        true,
      );
      expect(
        parsed
            .matchFor('api/v1/runners/me/period_leave/availability')!
            .showErrorPage,
        false,
      );
      expect(
        parsed
            .matchFor('api/v1/runners/me/emergency_logout/availability')!
            .showErrorPage,
        false,
      );
    });
  });

  group('BcpEndpoint', () {
    test('equality and hashCode reflect all fields', () {
      const a = BcpEndpoint(path: 'x', backDisabled: true, windowSec: 10);
      const b = BcpEndpoint(path: 'x', backDisabled: true, windowSec: 10);
      const c = BcpEndpoint(path: 'x', backDisabled: false, windowSec: 10);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
