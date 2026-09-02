import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/webview/app_navigator.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';

/// Result of validating the `data` portion of a navigate request against
/// a route's args contract. Either `args` (to be passed through to the
/// route opener) or `error` is populated — never both, never neither.
class ArgsResult {
  const ArgsResult.ok([this.args]) : error = null;

  factory ArgsResult.invalid(String reason) => ArgsResult._error(
        BifrostError(
          code: BifrostErrorCodes.invalidArgs,
          message: reason,
        ),
      );

  const ArgsResult._error(this.error) : args = null;

  final Object? args;
  final BifrostError? error;
}

/// Function that validates a raw args map and either produces a typed
/// object for the target route opener, or an `INVALID_ARGS` error.
typedef ArgsValidator = ArgsResult Function(Map<String, dynamic> data);

/// Function that actually performs the navigation for a route entry.
///
/// Conventions:
/// - Keep this function fast — the handler awaits it, so any long-running
///   work (like waiting for a bottom sheet to be dismissed) should be
///   scheduled with `unawaited` so the RPC response doesn't block.
/// - Throw on failure — the router catches and returns `INTERNAL_ERROR`.
typedef RouteOpener = Future<void> Function(
  AppNavigator navigator,
  Object? args, {
  required bool replace,
});

/// One entry in the registry: a `snabbit://` URI, the opener that runs
/// when the web asks for it, and an optional args validator.
class RouteEntry {
  const RouteEntry({
    required this.uri,
    required this.opener,
    this.argsValidator,
  });

  /// Most common case: push (or replace) a named Flutter route.
  factory RouteEntry.named({
    required String uri,
    required String routeName,
    ArgsValidator? argsValidator,
  }) {
    return RouteEntry(
      uri: uri,
      argsValidator: argsValidator,
      opener: (navigator, args, {required replace}) async {
        // Fire-and-forget: we don't want the RPC to block until the
        // pushed screen is popped.
        if (replace) {
          unawaited(
            navigator.pushReplacementNamed(routeName, arguments: args),
          );
        } else {
          unawaited(navigator.pushNamed(routeName, arguments: args));
        }
      },
    );
  }

  /// Show a modal bottom sheet. `closeBehavior: "replace"` has no effect
  /// on sheets (they're modal overlays, not routes to replace).
  ///
  /// Stacking caveat: this opener does NOT dismiss any open sheet before
  /// pushing a new one. Multiple sheets are now registered (PAN-upload,
  /// view-bank, view-pan), but each is triggered by a distinct user tap
  /// on the web side, so simultaneous stacking still isn't expected. If
  /// a future caller can plausibly stack on top of an open sheet, decide
  /// explicitly whether the new sheet should auto-dismiss the previous
  /// one (e.g. add a `dismissPrevious` flag) based on the actual UX —
  /// don't ship speculative dismiss-logic ahead of a real caller.
  factory RouteEntry.sheet({
    required String uri,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    double? maxHeightFraction,
    ArgsValidator? argsValidator,
  }) {
    return RouteEntry(
      uri: uri,
      argsValidator: argsValidator,
      opener: (navigator, args, {required replace}) async {
        final ctx = navigator.currentContext;
        if (ctx == null) {
          throw StateError(
            'RouteEntry.sheet: no live BuildContext on the navigator key',
          );
        }
        final BoxConstraints? constraints;
        if (maxHeightFraction != null) {
          final height = MediaQuery.of(ctx).size.height;
          constraints = BoxConstraints(maxHeight: height * maxHeightFraction);
        } else {
          constraints = null;
        }
        unawaited(
          showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: isScrollControlled,
            constraints: constraints,
            builder: builder,
          ),
        );
      },
    );
  }

  /// Full `snabbit://…` URI the web sends.
  final String uri;

  /// What happens when the web navigates to this URI.
  final RouteOpener opener;

  /// Optional: validate/parse the incoming `data` map. If null, the data
  /// map itself is passed through as `args` (or `null` if empty).
  final ArgsValidator? argsValidator;
}

/// Web-URI → route-entry lookup for the navigate handler. Case-sensitive,
/// exact match on the URI string.
class RouteRegistry {
  RouteRegistry(Iterable<RouteEntry> entries)
      : _byUri = {for (final e in entries) e.uri: e};

  final Map<String, RouteEntry> _byUri;

  RouteEntry? find(String uri) => _byUri[uri];

  Iterable<String> get registeredUris => _byUri.keys;
}
