import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Callback the handler invokes to actually push the Perfios page. Returns
/// the map the page popped with, or null when the page was dismissed without
/// producing a result. Injectable so tests can stub the push without needing
/// a live Navigator.
///
/// The map uses an internal `__error` sentinel to tunnel structured failures
/// out of the page (which can only `pop` a single Object?). Success payloads
/// never carry that sentinel.
typedef PerfiosAadhaarOpener = Future<Map<String, dynamic>?> Function();

/// RPC handler for [WebViewConstants.eventOpenPerfiosAadhaar].
///
/// Success `data`:
///   {
///     "demographics": { "name": ..., "dob": ..., "gender": ...,
///                       "address": ..., "maskedAadhaarNumber": ... },
///     "rawPerfiosJson": "the full onShutdown string, as-is"
///   }
///
/// Failures surface as structured [BifrostError]s — never exceptions.
class OpenPerfiosAadhaarHandler implements BifrostHandler {
  OpenPerfiosAadhaarHandler({required this.openPerfios});

  final PerfiosAadhaarOpener openPerfios;

  bool _inFlight = false;

  @override
  String get actionName => WebViewConstants.eventOpenPerfiosAadhaar;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    if (_inFlight) {
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.perfiosInProgress,
          message: 'A Perfios flow is already in progress',
        ),
      );
    }
    _inFlight = true;
    try {
      final result = await openPerfios();
      if (result == null) {
        return const BifrostResult(
          error: BifrostError(
            code: BifrostErrorCodes.userCancelled,
            message: 'Perfios flow closed without a result',
            retryable: true,
          ),
        );
      }
      if (result['__error'] == true) {
        return BifrostResult(
          error: BifrostError(
            code:
                result['code'] as String? ?? BifrostErrorCodes.internalError,
            message: result['message'] as String? ?? 'Perfios flow failed',
            retryable: true,
          ),
        );
      }
      return BifrostResult(data: Map<String, dynamic>.from(result));
    } catch (e) {
      return BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.internalError,
          message: 'Failed to open Perfios: $e',
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}
