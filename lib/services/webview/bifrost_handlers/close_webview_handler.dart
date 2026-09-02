import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

class CloseWebViewHandler implements BifrostHandler {
  CloseWebViewHandler({required this.onClose});

  final void Function(Map<String, dynamic>? result) onClose;

  @override
  String get actionName => WebViewConstants.eventCloseWebView;

  @override
  BifrostPattern get pattern => BifrostPattern.fireAndForget;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    // Always pass a map when the web calls closeWebView (even `{}`) so native
    // can distinguish completion from manual back, which pops with null.
    onClose(data);
    return const BifrostResult.empty();
  }
}
