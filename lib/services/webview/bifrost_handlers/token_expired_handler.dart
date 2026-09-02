import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// RPC handler for `tokenExpired`.
///
/// Web calls this on a 401 from any API. The response `{closing: true}`
/// tells web to stop whatever it was doing — native will dismiss the
/// webview and drop the runner back to the native Home screen.
///
/// Phase 1 scope: close-on-expiry only. Phase 2 will extend this action
/// with a silent-refresh flow (`{closing: false, newToken: '...'}`) and
/// web will retry the failed request instead of bailing.
///
/// **Close is deferred** by [closeDelay]. The router delivers the RPC
/// response by running JavaScript inside the webview; if we popped the
/// webview synchronously the JS context would be torn down before web's
/// promise resolves. A short delay (default 100ms) is enough for the
/// response to reach web even on slow devices.
class TokenExpiredHandler implements BifrostHandler {
  TokenExpiredHandler({
    required this.onClose,
    this.closeDelay = const Duration(milliseconds: 100),
  });

  final void Function() onClose;
  final Duration closeDelay;

  @override
  String get actionName => WebViewConstants.eventTokenExpired;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    if (kDebugMode) {
      debugPrint(
        '[TokenExpiredHandler] received tokenExpired — '
        'closing webview in ${closeDelay.inMilliseconds}ms',
      );
    }
    unawaited(Future.delayed(closeDelay, () {
      if (kDebugMode) {
        debugPrint('[TokenExpiredHandler] firing onClose()');
      }
      onClose();
    }));
    return const BifrostResult(data: {'closing': true});
  }
}
