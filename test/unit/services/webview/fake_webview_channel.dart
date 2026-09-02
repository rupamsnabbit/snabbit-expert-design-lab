import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/webview_channel.dart';

class PushedEvent {
  PushedEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic>? data;
}

class SentResponse {
  SentResponse({
    required this.event,
    required this.requestId,
    this.data,
    this.error,
  });
  final String event;
  final String requestId;
  final Map<String, dynamic>? data;
  final BifrostError? error;
}

/// In-memory WebViewChannel used by Dart unit and widget tests.
/// Records every call so tests can assert the bifrost-facing behaviour of
/// whatever code is under test.
class FakeWebViewChannel implements WebViewChannel {
  final List<PushedEvent> pushedEvents = [];
  final List<SentResponse> sentResponses = [];
  final Map<String, InboundHandler> inboundHandlers = {};
  String? currentUrl;

  @override
  Future<String?> getCurrentUrl() async => currentUrl;

  @override
  Future<void> pushEvent(String event, Map<String, dynamic>? data) async {
    pushedEvents.add(PushedEvent(event, data));
  }

  @override
  Future<void> sendResponse({
    required String event,
    required String requestId,
    Map<String, dynamic>? data,
    BifrostError? error,
  }) async {
    sentResponses.add(
      SentResponse(
        event: event,
        requestId: requestId,
        data: data,
        error: error,
      ),
    );
  }

  @override
  void registerInboundHandler(String handlerName, InboundHandler handler) {
    inboundHandlers[handlerName] = handler;
  }
}
