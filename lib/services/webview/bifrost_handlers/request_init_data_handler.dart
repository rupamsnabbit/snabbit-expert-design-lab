import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// RPC handler: web calls `requestInitData()` with a `requestId`; the router
/// sends back a response with the built init-data payload (or an error).
///
/// Legacy web that doesn't pass a `requestId` is rejected by the router's
/// pattern check and silently dropped — they still receive init data via
/// the legacy push on `onPageCommitVisible` (deleted in slice 1b).
class RequestInitDataHandler implements BifrostHandler {
  RequestInitDataHandler({required this.buildInitData});

  /// Builds the init-data result. Injected so the handler stays decoupled
  /// from secure storage, device info, and the Provider tree.
  ///
  /// Receives the inbound request data so it can read fields the web opts
  /// into, e.g. `capabilities: string[]` for capability negotiation (§2.8).
  final Future<BifrostResult> Function(Map<String, dynamic> data) buildInitData;

  @override
  String get actionName => WebViewConstants.eventRequestInitData;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) => buildInitData(data);
}
