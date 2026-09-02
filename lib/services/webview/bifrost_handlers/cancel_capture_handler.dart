import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/capture_image_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Bifrost fire-and-forget handler for the `cancelCapture` event.
///
/// The web calls this to programmatically abort an in-flight image
/// capture (e.g. navigation away from the upload screen, timeout, or
/// user tapping a web-side cancel button).
///
/// Delegates to [CaptureImageHandler.cancel], which pops the native
/// camera page. The pending `captureImage` RPC then resolves with
/// `USER_CANCELLED` — the web receives cancellation through that
/// channel, not through this handler.
class CancelCaptureHandler implements BifrostHandler {
  CancelCaptureHandler({required CaptureImageHandler captureHandler})
      : _captureHandler = captureHandler;

  final CaptureImageHandler _captureHandler;

  @override
  String get actionName => WebViewConstants.eventCancelCapture;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    if (!_captureHandler.isCaptureInFlight) {
      MonitoringServiceHelper.logInfo(
        'cancel_capture_ignored',
        {
          'reason': 'no_capture_in_flight',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return const BifrostResult.empty();
    }

    _captureHandler.cancel();
    return const BifrostResult.empty();
  }
}
