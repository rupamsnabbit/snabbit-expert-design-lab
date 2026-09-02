import 'package:pigeon/pigeon.dart';

// Type-safe bridge for the KMP navigation module. Run codegen after editing:
//   dart run pigeon --input pigeons/navigation_api.dart
// Generated files are committed (paths below). Do NOT hand-edit the *.g.* files.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/services/navigation/navigation_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/snabbit/runner/navigation/bridge/NavigationApi.g.kt',
    kotlinOptions:
        KotlinOptions(package: 'com.snabbit.runner.navigation.bridge'),
    dartPackageName: 'snabbit_runner',
  ),
)

/// A command the native navigation host asks Flutter to execute (KMP → Dart,
/// event channel). Currently the single cross-world action is opening a
/// Flutter-owned route during a native → Flutter handoff.
class NavCommand {
  NavCommand({required this.type, required this.route, this.args});

  final NavCommandType type;

  /// Flutter route name. Always set — every command type carries a route.
  final String route;

  /// Optional string arguments for the route.
  final Map<String?, String?>? args;
}

enum NavCommandType {
  /// Navigate to a Flutter-owned route ([NavCommand.route] + [NavCommand.args]) —
  /// a terminal handoff (the native host finishes).
  openFlutterRoute,

  /// Push a Flutter route while KEEPING the native host alive behind it (the
  /// reordering round trip). Dismissing it calls [NavigationHostApi.returnToNativeHost].
  pushHostBackedRoute,

  /// The native root-shell host just became the resumed foreground surface —
  /// Dart should drain any deeplink held for the cohort ([NavCommand.route] is
  /// unused/empty). This makes a held deeplink open ON TOP of the now-foreground
  /// shell, so a shell that launches/re-launches never covers it.
  drainDeeplinks,
}

/// Dart → KMP (method channel). Drives the native (Compose) navigation host.
@HostApi()
abstract class NavigationHostApi {
  /// Open a registered native destination (launches the native host). Returns
  /// `true` if a native screen owns the key (and was opened), `false` otherwise —
  /// the caller decides how to handle a `false` (the module renders no error UI).
  bool openNativeDestination(String key, Map<String?, String?> args);

  /// Open a native destination and await its result (the
  /// `startActivityForResult` equivalent). Completes with the result map the
  /// native screen returned, or `null` if the screen was dismissed without one.
  @async
  Map<String?, String?>? openNativeDestinationForResult(
    String key,
    Map<String?, String?> args,
  );

  /// Route an already-resolved deep-link value to a native destination.
  /// Returns true if a native screen owns it (and the host was opened); false
  /// lets the Dart DeepLinkRouter keep handling the value as a Flutter route.
  bool handleResolvedDeeplink(String value, Map<String?, String?> params);

  /// Deep-link keep-host handoff for a Flutter-owned destination. When a native
  /// root-shell host is currently live (the MQTT-cohort shell is foreground), it
  /// brings Flutter to front (keeping the host alive behind it) and opens [route]
  /// (+ [args]) as a host-backed route so back returns to the shell; returns `true`.
  /// Returns `false` when no root-shell host is live — the caller then navigates
  /// on Flutter itself (unchanged behaviour for non-cohort runners).
  bool openDeeplinkViaHost(String route, Map<String?, String?> args);

  /// True when the native root-shell host (the MQTT-cohort bottom-nav shell) is
  /// currently the RESUMED foreground surface. The deeplink router uses this to
  /// HOLD a cohort deeplink until the shell is actually up — so the linked screen
  /// opens ON TOP of the shell (drained on the shell's onResume) instead of being
  /// covered by a shell that launches/re-launches afterward.
  bool isRootShellForeground();

  /// Loan deep-link, native path: ask the RUNNING root-shell (the MQTT-cohort
  /// bottom-nav shell) to switch to the Profile tab and open the native loan sheet.
  /// Loan is migrated — it lives inside the Profile tab, not as a standalone screen,
  /// so this stays on the shell (no keep-host handoff) and signals it in-place.
  /// Returns `true` when the shell took it; `false` when no root-shell host is the
  /// foreground surface — the caller then shows the Flutter loan sheet (unchanged
  /// behaviour for non-cohort runners).
  bool showLoanInShell();

  /// Pop the native back stack (the host finishes when it empties, returning to
  /// Flutter — single-active-surface).
  void back();

  /// Return to a host-backed native screen the user handed off from (the reordering
  /// round trip). Reorders the live native host to front, or recreates it from its
  /// stashed key+args if the OS reclaimed it while backgrounded.
  @async
  void returnToNativeHost();

  /// Forced-logout teardown: finish the native shell (NavigationHostActivity) so the
  /// Flutter login screen — already pushed by handle403() on the Flutter navigator
  /// underneath — becomes the foreground surface. No-op when no native host is alive
  /// (non-cohort runners, or the runner is already on Flutter).
  void exitNativeShell();
}

/// KMP → Dart (event channel). Stream of commands the native host emits for
/// Flutter to execute.
@EventChannelApi()
abstract class NavigationEventApi {
  NavCommand navCommands();
}
