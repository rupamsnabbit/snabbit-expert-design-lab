import 'package:flutter/widgets.dart';

import 'kmp_navigation_bridge.dart';

/// A Flutter route opened by the KMP navigation bridge during the *keep-host*
/// round trip — `Flutter A → native B → Flutter C → back → native B → back →
/// Flutter A`, with the native host (B) kept alive in the background while C is
/// shown.
///
/// Backing out of C must NOT reveal A; it must return to B. Every dismissal path
/// is funnelled through [_returnToNativeThenRemove], which brings B forward FIRST,
/// waits for B's enter animation to cover the screen, and only THEN removes C
/// off-screen — so the Flutter home (A) under C is never revealed (no flash):
///  - **system back / predictive back gesture** → [PopScope] (`canPop: false`)
///    stops the framework popping C and calls the funnel — unless C owns the
///    press itself ([deferBackToChild]), see below;
///  - **imperative `Navigator.pop()`** (a page's own AppBar back button, e.g.
///    PayoutHome / TransactionHistory) bypasses [PopScope], so [didPop] catches it,
///    returns `false` to defer the removal, and calls the same funnel.
///
/// [deferBackToChild] exists because Flutter dispatches `onPopInvokedWithResult`
/// to EVERY [PopScope] in the route's subtree — there is no "consumed" signal. A
/// page that runs its own back contract (the webview, which forwards the press to
/// the web and only dismisses when the web asks) would therefore see its press
/// handled twice: once by itself, and once here, tearing the page down underneath
/// it. With the flag set this route stays out of the gesture path entirely and
/// waits for C's own `Navigator.pop()`, which [didPop] already funnels correctly.
///
/// Pushed opaque with zero-duration transitions (the KMP↔Flutter slide is the
/// Activity-level animation, not a Flutter route transition). Sub-routes C itself
/// pushes (C → C2) are ordinary routes and pop normally; only the final dismissal
/// of C routes back to native B.
class HostBackedRoute<T> extends PageRoute<T> {
  HostBackedRoute({
    required this.builder,
    required RouteSettings super.settings,
    this.deferBackToChild = false,
  });

  /// Builds C's content — resolved from the app's `appRoutes` table so it is the
  /// exact widget `Navigator.pushNamed(name)` would have built.
  final WidgetBuilder builder;

  /// Whether C owns the system-back press. When true this route does not act on
  /// the gesture at all; C decides what the press means and calls `Navigator.pop()`
  /// when it really is a dismissal, which [didPop] funnels to native B as usual.
  final bool deferBackToChild;

  /// Guards against re-entrancy: the dismissal is async, so a second back event
  /// (or a bypassing imperative pop) arriving mid-return must be ignored.
  bool _returning = false;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _returning || deferBackToChild) return;
        _returning = true;
        _returnToNativeThenRemove();
      },
      child: builder(context),
    );
  }

  // Deliberately does NOT call super.didPop: super completes the pop and lets the
  // framework remove C immediately (revealing home). Returning false defers the
  // removal to [_returnToNativeThenRemove] — the documented way for a route to say
  // "I'm handling this dismissal myself".
  @override
  // ignore: must_call_super
  bool didPop(T? result) {
    // An imperative `Navigator.pop()` — a page's own AppBar back button — reaches
    // here, bypassing the [PopScope] above (which only catches the system-back
    // gesture / `Navigator.maybePop()`). Return `false` so the framework does NOT
    // remove C now: removing it immediately reveals the Flutter home (A) behind it
    // for the whole duration of B's slide-in (the "good time" flash on icon-back).
    // We take ownership of the removal via the funnel instead.
    if (!_returning) {
      _returning = true;
      _returnToNativeThenRemove();
    }
    return false;
  }

  /// Bring native B to front, wait for its enter animation to cover the screen,
  /// then remove C off-screen. Shared by the gesture ([PopScope]) and imperative
  /// ([didPop]) dismissal paths so both are flash-free. Best-effort;
  /// [KmpNavigationBridge.returnToNativeHost] never throws.
  Future<void> _returnToNativeThenRemove() async {
    await KmpNavigationBridge.instance.returnToNativeHost();
    // Hold C on top of A until B has slid in and covered the screen (~matches
    // nav_enter_from_left, 280ms), then remove C while it's already hidden behind B.
    await Future.delayed(const Duration(milliseconds: 300));
    if (isActive) navigator?.removeRoute(this);
  }

  @override
  void dispose() {
    // Last-resort safety net: if C is removed without either dismissal path having
    // run (e.g. the whole navigator is torn down), still bring B forward. Guarded
    // so the normal paths (which set [_returning]) never double-invoke.
    if (!_returning) {
      _returning = true;
      KmpNavigationBridge.instance.returnToNativeHost();
    }
    super.dispose();
  }
}
