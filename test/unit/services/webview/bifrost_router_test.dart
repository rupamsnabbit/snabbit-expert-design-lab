import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/services/webview/bifrost_router.dart';
import 'package:snabbit_runner/services/webview/origin_gate.dart';

import 'fake_webview_channel.dart';

const _origin = 'https://coins.snabbit.com';

class _RecordingHandler implements BifrostHandler {
  _RecordingHandler({
    required this.actionName,
    required this.pattern,
    this.throwOnHandle = false,
    this.result = const BifrostResult.empty(),
  });

  @override
  final String actionName;
  @override
  final BifrostPattern pattern;
  final bool throwOnHandle;
  final BifrostResult result;

  final List<Map<String, dynamic>> receivedData = [];
  int handleCount = 0;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    handleCount++;
    receivedData.add(data);
    if (throwOnHandle) throw StateError('boom');
    return result;
  }
}

BifrostRouter _makeRouter({
  required FakeWebViewChannel channel,
  required Map<String, BifrostHandler> handlers,
  String allowedOrigin = _origin,
}) {
  return BifrostRouter(
    channel: channel,
    originGate: OriginGate(initialUrl: '$allowedOrigin/'),
    handlers: handlers,
    logger: const NullBifrostLogger(),
  );
}

void main() {
  group('BifrostRouter.onInbound', () {
    test('dispatches a valid FAF message to the matching handler', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/page';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"openUrl","data":{"url":"https://x"}}',
      );

      expect(handler.handleCount, 1);
      expect(handler.receivedData.single, {'url': 'https://x'});
    });

    test('drops messages with malformed JSON', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound('{not json');

      expect(handler.handleCount, 0);
    });

    test('blocks messages from non-allowlisted origin', () async {
      final channel = FakeWebViewChannel()
        ..currentUrl = 'https://attacker.com/x';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"openUrl","data":{"url":"https://x"}}',
      );

      expect(handler.handleCount, 0);
    });

    test('blocks the crafted subdomain attack', () async {
      final channel = FakeWebViewChannel()
        ..currentUrl = 'https://coins.snabbit.com.attacker.com/steal';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"openUrl","data":{"url":"https://x"}}',
      );

      expect(handler.handleCount, 0);
    });

    test('fails closed when current URL is null', () async {
      final channel = FakeWebViewChannel(); // currentUrl not set
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"openUrl","data":{"url":"https://x"}}',
      );

      expect(handler.handleCount, 0);
    });

    test('drops UNKNOWN_ACTION FAF events without sending a response',
        () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final router = _makeRouter(channel: channel, handlers: const {});

      await router.onInbound(
        '{"event":"thisActionDoesNotExist","data":{}}',
      );

      expect(channel.pushedEvents, isEmpty);
      expect(channel.sentResponses, isEmpty);
    });

    test('UNKNOWN_ACTION with a requestId gets an UNKNOWN_ACTION error '
        'response (so the promise rejects fast)', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final router = _makeRouter(channel: channel, handlers: const {});

      await router.onInbound(
        '{"event":"thisActionDoesNotExist","data":{},"requestId":"r99"}',
      );

      expect(channel.sentResponses, hasLength(1));
      final resp = channel.sentResponses.single;
      expect(resp.event, 'thisActionDoesNotExist');
      expect(resp.requestId, 'r99');
      expect(resp.error?.code, BifrostErrorCodes.unknownAction);
    });

    test('rejects FAF handler when a requestId is supplied (no response)',
        () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"openUrl","data":{"url":"https://x"},"requestId":"r1"}',
      );

      expect(handler.handleCount, 0);
      // Web sent a requestId — give it a PATTERN_MISMATCH error back so the
      // promise rejects instead of timing out.
      expect(channel.sentResponses, hasLength(1));
      expect(
        channel.sentResponses.single.error?.code,
        BifrostErrorCodes.patternMismatch,
      );
    });

    test('rejects RPC handler when a requestId is missing', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'navigate',
        pattern: BifrostPattern.rpc,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound('{"event":"navigate","data":{}}');

      expect(handler.handleCount, 0);
      // No requestId → no response to send (web wasn't expecting one).
      expect(channel.sentResponses, isEmpty);
    });

    test('swallows handler exceptions without breaking the router', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
        throwOnHandle: true,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound('{"event":"openUrl","data":{}}');

      expect(handler.handleCount, 1); // did run, but threw
    });
  });

  group('BifrostRouter RPC response', () {
    test('sends success response echoing requestId and data', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'requestInitData',
        pattern: BifrostPattern.rpc,
        result: const BifrostResult(data: {'token': 'abc'}),
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"requestInitData","data":{},"requestId":"r42"}',
      );

      expect(channel.sentResponses, hasLength(1));
      final resp = channel.sentResponses.single;
      expect(resp.event, 'requestInitData');
      expect(resp.requestId, 'r42');
      expect(resp.data, {'token': 'abc'});
      expect(resp.error, isNull);
    });

    test('sends error response when handler returns a BifrostError', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'requestInitData',
        pattern: BifrostPattern.rpc,
        result: const BifrostResult(
          error: BifrostError(
            code: 'TOKEN_UNAVAILABLE',
            message: 'no token',
          ),
        ),
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"requestInitData","data":{},"requestId":"r1"}',
      );

      expect(channel.sentResponses.single.error?.code, 'TOKEN_UNAVAILABLE');
      expect(channel.sentResponses.single.data, isNull);
    });

    test('sends INTERNAL_ERROR response when the handler throws', () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'requestInitData',
        pattern: BifrostPattern.rpc,
        throwOnHandle: true,
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound(
        '{"event":"requestInitData","data":{},"requestId":"r1"}',
      );

      expect(channel.sentResponses, hasLength(1));
      final resp = channel.sentResponses.single;
      expect(resp.error?.code, BifrostErrorCodes.internalError);
      expect(resp.requestId, 'r1');
    });

    test('FAF handler does not send a response even when result has data',
        () async {
      final channel = FakeWebViewChannel()..currentUrl = '$_origin/';
      final handler = _RecordingHandler(
        actionName: 'openUrl',
        pattern: BifrostPattern.fireAndForget,
        result: const BifrostResult(data: {'something': 'ignored'}),
      );
      final router = _makeRouter(
        channel: channel,
        handlers: {handler.actionName: handler},
      );

      await router.onInbound('{"event":"openUrl","data":{}}');

      expect(channel.sentResponses, isEmpty);
    });
  });
}
