import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:snabbit_runner/main.dart' show appRoutes;
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/select_language_init_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

import 'host_backed_route.dart';
import 'navigation_api.g.dart';

/// Dart side of the KMP navigation bridge.
///
/// Wraps the Pigeon [NavigationHostApi] (Dart → KMP: open a native destination,
/// route a resolved deep-link, pop) and consumes the [navCommands] event stream
/// (KMP → Dart), executing native → Flutter handoffs against the root Navigator.
///
/// The native (Compose) screens run in a separate host Activity; this client only
/// asks KMP to open them and reacts to the commands it streams back. Every method
/// is defensive — a bridge error logs and degrades to "not handled" so the
/// existing Flutter navigation is never broken by the bridge.
class KmpNavigationBridge {
  KmpNavigationBridge._();
  static final KmpNavigationBridge instance = KmpNavigationBridge._();

  final NavigationHostApi _hostApi = NavigationHostApi();
  StreamSubscription<NavCommand>? _sub;

  /// Invoked when the native root-shell host resumes and asks Dart to drain any
  /// deeplink held for the cohort. Wired in `main.dart` to
  /// `DeepLinkRouter.instance.drainPending`. Null until wired.
  void Function()? onDrainRequested;

  /// Broadcasts each time the native root-shell host resumes (becomes foreground).
  /// The cohort PartnerHome recovery awaits this as the truthful "shell is up"
  /// signal instead of polling a flag. App-lifetime (this bridge is a singleton).
  final StreamController<void> _rootShellResumed =
      StreamController<void>.broadcast();

  /// Completes `true` when the root-shell host is — or becomes, within [timeout] —
  /// the foreground surface, else `false`. Checks live ground truth first, then
  /// awaits the next resume event: no grace-window guessing. Never throws.
  Future<bool> waitForRootShellForeground(Duration timeout) async {
    final completer = Completer<bool>();
    // Subscribe BEFORE the ground-truth check so a resume firing between the check
    // and the listen is not missed.
    final sub = _rootShellResumed.stream.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    Timer? timer;
    try {
      if (await isRootShellForeground()) return true;
      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(false);
      });
      return await completer.future;
    } catch (e) {
      // Honour the "never throws" contract (matches every other bridge method):
      // any failure degrades to "shell not foreground" so a bridge hiccup can't
      // break the cohort recovery that awaits this.
      MonitoringServiceHelper.logWarning(
        'kmp_nav_wait_root_shell_foreground_failed',
        {'error': e.toString()},
      );
      return false;
    } finally {
      await sub.cancel();
      timer?.cancel();
    }
  }

  /// Subscribe to native → Flutter commands. Idempotent; call once during app
  /// init (alongside the deeplink wiring).
  void start() {
    _sub ??= navCommands().listen(
      _handleCommand,
      onError: (Object e) => MonitoringServiceHelper.logWarning(
        'kmp_nav_command_stream_error',
        {'error': e.toString()},
      ),
    );
  }

  /// Asks KMP whether [value] (a resolved deep-link value) maps to a native
  /// screen, opening it if so. Returns false when no native screen owns it — the
  /// caller then keeps handling it as a Flutter route, unchanged. Never throws.
  Future<bool> handleResolvedDeeplink(
    String value,
    Map<String, String> params,
  ) async {
    try {
      return await _hostApi.handleResolvedDeeplink(value, params);
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_handle_deeplink_failed',
        {'value': value, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Deep-link keep-host handoff for a Flutter-owned destination. When a native
  /// root-shell host is live (the MQTT-cohort shell is the foreground surface), it
  /// brings Flutter to front (keeping the host alive behind it) and opens [route]
  /// (+ [args]) as a host-backed route so back returns to the shell; returns `true`.
  /// Returns `false` when no root-shell host is live — the caller then navigates on
  /// Flutter itself (the unchanged path for non-cohort runners). Never throws.
  Future<bool> openDeeplinkViaHost(
    String route, [
    Map<String, String> args = const {},
  ]) async {
    try {
      return await _hostApi.openDeeplinkViaHost(route, args);
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_open_deeplink_via_host_failed',
        {'route': route, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Whether the native root-shell host is the resumed foreground surface, or
  /// `null` if the bridge call itself errored (channel down / host gone) — i.e.
  /// "couldn't determine", which is distinct from a definite "not foreground".
  /// Callers that must tell those apart (e.g. the PartnerHome watchdog, so it
  /// doesn't reopen on a broken channel) use this.
  Future<bool?> isRootShellForegroundOrNull() async {
    try {
      return await _hostApi.isRootShellForeground();
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_is_root_shell_foreground_failed',
        {'error': e.toString()},
      );
      return null;
    }
  }

  /// Whether the native root-shell host (the MQTT-cohort shell) is the resumed
  /// foreground surface. The deeplink router uses this to hold a cohort deeplink
  /// until the shell is up (so the linked screen opens on top of it). Never throws —
  /// a bridge error resolves to `false` (router treats it as "not foreground").
  Future<bool> isRootShellForeground() async =>
      await isRootShellForegroundOrNull() ?? false;

  /// Loan deeplink, native path: asks the running root-shell (the MQTT-cohort shell) to
  /// switch to the Profile tab and open the native loan sheet. Returns `true` when the
  /// shell took it; `false` (non-cohort / shell not the foreground surface / bridge error)
  /// → the caller shows the Flutter loan sheet instead. Never throws.
  Future<bool> showLoanInShell() async {
    try {
      return await _hostApi.showLoanInShell();
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_show_loan_in_shell_failed',
        {'error': e.toString()},
      );
      return false;
    }
  }

  /// Opens a registered native destination by [key]. Returns `true` if a native
  /// screen opened, `false` otherwise (unknown key / no host / bridge error) — the
  /// caller decides how to react (the module shows no error UI). Never throws.
  Future<bool> openNativeDestination(
    String key, [
    Map<String, String> args = const {},
  ]) async {
    try {
      return await _hostApi.openNativeDestination(key, args);
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_open_native_failed',
        {'key': key, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Opens a native destination and awaits its result (the
  /// `startActivityForResult` equivalent). Completes with the result map the
  /// native screen returned, or `null` if it was dismissed without one. Never
  /// throws — a bridge error logs and resolves to `null`.
  Future<Map<String, String>?> openNativeDestinationForResult(
    String key, [
    Map<String, String> args = const {},
  ]) async {
    try {
      final result = await _hostApi.openNativeDestinationForResult(key, args);
      if (result == null) return null;
      return {
        for (final entry in result.entries)
          if (entry.key != null) entry.key!: entry.value ?? '',
      };
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_open_for_result_failed',
        {'key': key, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Pops the native back stack (the host finishes when it empties, returning to
  /// Flutter). Best-effort; logs on error.
  Future<void> back() async {
    try {
      await _hostApi.back();
    } catch (e) {
      MonitoringServiceHelper.logWarning(
          'kmp_nav_back_failed', {'error': e.toString()});
    }
  }

  /// Returns to a host-backed native screen the user handed off from (the
  /// reordering round trip): brings the live native host back to front, or
  /// recreates it from its stashed key+args if the OS reclaimed it while
  /// backgrounded. Called by [HostBackedRoute] on dismissal. Best-effort; logs on
  /// error and never throws (so a bridge failure can't strand the back gesture).
  /// Host-backed routes that run their own back contract, so [HostBackedRoute]
  /// must stay out of the gesture path (see its `deferBackToChild` docs). The
  /// webview forwards every press to the web — an overlay open in there dismisses
  /// in place, and only a press the web declines becomes a `Navigator.pop()`.
  static const Set<String> _routesOwningBack = {AppWebViewPage.routeName};

  Future<void> returnToNativeHost() async {
    try {
      await _hostApi.returnToNativeHost();
    } catch (e) {
      MonitoringServiceHelper.logWarning(
          'kmp_nav_return_to_host_failed', {'error': e.toString()});
    }
  }

  /// Forced-logout teardown: finishes the native shell (the MQTT-cohort host
  /// Activity) so the Flutter login screen `handle403()` already pushed becomes
  /// the foreground surface. No-op for non-cohort runners (no native host alive).
  /// Best-effort; logs on error and never throws (so a bridge failure can't block
  /// the already-completed logout).
  Future<void> exitNativeShell() async {
    try {
      await _hostApi.exitNativeShell();
    } catch (e) {
      MonitoringServiceHelper.logWarning(
          'kmp_nav_exit_native_shell_failed', {'error': e.toString()});
    }
  }

  void _handleCommand(NavCommand command) {
    // Defensive: a throw in here (e.g. pushNamed of an unregistered route) runs inside
    // the stream's onData and would escape to the zone, not the stream's onError — so
    // catch it and log, keeping the bridge from ever breaking Flutter navigation.
    try {
      switch (command.type) {
        case NavCommandType.drainDeeplinks:
          // The native root-shell host just became foreground — drain any deeplink
          // held for the cohort so it opens ON TOP of the now-foreground shell.
          onDrainRequested?.call();
          // The same resume is the truthful "root shell is up" event the cohort
          // PartnerHome recovery waits on (see waitForRootShellForeground).
          if (!_rootShellResumed.isClosed) _rootShellResumed.add(null);
          // This doubles as the cohort's "app resumed" signal. Flutter's own
          // didChangeAppLifecycleState never reports `resumed` while the shell
          // covers MainActivity, so for these runners it is the only
          // resume-shaped hook there is — and it is what lets a failed FCM
          // registration recover without a cold start. No-op once the reported
          // build matches (a single SharedPreferences read).
          unawaited(SelectLanguageInitProvider.ensureFcmReported());

        case NavCommandType.openFlutterRoute:
          final route = command.route;
          if (route.isEmpty) return;
          final context = GlobalState().navigatorKey.currentContext;
          if (context == null) {
            MonitoringServiceHelper.logWarning(
              'kmp_nav_open_flutter_route_no_context',
              {'route': route},
            );
            return;
          }
          Navigator.of(context)
              .pushNamed(route, arguments: _routeArgs(command.args));

        case NavCommandType.pushHostBackedRoute:
          final route = command.route;
          if (route.isEmpty) return;
          final context = GlobalState().navigatorKey.currentContext;
          if (context == null) {
            MonitoringServiceHelper.logWarning(
              'kmp_nav_push_host_backed_no_context',
              {'route': route},
            );
            return;
          }
          final builder = appRoutes[route];
          if (builder == null) {
            // Route not in the table (misconfigured keep-host handoff). Degrade to
            // a normal push so the user still lands on the screen — back won't
            // route to native B in this case (logged for the dashboard).
            MonitoringServiceHelper.logWarning(
              'kmp_nav_push_host_backed_unknown_route',
              {'route': route},
            );
            Navigator.of(context)
                .pushNamed(route, arguments: _routeArgs(command.args));
            return;
          }
          Navigator.of(context).push(
            HostBackedRoute<dynamic>(
              builder: builder,
              settings: RouteSettings(
                name: route,
                arguments: _routeArgs(command.args),
              ),
              deferBackToChild: _routesOwningBack.contains(route),
            ),
          );
      }
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'kmp_nav_handle_command_failed',
        {'type': '${command.type}', 'error': e.toString()},
      );
    }
  }

  /// Normalizes Pigeon's `Map<String?, String?>` route args to `Map<String, dynamic>`
  /// so Flutter route builders that check `args is Map<String, dynamic>` actually receive
  /// them — a nullable-key map is NOT a subtype, so passing it raw silently drops the args.
  /// Null keys are dropped.
  Map<String, dynamic> _routeArgs(Map<String?, String?>? args) => {
        for (final e in (args ?? const {}).entries)
          if (e.key != null) e.key!: e.value,
      };
}
