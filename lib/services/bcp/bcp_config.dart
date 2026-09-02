import 'dart:convert';

import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

class BcpConfig {
  final bool enabled;
  final bool persistAcrossSessions;
  final int triggerStatus;
  final int defaultWindowSec;
  final List<BcpEndpoint> endpoints;

  const BcpConfig({
    required this.enabled,
    required this.persistAcrossSessions,
    required this.triggerStatus,
    required this.defaultWindowSec,
    required this.endpoints,
  });

  static const int _minStatus = 400;
  static const int _maxStatus = 599;
  static const int _minWindowSec = 1;
  static const int _maxWindowSec = 600;
  static const int _fallbackStatus = 435;
  static const int _fallbackWindowSec = 30;

  static const String _defaultEndpointsJson =
      '[{"path":"api/v1/runners/me/app/current_state","back_disabled":true,"window_sec":30},'
      '{"path":"api/v1/runners/me/period_leave/availability","back_disabled":false,"show_error_page":false},'
      '{"path":"api/v1/runners/me/emergency_logout/availability","back_disabled":false,"show_error_page":false}]';

  static const Map<String, dynamic> defaults = {
    RemoteConfigKeys.expertBcpEnabled: true,
    RemoteConfigKeys.expertBcpPersistAcrossSessions: false,
    RemoteConfigKeys.expertBcpTriggerStatus: _fallbackStatus,
    RemoteConfigKeys.expertBcpDefaultWindowSec: _fallbackWindowSec,
    RemoteConfigKeys.expertBcpEndpoints: _defaultEndpointsJson,
  };

  factory BcpConfig.fromRemoteConfig(RemoteConfigService rc) {
    return BcpConfig.parse(
      enabled: rc.getBool(RemoteConfigKeys.expertBcpEnabled, defaultValue: true),
      persistAcrossSessions: rc.getBool(
          RemoteConfigKeys.expertBcpPersistAcrossSessions,
          defaultValue: false),
      triggerStatus: rc.getInt(RemoteConfigKeys.expertBcpTriggerStatus,
          defaultValue: _fallbackStatus),
      defaultWindowSec: rc.getInt(RemoteConfigKeys.expertBcpDefaultWindowSec,
          defaultValue: _fallbackWindowSec),
      endpointsJson: rc.getString(RemoteConfigKeys.expertBcpEndpoints,
          defaultValue: _defaultEndpointsJson),
    );
  }

  factory BcpConfig.parse({
    required bool enabled,
    required bool persistAcrossSessions,
    required int triggerStatus,
    required int defaultWindowSec,
    required String endpointsJson,
  }) {
    final clampedStatus = (triggerStatus < _minStatus || triggerStatus > _maxStatus)
        ? _fallbackStatus
        : triggerStatus;
    final clampedDefaultWindow = _clampWindow(defaultWindowSec) ?? _fallbackWindowSec;
    final endpoints = _parseEndpoints(endpointsJson, clampedDefaultWindow);
    return BcpConfig(
      enabled: enabled,
      persistAcrossSessions: persistAcrossSessions,
      triggerStatus: clampedStatus,
      defaultWindowSec: clampedDefaultWindow,
      endpoints: endpoints,
    );
  }

  BcpEndpoint? matchFor(String normalizedPath) {
    for (final entry in endpoints) {
      if (normalizedPath.startsWith(entry.path)) return entry;
    }
    return null;
  }

  static List<BcpEndpoint> _parseEndpoints(String raw, int defaultWindow) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return const [];
      final out = <BcpEndpoint>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final path = item['path'];
        if (path is! String || path.isEmpty) continue;
        final backDisabled = item['back_disabled'] == true;
        final showErrorPage = item['show_error_page'] != false;
        final perEntryWindow = _clampWindow(_asInt(item['window_sec']));
        out.add(BcpEndpoint(
          path: path,
          backDisabled: backDisabled,
          showErrorPage: showErrorPage,
          windowSec: perEntryWindow ?? defaultWindow,
        ));
      }
      return List.unmodifiable(out);
    } catch (_) {
      return const [];
    }
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int? _clampWindow(int? value) {
    if (value == null) return null;
    if (value < _minWindowSec || value > _maxWindowSec) return null;
    return value;
  }
}

class BcpEndpoint {
  final String path;
  final bool backDisabled;
  final bool showErrorPage;
  final int windowSec;

  const BcpEndpoint({
    required this.path,
    required this.backDisabled,
    required this.windowSec,
    this.showErrorPage = true,
  });

  @override
  bool operator ==(Object other) =>
      other is BcpEndpoint &&
      other.path == path &&
      other.backDisabled == backDisabled &&
      other.showErrorPage == showErrorPage &&
      other.windowSec == windowSec;

  @override
  int get hashCode =>
      Object.hash(path, backDisabled, showErrorPage, windowSec);

  @override
  String toString() =>
      'BcpEndpoint(path=$path, backDisabled=$backDisabled, '
      'showErrorPage=$showErrorPage, windowSec=$windowSec)';
}

String bcpNormalizePath(String raw) {
  var p = raw.split('?').first;
  const marker = '.com/';
  final idx = p.indexOf(marker);
  if (idx != -1) p = p.substring(idx + marker.length);
  if (p.startsWith('/')) p = p.substring(1);
  return p;
}
