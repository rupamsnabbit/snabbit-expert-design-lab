import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';

/// Whether a handler expects a request/response RPC exchange or is a pure
/// fire-and-forget notification. See proposal §2.2.
enum BifrostPattern { fireAndForget, rpc }

/// Result returned by a handler. `data` is the success payload; `error` is
/// a structured failure. Either or both may be null. The router uses the
/// handler's [BifrostPattern] to decide whether to send a response.
class BifrostResult {
  const BifrostResult({this.data, this.error});

  /// Shortcut for a fire-and-forget handler that has nothing to report.
  const BifrostResult.empty()
      : data = null,
        error = null;

  final Map<String, dynamic>? data;
  final BifrostError? error;
}

/// Base contract for every inbound bifrost handler. Implementations are pure
/// functions from `data → result`; the router handles envelope concerns
/// (parsing, origin gating, response dispatch).
abstract class BifrostHandler {
  String get actionName;
  BifrostPattern get pattern;

  Future<BifrostResult> handle(Map<String, dynamic> data);
}
