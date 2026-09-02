import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';

/// A [CustomPathHandler] that serves captured images from the
/// [CaptureRegistry] via `WebViewAssetLoader`.
///
/// Registered at `/captures/` so a URL like
/// `https://appassets.androidplatform.net/captures/<token>.jpg`
/// is intercepted by the WebView's native networking layer and served
/// directly from disk — **no image bytes cross the JS bridge**.
///
/// Returns a fully-specified [WebResourceResponse] (status code, headers,
/// Content-Length) so the WebView's image decoder can stream efficiently.
/// Unknown or expired tokens receive a 404 (null data).
///
/// **CORS note:** All responses include `Access-Control-Allow-Origin: *`
/// and permissive `Access-Control-Allow-Methods/Headers` so the web's
/// `fetch()` works cross-origin. [CustomPathHandler.handle] only receives
/// the path — the HTTP method is not exposed, so we cannot return a
/// dedicated 204 for OPTIONS preflight. The headers on every response
/// satisfy preflight requirements on Android WebView. If the web team
/// adds custom request headers, verify preflight still works on the
/// target WebView versions.
class CapturePathHandler extends CustomPathHandler {
  CapturePathHandler({required super.path});

  @override
  Future<WebResourceResponse?> handle(String path) async {
    // Path arrives as e.g. "1716825600000000_0.jpg" — strip the trailing
    // extension only (not greedy like replaceAll).
    final filename = path.split('/').last;
    final token = filename.endsWith('.jpg')
        ? filename.substring(0, filename.length - 4)
        : filename;
    final stopwatch = Stopwatch()..start();

    final file = CaptureRegistry.instance.resolve(token);

    if (file == null || !await file.exists()) {
      stopwatch.stop();
      MonitoringServiceHelper.logInfo(
        'capture_serve_miss',
        {
          'token': token,
          'reason': file == null ? 'unknown_or_expired' : 'file_deleted',
          'latencyMs': stopwatch.elapsedMilliseconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return _notFound(token);
    }

    // Read + serve, wrapped to close a TOCTOU window: the registry's sweep
    // timer or a web `releaseCapture` can delete the file between the
    // resolve()/exists() check above and the read below. Without this guard
    // the exception propagates into the native WebView layer untracked;
    // here we treat it as a logged miss instead.
    try {
      // Size guard before loading into memory — WebResourceResponse only
      // accepts Uint8List (no streaming API on Android). Capture-time
      // enforcement in CaptureImageHandler should mean we never reach this,
      // so it's defense-in-depth; we return a distinct 413 (not 404) so the
      // cause is observable and the web could differentiate if needed.
      final fileLength = await file.length();
      if (fileLength > CaptureRegistry.maxCaptureSizeBytes) {
        stopwatch.stop();
        MonitoringServiceHelper.logWarning(
          'capture_serve_too_large',
          {
            'token': token,
            'fileSizeBytes': fileLength,
            'maxAllowed': CaptureRegistry.maxCaptureSizeBytes,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        return _tooLarge(token);
      }

      final bytes = await file.readAsBytes();
      stopwatch.stop();

      MonitoringServiceHelper.logDebug(
        'capture_serve_hit',
        {
          'token': token,
          'fileSizeBytes': bytes.length,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return WebResourceResponse(
        contentType: 'image/jpeg',
        statusCode: 200,
        reasonPhrase: 'OK',
        headers: {
          ..._corsHeaders,
          'Cache-Control': 'no-store',
          'Content-Length': '${bytes.length}',
          'X-Capture-Token': token,
        },
        data: bytes,
      );
    } catch (e) {
      stopwatch.stop();
      // A thrown read is an error condition (I/O failure, or the TOCTOU
      // delete race) — distinct from a clean not-found, so log at error
      // level under its own event rather than as a benign miss.
      MonitoringServiceHelper.logError(
        'capture_serve_error',
        {
          'token': token,
          'reason': 'read_failed',
          'error': e.toString(),
          'latencyMs': stopwatch.elapsedMilliseconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return _notFound(token);
    }
  }

  /// CORS headers included on every response. Permissive enough to
  /// satisfy both simple requests and preflight checks on Android
  /// WebView (where we cannot intercept OPTIONS separately).
  ///
  /// **API-level note:** The wildcard `*` in `Allow-Headers` is
  /// supported from Chromium 87+ (Android API 30+). Devices on
  /// API 28–29 with older system WebView builds may silently ignore
  /// the wildcard. This is acceptable here because the asset-loader
  /// domain is same-origin (`appassets.androidplatform.net`) and the
  /// web's `fetch()` for captures uses no custom request headers.
  /// If custom headers are added later, enumerate them explicitly.
  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  };

  /// Returns a 404 response with CORS headers.
  static WebResourceResponse _notFound(String token) {
    return WebResourceResponse(
      statusCode: 404,
      reasonPhrase: 'Not Found',
      headers: _corsHeaders,
      data: null,
    );
  }

  /// Returns a 413 (Payload Too Large) response — distinct from the 404 a
  /// missing/expired token returns, so the web can tell "image too large,
  /// retake" apart from "token gone".
  static WebResourceResponse _tooLarge(String token) {
    return WebResourceResponse(
      statusCode: 413,
      reasonPhrase: 'Payload Too Large',
      headers: _corsHeaders,
      data: null,
    );
  }
}
