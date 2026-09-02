import 'dart:async';

import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/pages/getting_started/getting_started.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/debug/network_inspector.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/monitoring/uuid_generator.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/services/network_channel.dart';
import 'package:snabbit_runner/services/realtime/realtime_channel.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import '../main.dart';
import 'globals.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();

  factory HttpService() => _instance;

  HttpService._internal() {
    // Debug-only: mirror all HttpService traffic into the Chucker inspector,
    // opened from the debug menu. Never attached in release builds.
    // The in-app notification (on/off + alignment) is owned by
    // applyChuckerDebugSettings(), applied from main() after the persisted
    // debug prefs load — setting it here could clobber that value depending on
    // when this singleton is first constructed.
    if (kDebugMode) {
      _dio.interceptors.add(ChuckerDioInterceptor());
    }
    _dio.interceptors.add(BcpGate.instance.interceptor);
    // Debug-only: capture this client's traffic in the Alice inspector.
    // No-op (and tree-shaken) in profile/release builds.
    if (kDebugMode) {
      DebugNetworkInspector.instance.attach(_dio);
    }
  }

  final Dio _dio = Dio();

  String? _cachedToken;

  void invalidateTokenCache() {
    _cachedToken = null;
  }

  Future<String?> _getToken() async {
    return _cachedToken ??=
        await SecureStorageUtils.getAccessToken("HTTP_SERVICE_GET_TOKEN");
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    bool suppressUnauthorizedHandler = false,
    // required String sessionId
  }) async {
    _dio.options.headers['content-Type'] = 'application/json';
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // _dio.options.headers['Session-Id'] = sessionId;
    // _dio.options.headers['Device-Id'] = prefs.getString("Device-Id");
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.connectTimeout = const Duration(seconds: 60);
    try {
      Options? options;
      final token = await _getToken();
      if (token != null) {
        headers.addAll({
          "Authorization": "Bearer $token",
          "x-version-code": await GlobalState().currentVersionCode(),
          // "Session-Id": sessionId,
          // Add any other headers if needed
        });
      }
      headers["X-Request-ID"] = UuidGenerator().generateUuid("GET");
      options = Options(
        headers: headers,
      );
      debugPrint(
          "GET Execution started for ${path.split(".com").last} at ${DateTime.now()}");
/*
      MonitoringServiceHelper.logDebug('GET Request Started', {
        'path': path,
        'queryParams': queryParameters,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      final response = await _dio.get(
          // serverPath(path),
          path,
          queryParameters: queryParameters,
          // cancelToken: _cancelToken,
          options: options);
/*
      MonitoringServiceHelper.logInfo('GET Request Successful', {
        'path': path,
        'statusCode': response.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      GlobalState().appError.value = AppErrorType.none;
      debugPrint("GET Execution finished for $path at ${DateTime.now()}");
      return response;
    } on DioException catch (e) {
      debugPrint("GET Execution finished with error $e at ${DateTime.now()}");
      if (e.response?.statusCode == 401 && !suppressUnauthorizedHandler) {
        handle403();
      }
      if (e.type == DioExceptionType.cancel) {
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        GlobalState().appError.value = AppErrorType.serverDown;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.badResponse) {
        GlobalState().appError.value = AppErrorType.invalidRequest;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionError) {
        GlobalState().appError.value = AppErrorType.noInternet;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else {
        GlobalState().appError.value = AppErrorType.otherError;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      }
    }
  }

  Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    Duration? receiveTimeout,
    Duration? connectTimeout,
    bool suppressUnauthorizedHandler = false,
  }) async {
    _dio.options.headers['content-Type'] = 'application/json';
    // _dio.options.headers["Device-Id"] = prefs.getString("Device-Id");
    _dio.options.receiveTimeout = receiveTimeout ?? const Duration(seconds: 60);
    _dio.options.connectTimeout = connectTimeout ?? const Duration(seconds: 60);
    if (data != null && data["sessionId"] != null) {
      _dio.options.headers['Session-Id'] = "${data["sessionId"]}";
    }
    try {
      Options? options;
      final token = await _getToken();
      if (token != null) {
        headers.addAll({
          "Authorization": "Bearer $token",
          "x-version-code": await GlobalState().currentVersionCode(),
          // "Session-Id": sessionId,
          // Add any other headers if needed
        });
      }
      headers["X-Request-ID"] = UuidGenerator().generateUuid("POST");
      options = Options(
        headers: headers,
      );
/*
      MonitoringServiceHelper.logDebug('POST Request Started', {
        'path': path,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      debugPrint(
          "POST Execution started for ${path.split(".com").last} at ${DateTime.now()}");
      final response = await _dio.post(path,
          data: data,
          queryParameters: queryParameters,
          // cancelToken: _cancelToken,
          options: options);
/*
      MonitoringServiceHelper.logInfo('POST Request Successful', {
        'path': path,
        'statusCode': response.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      GlobalState().appError.value = AppErrorType.none;
      debugPrint("POST Execution finished for $path at ${DateTime.now()}");
      return response;
    } on DioException catch (e) {
      debugPrint("POST Execution finished with error $e at ${DateTime.now()}");
      if (e.response?.statusCode == 401 && !suppressUnauthorizedHandler) {
        handle403();
      }
      if (e.type == DioExceptionType.cancel) {
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        GlobalState().appError.value = AppErrorType.serverDown;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.badResponse) {
        GlobalState().appError.value = AppErrorType.invalidRequest;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionError) {
        GlobalState().appError.value = AppErrorType.noInternet;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else {
        GlobalState().appError.value = AppErrorType.otherError;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      }
    }
  }

  Future<Response> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic> headers = const {},
  }) async {
    _dio.options.headers['content-Type'] = 'application/json';
    // _dio.options.headers["Device-Id"] = prefs.getString("Device-Id");
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.connectTimeout = const Duration(seconds: 60);
    if (data != null && data["sessionId"] != null) {
      _dio.options.headers['Session-Id'] = "${data["sessionId"]}";
    }
    try {
      Options? options;
      final token = await _getToken();
      if (token != null) {
        headers.addAll({
          "Authorization": "Bearer $token",
          "x-version-code": await GlobalState().currentVersionCode(),
          // "Session-Id": sessionId,
          // Add any other headers if needed
        });
      }
      headers["X-Request-ID"] = UuidGenerator().generateUuid("PUT");
      options = Options(
        headers: headers,
      );
/*
      MonitoringServiceHelper.logDebug('PUT Request Started', {
        'path': path,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      debugPrint(
          "PUT Execution started for ${path.split(".com").last} at ${DateTime.now()}");
      final response = await _dio.put(path,
          data: data,
          // cancelToken: _cancelToken,
          options: options);
/*
      MonitoringServiceHelper.logInfo('PUT Request Successful', {
        'path': path,
        'statusCode': response.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      GlobalState().appError.value = AppErrorType.none;
      debugPrint("PUT Execution finished for $path at ${DateTime.now()}");
      return response;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        handle403();
      }
      if (e.type == DioExceptionType.cancel) {
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        GlobalState().appError.value = AppErrorType.serverDown;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.badResponse) {
        GlobalState().appError.value = AppErrorType.invalidRequest;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionError) {
        GlobalState().appError.value = AppErrorType.noInternet;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else {
        GlobalState().appError.value = AppErrorType.otherError;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      }
    }
  }

  Future<Response?> postDocs(
    String path, {
    required FormData formData,
    Map<String, dynamic> headers = const {},
  }) async {
    try {
      _dio.options.headers['content-Type'] = 'application/json';
      // _dio.options.headers["Device-Id"] = prefs.getString("Device-Id");
      _dio.options.receiveTimeout = const Duration(seconds: 60);
      _dio.options.connectTimeout = const Duration(seconds: 60);
      Options? options;
      final token = await _getToken();
      if (token != null) {
        headers.addAll({
          "Authorization": "Bearer $token",
          "x-platform": defaultTargetPlatform.name,
          "x-version-code": GlobalState().currentVersionCode,
          'Content-Type': 'multipart/form-data',
          // "Session-Id": sessionId,
          // Add any other headers if needed
        });
      }
      headers["X-Request-ID"] = UuidGenerator().generateUuid("POST_DOCS");
      options = Options(headers: headers);
      // Convert files to MultipartFile

      // Make PUT request
      /*
      MonitoringServiceHelper.logDebug('POST Docs Request Started', {
        'path': path,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      debugPrint("POST DOCS Execution finished for $path at ${DateTime.now()}");
      final response = await _dio.post(
        path,
        data: formData,
        options: options,
      );

      if (response.statusCode == 200) {
        /*
        MonitoringServiceHelper.logInfo('POST Docs Request Successful', {
          'path': path,
          'statusCode': response.statusCode,
          'timestamp': DateTime.now().toIso8601String(),
        });
        */
        return response;
      } else {
        /*
        MonitoringServiceHelper.logWarning(
            'POST Docs Request Returned Non-200 Status', {
          'path': path,
          'statusCode': response.statusCode,
          'timestamp': DateTime.now().toIso8601String(),
        });
        */
        return null;
      }
    } on DioException catch (e) {
      debugPrint(
        "POST DOCS Execution finished with error ${e.response} at ${DateTime.now()}",
      );
/*
      MonitoringServiceHelper.logError('POST Docs Request Failed', {
        'path': path,
        'error': e.toString(),
        'errorType': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
*/
      if (e.response?.statusCode == 401) {
        handle403();
      }
      if (e.type == DioExceptionType.cancel) {
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        GlobalState().appError.value = AppErrorType.serverDown;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.badResponse) {
        GlobalState().appError.value = AppErrorType.invalidRequest;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else if (e.type == DioExceptionType.connectionError) {
        GlobalState().appError.value = AppErrorType.noInternet;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      } else {
        GlobalState().appError.value = AppErrorType.otherError;
        if (e.response != null) {
          return e.response!;
        }
        throw Exception(e.message);
      }
    }
  }

// Cancel request logic doesn't work as it is. New CancelToken() is required to be maintained for each request.
// void cancelRequest() {
//   _cancelToken.cancel('Request cancelled');
//   _cancelToken = CancelToken();
// }
}

Future<void> handle403() async {
  // `isBackgroundIsolate` is set on both background isolates (the bg-location
  // service and the FCM handler). Neither has the KMP auth MethodChannel
  // (AuthPlugin is registered only on MainActivity's FlutterEngine) nor a
  // navigator, so touching either from here throws MissingPluginException /
  // dereferences a null context. Route those main-isolate-only concerns to
  // the main isolate; do only what's isolate-safe locally.
  final bool isBackground = GlobalState().isBackgroundIsolate;

  // Clear shield upload queue to prevent cross-user data leakage.
  GlobalState().shieldUploadQueue?.stop();
  unawaited(GlobalState().shieldUploadQueue?.clearAll() ?? Future.value());
  GlobalState().shieldUploadQueue = null;

  if (isBackground) {
    // Hand the logout to the main isolate (KMP token clear + redirect) BEFORE
    // stopping the service, otherwise stopSelf() could tear the isolate down
    // before the relay is delivered.
    notifyMainIsolateForceLogout();
  } else {
    // Wipe the KMP-side bearer token so subsequent requests through
    // SnabbitHttpClient don't go out with stale auth. Awaited so an
    // in-flight retry from any caller can't pick the stale token off
    // StoreManager's MutableStateFlow before we've cleared it. Guarded so a
    // channel failure degrades gracefully instead of surfacing as an
    // unhandled async exception.
    try {
      await NetworkChannel.clearToken();
    } catch (e) {
      MonitoringServiceHelper.logError(
        'HANDLE_403_KMP_CLEAR_TOKEN_FAILED',
        {'error': e.toString()},
      );
    }
    // Drop super-props (runner_id/cluster_id/region_id) on both Dart and KMP
    // sides so the previous user's context can't ride onto logged-out or
    // next-user events. Main-isolate only — has the KMP channel; the
    // background isolate relays logout to the main isolate above.
    OnboardingAnalytics.clearSuperProperties();
  }

  // Isolate-aware: from a background isolate this stops via the ServiceInstance
  // rather than the missing main-isolate FlutterBackgroundService channel.
  stopService();

  String? token = await SecureStorageUtils.getAccessToken("HANDLE_403_METHOD");

  HttpService().invalidateTokenCache();
  // Secure storage is shared across isolates, so clearing it here also stops
  // the foreground Dart HTTP path from reusing the stale token.
  await SecureStorageUtils.clearToken();
  // WS5: forced-logout — tear down the MQTT realtime engine + its persisted
  // config too (idempotent; no-op for the polling cohort).
  await RealtimeChannel.stop();
  await RealtimeChannel.clearConfig();
  GlobalState().appError.value = AppErrorType.none;

  // Navigation is a main-isolate concern — a background isolate has no
  // navigator. The main isolate performs the redirect when it drains the
  // force-logout relay sent above.
  if (isBackground) return;

  try {
    if (token?.isNotEmpty == true) {
      Navigator.of(GlobalState().navigatorKey.currentContext!)
          .pushNamedAndRemoveUntil(GettingStarted.routeName, (_) => false);
    }
  } catch (e) {
    // DO NOTHING
  }

  // KMP (MQTT) cohort: the redirect above ran on the Flutter navigator, which sits
  // BEHIND the native shell Activity when a cohort runner is on a native screen — so
  // without this the runner is logged out under the hood but still staring at the
  // (now unauthenticated) native surface. Finish that shell so the login screen we
  // just pushed becomes visible. No-op for non-cohort runners (no native host alive).
  // Gated on the same token-present condition as the redirect; the wrapper is
  // best-effort (logs, never throws), so it can't block the already-completed logout.
  if (token?.isNotEmpty == true) {
    await KmpNavigationBridge.instance.exitNativeShell();
  }
}
