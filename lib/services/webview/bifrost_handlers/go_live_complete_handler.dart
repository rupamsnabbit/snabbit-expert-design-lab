import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Handles the web's `goLiveComplete` event, fired when the runner finishes
/// going live inside the training hub webview.
///
/// Go-live changes the runner's status to ACTIVE on the backend only — the
/// app's local user object is stale at this point. The web used to call
/// `closeWebView` here, which (plain pop) revealed whatever screen the hub was
/// launched over (SelectLanguageV2) instead of PartnerHome. This dedicated
/// event lets native re-fetch `runners/me` and route by the runner's current
/// state; the destination is decided natively, so no payload is required.
///
/// Web clients feature-detect support via `NativeCapabilities` (this action is
/// listed there) and fall back to `closeWebView` on builds that don't advertise
/// it, so older apps are unaffected.
class GoLiveCompleteHandler implements BifrostHandler {
  GoLiveCompleteHandler({required this.onGoLiveComplete});

  final void Function() onGoLiveComplete;

  @override
  String get actionName => WebViewConstants.eventGoLiveComplete;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    onGoLiveComplete();
    return const BifrostResult.empty();
  }
}
