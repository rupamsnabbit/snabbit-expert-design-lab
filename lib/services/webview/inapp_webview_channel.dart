import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/webview_channel.dart';

class InAppWebViewChannel implements WebViewChannel {
  InAppWebViewChannel(this._controller);

  final InAppWebViewController _controller;

  @override
  Future<String?> getCurrentUrl() async {
    final url = await _controller.getUrl();
    return url?.toString();
  }

  @override
  Future<void> pushEvent(String event, Map<String, dynamic>? data) async {
    final envelope = BifrostEnvelope(
      event: event,
      data: data ?? const {},
    );
    await _postEnvelope(envelope);
  }

  @override
  Future<void> sendResponse({
    required String event,
    required String requestId,
    Map<String, dynamic>? data,
    BifrostError? error,
  }) async {
    final envelope = BifrostEnvelope(
      event: event,
      data: data ?? const {},
      requestId: requestId,
      error: error,
    );
    await _postEnvelope(envelope);
  }

  @override
  void registerInboundHandler(String handlerName, InboundHandler handler) {
    _controller.addJavaScriptHandler(
      handlerName: handlerName,
      callback: handler,
    );
  }

  Future<void> _postEnvelope(BifrostEnvelope envelope) async {
    final payload = jsonEncode(envelope.toJson());
    final result = await _controller.callAsyncJavaScript(
      // Prefer the new unified receiver; fall back to the legacy one so old
      // web deploys keep working during the transition (removed in slice 1b).
      functionBody: '''
        var msg = JSON.parse(payload);
        if (window.onFlutterMessage) {
          window.onFlutterMessage(msg);
        } else if (window.onFlutterEvent) {
          window.onFlutterEvent(msg);
        }
      ''',
      arguments: {'payload': payload},
    );
    if (result?.error != null) {
      MonitoringServiceHelper.logError('webview_post_event_js_error', {
        'event': envelope.event,
        'error': result!.error.toString(),
      });
    }
  }
}
