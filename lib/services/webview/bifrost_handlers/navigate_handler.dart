import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/route_registry.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// RPC handler for `navigate`. Web sends a `snabbit://…` URI; we resolve it
/// to a Flutter named route and push it onto the navigator stack.
///
/// Failure modes (all returned as structured `BifrostError`s, not exceptions):
/// - `INVALID_ARGS` — missing `uri`, or per-route args validator rejected.
/// - `UNKNOWN_ROUTE` — URI not in the registry.
/// - `DEBOUNCED` — called again within the debounce window.
class NavigateHandler implements BifrostHandler {
  NavigateHandler({
    required this.registry,
    required this.navigator,
    this.debounce = const Duration(milliseconds: 300),
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  static const String _closeBehaviorReplace = 'replace';

  final RouteRegistry registry;
  final AppNavigator navigator;
  final Duration debounce;
  final DateTime Function() _now;

  DateTime? _lastNavAt;

  @override
  String get actionName => WebViewConstants.eventNavigate;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final uri = data['uri'];
    if (uri is! String || uri.isEmpty) {
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.invalidArgs,
          message: "Missing or invalid 'uri'",
        ),
      );
    }

    // The registry is keyed on query-less URIs (e.g.
    // 'snabbit://onboarding_steps'). The web may append query params
    // (e.g. '?module_id=1&module_name=id-verification'); strip them for the
    // exact-match lookup and fold them into the args the opener receives.
    // Query-less URIs (every other route) are unaffected: lookupUri == uri
    // and queryParams is empty.
    final qIndex = uri.indexOf('?');
    final lookupUri = qIndex == -1 ? uri : uri.substring(0, qIndex);
    final queryParams = qIndex == -1
        ? const <String, String>{}
        : Uri.splitQueryString(uri.substring(qIndex + 1));

    final entry = registry.find(lookupUri);
    if (entry == null) {
      return BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.unknownRoute,
          message: 'No route registered for $uri',
          details: {'uri': uri},
        ),
      );
    }

    final now = _now();
    if (_lastNavAt != null && now.difference(_lastNavAt!) < debounce) {
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.debounced,
          message: 'Ignored navigation within debounce window',
        ),
      );
    }

    final rawArgs = data['data'];
    // Query params first, explicit data map second so an explicit `data`
    // value wins on key conflict.
    final Map<String, dynamic> argsMap = {
      ...queryParams,
      if (rawArgs is Map<String, dynamic>) ...rawArgs,
    };

    Object? args;
    if (entry.argsValidator != null) {
      final result = entry.argsValidator!(argsMap);
      if (result.error != null) {
        return BifrostResult(error: result.error);
      }
      args = result.args;
    } else {
      args = argsMap.isEmpty ? null : argsMap;
    }

    // Commit the debounce timestamp only once we're actually about to
    // navigate — earlier returns above don't count as a "nav".
    _lastNavAt = now;

    final replace = data['closeBehavior'] == _closeBehaviorReplace;
    await entry.opener(navigator, args, replace: replace);

    return const BifrostResult.empty();
  }
}
