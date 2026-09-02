import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_logger.dart';
import 'package:snabbit_runner/services/webview/origin_gate.dart';
import 'package:snabbit_runner/services/webview/webview_channel.dart';

/// Routes inbound bifrost messages. See proposal §4.3.
class BifrostRouter {
  BifrostRouter({
    required this.channel,
    required this.originGate,
    required Map<String, BifrostHandler> handlers,
    this.logger = const MonitoringBifrostLogger(),
  }) : _handlers = handlers;

  final WebViewChannel channel;
  final OriginGate originGate;
  final BifrostLogger logger;
  final Map<String, BifrostHandler> _handlers;

  /// Entry point for raw messages received from the web page.
  Future<void> onInbound(String rawJson) async {
    final stopwatch = Stopwatch()..start();
    final env = BifrostEnvelope.tryParse(rawJson);
    if (env == null) {
      logger.logError('bifrost_parse_failed', {'raw': rawJson});
      return;
    }

    final currentUrl = await channel.getCurrentUrl();
    if (!originGate.isAllowed(currentUrl)) {
      logger.logError('bifrost_origin_blocked', {
        'event': env.event,
        'url': _maskOrigin(currentUrl),
      });
      return;
    }

    final handler = _handlers[env.event];
    if (handler == null) {
      logger.logError('bifrost_unknown_action', {
        'event': env.event,
      });
      // If the web used RPC, respond with an error so the promise rejects
      // immediately instead of hanging until its timeout.
      if (env.requestId != null) {
        await channel.sendResponse(
          event: env.event,
          requestId: env.requestId!,
          error: BifrostError(
            code: BifrostErrorCodes.unknownAction,
            message: 'No handler registered for "${env.event}"',
          ),
        );
      }
      return;
    }

    if (!_patternMatches(handler.pattern, env.requestId != null)) {
      logger.logError('bifrost_pattern_mismatch', {
        'event': env.event,
        'hasRequestId': env.requestId != null,
        'expected': handler.pattern.name,
      });
      // Same fast-fail: if the web sent a requestId expecting a response,
      // give it one even though the pattern is wrong.
      if (env.requestId != null) {
        await channel.sendResponse(
          event: env.event,
          requestId: env.requestId!,
          error: BifrostError(
            code: BifrostErrorCodes.patternMismatch,
            message: 'Handler for "${env.event}" does not accept '
                '${handler.pattern.name} requests',
          ),
        );
      }
      return;
    }

    var ok = true;
    try {
      final result = await handler.handle(env.data);
      if (handler.pattern == BifrostPattern.rpc) {
        await channel.sendResponse(
          event: env.event,
          requestId: env.requestId!,
          data: result.data,
          error: result.error,
        );
      }
    } catch (e, st) {
      ok = false;
      logger.logError('bifrost_handler_threw', {
        'event': env.event,
        'error': e.toString(),
        'stack': st.toString(),
      });
      if (handler.pattern == BifrostPattern.rpc && env.requestId != null) {
        await channel.sendResponse(
          event: env.event,
          requestId: env.requestId!,
          error: BifrostError(
            code: BifrostErrorCodes.internalError,
            message: e.toString(),
          ),
        );
      }
    } finally {
      stopwatch.stop();
      logger.logInfo('bifrost_handler_done', {
        'event': env.event,
        'durationMs': stopwatch.elapsedMilliseconds,
        'ok': ok,
      });
    }
  }

  /// FAF expects no requestId; RPC requires one.
  bool _patternMatches(BifrostPattern pattern, bool hasRequestId) {
    switch (pattern) {
      case BifrostPattern.fireAndForget:
        return !hasRequestId;
      case BifrostPattern.rpc:
        return hasRequestId;
    }
  }

  /// Avoid logging full URLs (may contain tokens, query strings, PII).
  String _maskOrigin(String? url) {
    if (url == null || url.isEmpty) return '<null>';
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return '<unparseable>';
      return '${uri.scheme}://${uri.host}';
    } catch (_) {
      return '<unparseable>';
    }
  }
}
