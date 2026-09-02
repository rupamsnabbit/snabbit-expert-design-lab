import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snabbit_runner/pages/bcp/bcp_degraded_page.dart';
import 'package:snabbit_runner/services/bcp/bcp_config.dart';
import 'package:snabbit_runner/services/bcp/bcp_store.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

typedef BcpNavigator = void Function(bool backDisabled);
typedef BcpConfigReader = BcpConfig Function();
typedef BcpStoreFactory = Future<BcpStore?> Function();

const String _syntheticFlag = '_bcpSynthetic';

class BcpGate {
  BcpGate._({
    required BcpConfigReader configReader,
    required BcpStoreFactory storeFactory,
    required BcpNavigator navigator,
    Duration persistDebounce = const Duration(milliseconds: 200),
    DateTime Function()? clock,
  })  : _configReader = configReader,
        _storeFactory = storeFactory,
        _navigator = navigator,
        _persistDebounce = persistDebounce,
        _clock = clock ?? DateTime.now,
        _config = configReader();

  static BcpGate? _instance;

  static BcpGate get instance {
    return _instance ??= BcpGate._(
      configReader: () => BcpConfig.fromRemoteConfig(RemoteConfigService.instance),
      storeFactory: () async => BcpStore(await SharedPreferences.getInstance()),
      navigator: bcpDefaultNavigator,
    );
  }

  @visibleForTesting
  static BcpGate testInstance({
    required BcpConfigReader configReader,
    required BcpStoreFactory storeFactory,
    BcpNavigator? navigator,
    Duration persistDebounce = const Duration(milliseconds: 200),
    DateTime Function()? clock,
  }) {
    final gate = BcpGate._(
      configReader: configReader,
      storeFactory: storeFactory,
      navigator: navigator ?? _noopNavigator,
      persistDebounce: persistDebounce,
      clock: clock,
    );
    _instance = gate;
    return gate;
  }

  @visibleForTesting
  static void resetForTest() {
    _instance?._dispose();
    _instance = null;
  }

  final BcpConfigReader _configReader;
  final BcpStoreFactory _storeFactory;
  final BcpNavigator _navigator;
  final Duration _persistDebounce;
  final DateTime Function() _clock;

  BcpConfig _config;
  bool _hydrated = false;
  Future<void>? _hydration;
  BcpStore? _store;
  final Map<String, DateTime> _blockUntil = {};
  Timer? _persistTimer;

  @visibleForTesting
  BcpConfig get config => _config;

  @visibleForTesting
  Map<String, DateTime> get blockUntilSnapshot => Map.unmodifiable(_blockUntil);

  Future<void> hydrate() {
    return _hydration ??= _hydrate();
  }

  /// Returns true if [path] matches an allowlisted endpoint and the block
  /// window is still active. Providers use this to distinguish a BCP-driven
  /// failure from any other availability failure (network, server error).
  bool isBlocked(String path) {
    if (!_config.enabled) return false;
    final match = _config.matchFor(bcpNormalizePath(path));
    if (match == null) return false;
    final expiry = _blockUntil[match.path];
    return expiry != null && expiry.isAfter(_clock());
  }

  Future<void> _hydrate() async {
    try {
      _config = _configReader();
      if (_config.persistAcrossSessions) {
        _store = await _storeFactory();
        final loaded = await _store?.load() ?? <String, DateTime>{};
        _blockUntil.addAll(loaded);
      }
    } catch (_) {
    } finally {
      _hydrated = true;
    }
  }

  Future<void> refresh() async {
    final previous = _config;
    try {
      _config = _configReader();
    } catch (_) {
      return;
    }
    _dropBlocksOutsideAllowlist();
    await _reconcilePersistence(previous);
  }

  void _dropBlocksOutsideAllowlist() {
    final allowed = _config.endpoints.map((e) => e.path).toSet();
    final removed = _blockUntil.keys.where((k) => !allowed.contains(k)).toList();
    if (removed.isEmpty) return;
    for (final k in removed) {
      _blockUntil.remove(k);
    }
    _schedulePersist();
  }

  Future<void> _reconcilePersistence(BcpConfig previous) async {
    if (previous.persistAcrossSessions && !_config.persistAcrossSessions) {
      _persistTimer?.cancel();
      _persistTimer = null;
      await _store?.clear();
      _store = null;
    } else if (!previous.persistAcrossSessions && _config.persistAcrossSessions) {
      _store ??= await _storeFactory();
      _schedulePersist();
    }
  }

  Interceptor get interceptor => InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      );

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_config.enabled) {
      handler.next(options);
      return;
    }
    if (_hydration != null && !_hydrated) {
      await _hydration;
    }
    final path = bcpNormalizePath(options.path);
    final match = _config.matchFor(path);
    if (match == null) {
      handler.next(options);
      return;
    }
    final expiry = _blockUntil[match.path];
    if (expiry != null && expiry.isAfter(_clock())) {
      if (match.showErrorPage) {
        _navigator(match.backDisabled);
      }
      options.extra[_syntheticFlag] = true;
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: _config.triggerStatus,
            data: {'bcp': true, 'endpoint': match.path},
          ),
          type: DioExceptionType.badResponse,
        ),
        true,
      );
      return;
    }
    if (expiry != null) {
      _blockUntil.remove(match.path);
      _schedulePersist();
    }
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    _maybeRecord(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  void _onError(DioException err, ErrorInterceptorHandler handler) {
    final isSynthetic = err.requestOptions.extra[_syntheticFlag] == true;
    if (!isSynthetic) {
      _maybeRecord(err.requestOptions, err.response?.statusCode);
    }
    handler.next(err);
  }

  void _maybeRecord(RequestOptions options, int? statusCode) {
    if (!_config.enabled) return;
    if (statusCode != _config.triggerStatus) return;
    final match = _config.matchFor(bcpNormalizePath(options.path));
    if (match == null) return;
    _recordBlock(match);
    if (match.showErrorPage) {
      _navigator(match.backDisabled);
    }
  }

  void _recordBlock(BcpEndpoint match) {
    _blockUntil[match.path] = _clock().add(Duration(seconds: match.windowSec));
    _schedulePersist();
  }

  void _schedulePersist() {
    if (!_config.persistAcrossSessions) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persistNow);
  }

  Future<void> _persistNow() async {
    _persistTimer = null;
    try {
      await _store?.save(Map<String, DateTime>.from(_blockUntil));
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> flushPersistForTest() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _persistNow();
  }

  void _dispose() {
    _persistTimer?.cancel();
    _persistTimer = null;
  }

  static void _noopNavigator(bool _) {}
}

/// Default navigator: pushes [BcpDegradedPage] onto the global navigator,
/// skipping the push if the top route is already the degraded page.
/// Lives outside [BcpGate] so it stays unit-testable in isolation.
void bcpDefaultNavigator(bool backDisabled) {
  final navigator = GlobalState().navigatorKey.currentState;
  if (navigator == null) return;
  if (_topRouteIsBcpDegraded(navigator)) return;
  navigator.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: BcpDegradedPage.routeName),
      builder: (_) => BcpDegradedPage(
        backDisabled: backDisabled,
        source: BcpDegradedPage.sourceAuto,
      ),
    ),
  );
}

bool _topRouteIsBcpDegraded(NavigatorState navigator) {
  bool isTop = false;
  navigator.popUntil((route) {
    isTop = route.settings.name == BcpDegradedPage.routeName;
    return true;
  });
  return isTop;
}
