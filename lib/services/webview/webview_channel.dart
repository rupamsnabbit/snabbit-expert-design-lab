import 'dart:async';

import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';

typedef InboundHandler = Future<void> Function(List<dynamic> args);

/// Seam between bifrost code and the InAppWebView API.
/// Handlers, routers, and the page widget depend on this, not on
/// `InAppWebViewController` directly, so the bifrost is testable in isolation.
abstract class WebViewChannel {
  Future<String?> getCurrentUrl();

  /// Push a fire-and-forget event from Flutter to the web page.
  /// Data is omitted from the payload when null.
  Future<void> pushEvent(String event, Map<String, dynamic>? data);

  /// Send an RPC response to a previously-received request. [requestId]
  /// echoes the inbound `requestId` so web can resolve the matching promise.
  /// Either [data], [error], or both may be set; both being null produces
  /// an empty-success response.
  Future<void> sendResponse({
    required String event,
    required String requestId,
    Map<String, dynamic>? data,
    BifrostError? error,
  });

  /// Register an inbound handler for messages posted from the web page.
  void registerInboundHandler(String handlerName, InboundHandler handler);
}
