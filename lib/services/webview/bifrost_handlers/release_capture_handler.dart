import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Bifrost fire-and-forget handler for the `releaseCapture` event.
///
/// The web calls this after it no longer needs a previously captured
/// image (e.g. after upload or page transition). Deletes the backing
/// file from disk and removes the token from [CaptureRegistry].
///
/// Belt-and-suspenders with [CaptureRegistry]'s TTL sweep — even if
/// the web forgets to call this, files are cleaned up automatically.
class ReleaseCaptureHandler implements BifrostHandler {
  @override
  String get actionName => WebViewConstants.eventReleaseCapture;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final raw = data['token'];
    final token = raw is String ? raw : null;
    if (token != null && token.isNotEmpty) {
      await CaptureRegistry.instance.evict(token);
      MonitoringServiceHelper.logInfo(
        'capture_released',
        {
          'token': token,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
    return const BifrostResult.empty();
  }
}
