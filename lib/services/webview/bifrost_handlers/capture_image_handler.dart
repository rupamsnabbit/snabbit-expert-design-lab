import 'dart:io';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Callback that opens the selfie capture page and returns the captured
/// [File], or `null` if the user cancels.
typedef ImageCapturer = Future<File?> Function();

/// Callback that builds a WebViewAssetLoader URL for a capture token.
typedef CaptureUrlBuilder = String Function(String token);

/// Abstraction over `permission_handler` so tests can inject a fake.
/// Returns the [PermissionStatus] after requesting the given permission.
typedef PermissionRequester = Future<PermissionStatus> Function(
  Permission permission,
);

/// Callback that dismisses the native capture UI (pops the camera page).
/// Called by [CaptureImageHandler.cancel] when the web sends `cancelCapture`.
typedef CaptureDismisser = void Function();

/// Called when camera permission is denied. Gives the UI layer a chance to
/// show a bottom sheet guiding the user to app settings. Returns `true` if
/// the user resolved the permission (came back from settings with camera
/// granted), `false` to give up and return `PERMISSION_DENIED` to the web.
typedef PermissionDeniedHandler = Future<bool> Function(
  PermissionStatus status,
);

/// Abstraction over [FirebaseCrashlytics.instance.recordError] so tests
/// can inject a no-op without initialising Firebase.
typedef ErrorReporter = Future<void> Function(
  dynamic exception,
  StackTrace? stack, {
  String? reason,
  bool fatal,
});

/// Bifrost RPC handler for the `captureImage` event.
///
/// Opens the native selfie camera, waits for the user to capture (or
/// cancel), then responds with a `WebViewAssetLoader` URL that the
/// WebView can fetch like any HTTP resource. **No image bytes cross
/// the JS bridge** — only the URL string.
///
/// Includes a reentrancy guard: if a capture is already in flight,
/// subsequent requests receive `CAPTURE_IN_PROGRESS` immediately.
///
/// Supports programmatic cancellation via [cancel], used by the
/// `cancelCapture` fire-and-forget handler.
class CaptureImageHandler implements BifrostHandler {
  CaptureImageHandler({
    required ImageCapturer captureCallback,
    required CaptureUrlBuilder urlBuilder,
    CaptureDismisser? dismissCapture,
    PermissionRequester? permissionRequester,
    PermissionDeniedHandler? onPermissionDenied,
    ErrorReporter? errorReporter,
  })  : _capture = captureCallback,
        _urlBuilder = urlBuilder,
        _dismissCapture = dismissCapture,
        _requestPermission = permissionRequester ?? _defaultRequest,
        _onPermissionDenied = onPermissionDenied,
        _reportError = errorReporter ?? _defaultReporter;

  final ImageCapturer _capture;
  final CaptureUrlBuilder _urlBuilder;
  final CaptureDismisser? _dismissCapture;
  final PermissionRequester _requestPermission;
  final PermissionDeniedHandler? _onPermissionDenied;
  final ErrorReporter _reportError;

  static Future<PermissionStatus> _defaultRequest(
    Permission permission,
  ) async =>
      permission.request();

  static Future<void> _defaultReporter(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) =>
      FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason ?? '',
        fatal: fatal,
      );

  /// Monotonic counter combined with the millisecond timestamp to
  /// guarantee unique tokens even if two captures happen within the
  /// same clock tick (Android's Dart clock has ~1 ms resolution).
  static int _tokenCounter = 0;

  /// CSPRNG for the random component of capture tokens.
  static final Random _secureRandom = Random.secure();

  /// Builds an opaque capture token: `<timestamp>_<counter>_<random>`.
  ///
  /// The timestamp + counter guarantee uniqueness; the 8-byte
  /// [Random.secure] suffix makes the token **unguessable**. Without it,
  /// `<timestamp>_<counter>` is predictable, and any content in the
  /// WebView could fabricate a valid `/captures/<token>.jpg` URL to read
  /// another in-flight capture (a mild IDOR). The suffix closes that.
  static String _generateToken() {
    final random = List<int>.generate(8, (_) => _secureRandom.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${DateTime.now().millisecondsSinceEpoch}_${_tokenCounter++}_$random';
  }

  /// Prevents concurrent capture sessions. A second request while the
  /// camera is open would stack two SelfieCapturePage instances.
  bool _captureInFlight = false;

  /// Set by [cancel] so [handle] can resolve as `USER_CANCELLED` when the
  /// web aborts while the **permission sheet** is open — before the camera
  /// page, where a null [_capture] result already signals cancellation.
  /// Without this, a mid-sheet cancel would fall through to
  /// `PERMISSION_DENIED` (wrong code) or block until the sheet times out.
  bool _cancelRequested = false;

  /// Whether a capture session is currently in progress.
  bool get isCaptureInFlight => _captureInFlight;

  /// Programmatically cancels an in-flight capture by dismissing the
  /// native camera UI. The awaiting [_capture] call returns `null`,
  /// which [handle] already treats as `USER_CANCELLED`.
  ///
  /// No-op when no capture is in flight or no [CaptureDismisser] was
  /// provided.
  void cancel() {
    if (!_captureInFlight) return;
    _cancelRequested = true;
    MixpanelSetup.logEvent(
      TrackingEvents.captureImageCancelRequested,
      {},
    );
    _dismissCapture?.call();
  }

  @override
  String get actionName => WebViewConstants.eventCaptureImage;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    if (_captureInFlight) {
      MixpanelSetup.logEvent(
        TrackingEvents.captureImageBlocked,
        {},
      );
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.captureInProgress,
          message: 'A capture is already in progress',
        ),
      );
    }

    _captureInFlight = true;
    _cancelRequested = false;
    final stopwatch = Stopwatch()..start();

    try {
      MixpanelSetup.logEvent(
        TrackingEvents.captureImageStarted,
        {},
      );

      // ── Camera permission gate ──
      var permStatus = await _requestPermission(Permission.camera);
      if (!_isPermissionGranted(permStatus)) {
        // Give the UI a chance to show a bottom sheet and guide the
        // user to settings. If the callback resolves the permission
        // we continue with the capture; otherwise return the error.
        if (_onPermissionDenied != null) {
          MixpanelSetup.logEvent(
            TrackingEvents.captureImagePermissionShowingUi,
            {'status': permStatus.name},
          );
          final resolved = await _onPermissionDenied(permStatus);
          if (resolved) {
            // Re-check after the user returned from settings.
            permStatus = await _requestPermission(Permission.camera);
          }
        }

        // The web aborted (`cancelCapture`) while the permission sheet was
        // open — the sheet dismisses itself and we resolve as cancellation
        // rather than letting it fall through to PERMISSION_DENIED.
        if (_cancelRequested) {
          stopwatch.stop();
          MixpanelSetup.logEvent(
            TrackingEvents.captureImageCancelled,
            {'durationMs': stopwatch.elapsedMilliseconds},
          );
          return const BifrostResult(
            error: BifrostError(
              code: BifrostErrorCodes.userCancelled,
              message: 'User cancelled image capture',
            ),
          );
        }

        if (!_isPermissionGranted(permStatus)) {
          stopwatch.stop();
          MonitoringServiceHelper.logWarning(
            'capture_image_permission_denied',
            {
              'permissionStatus': permStatus.name,
              'durationMs': stopwatch.elapsedMilliseconds,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          MixpanelSetup.logEvent(
            TrackingEvents.captureImagePermissionDenied,
            {
              'status': permStatus.name,
              'durationMs': stopwatch.elapsedMilliseconds,
            },
          );
          return BifrostResult(
            error: BifrostError(
              code: BifrostErrorCodes.permissionDenied,
              message: 'Camera permission not granted',
              details: {
                'permission': 'camera',
                'status': permStatus.name,
              },
            ),
          );
        }
      }

      final file = await _capture();
      stopwatch.stop();

      if (file == null) {
        MixpanelSetup.logEvent(
          TrackingEvents.captureImageCancelled,
          {'durationMs': stopwatch.elapsedMilliseconds},
        );
        return const BifrostResult(
          error: BifrostError(
            code: BifrostErrorCodes.userCancelled,
            message: 'User cancelled image capture',
          ),
        );
      }

      // Copy the captured image to a dedicated captures directory and
      // register it with a unique token for the WebViewAssetLoader.
      final captureDir = await _getCaptureDir();
      final token = _generateToken();
      final target = File('${captureDir.path}/$token.jpg');
      await file.copy(target.path);

      // Enforce the servable size cap HERE, before registering and
      // returning success. Otherwise the RPC would hand back a valid-looking
      // {url, token}, and the oversize image would only fail later at serve
      // time — which the web sees as a silent broken image with no way to
      // prompt a retake. Failing the RPC with FILE_TOO_LARGE is the clean
      // signal. (Debug telemetry → Coralogix, not a Mixpanel event.)
      final fileSize = await target.length();
      if (fileSize > CaptureRegistry.maxCaptureSizeBytes) {
        try {
          if (await target.exists()) await target.delete();
        } catch (_) {
          // Best-effort cleanup; the TTL/startup sweep is the backstop.
        }
        MonitoringServiceHelper.logWarning(
          'capture_image_too_large',
          {
            'fileSizeBytes': fileSize,
            'maxBytes': CaptureRegistry.maxCaptureSizeBytes,
            'durationMs': stopwatch.elapsedMilliseconds,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        return BifrostResult(
          error: BifrostError(
            code: BifrostErrorCodes.fileTooLarge,
            message: 'Captured image is too large',
            details: {
              'fileSizeBytes': fileSize,
              'maxBytes': CaptureRegistry.maxCaptureSizeBytes,
            },
          ),
        );
      }

      CaptureRegistry.instance.register(target, token: token);
      final url = _urlBuilder(token);

      MixpanelSetup.logEvent(
        TrackingEvents.captureImageCompleted,
        {
          'fileSizeBytes': fileSize,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      return BifrostResult(data: {'url': url, 'token': token});
    } catch (e, stack) {
      stopwatch.stop();
      MonitoringServiceHelper.logError(
        'capture_image_error',
        {
          'error': e.toString(),
          'stackTrace': stack.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _reportError(
        e,
        stack,
        reason: 'captureImage handler failed',
        fatal: false,
      );
      return BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.internalError,
          message: 'Image capture failed unexpectedly',
        ),
      );
    } finally {
      _captureInFlight = false;
    }
  }

  static bool _isPermissionGranted(PermissionStatus status) =>
      status == PermissionStatus.granted ||
      status == PermissionStatus.limited ||
      status == PermissionStatus.provisional;

  /// Returns (and creates if needed) the dedicated captures directory
  /// inside the app's temp storage.
  static Future<Directory> _getCaptureDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/captures');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
