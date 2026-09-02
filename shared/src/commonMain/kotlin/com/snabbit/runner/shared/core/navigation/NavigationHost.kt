package com.snabbit.runner.shared.core.navigation

/**
 * The cross-layer hook the [NavigationController] uses to reach its Android host —
 * the few things shared Kotlin can't do itself because the host is a separate
 * Activity outside this module. The `:app` host Activity implements this and
 * registers via [NavigationController.host]; it forwards each call to the Flutter
 * bridge (and finishes the host where appropriate).
 *
 * This is a plain callback, **not** an MVI effect bus — the same kind of cross-layer
 * seam every other bridge in the app already uses. Two things are deliberately NOT
 * here: returning to Flutter (that is simply an empty back stack — the host finishes
 * itself) and failures (the open call returns a status to the consumer; the
 * controller only logs/reports — there is no failure event).
 */
interface NavigationHost {
    /**
     * True when this host is the app's **root shell** (the bottom-nav home surface),
     * i.e. back exits the app rather than returning to Flutter. Used to decide whether a
     * deep-link keep-host handoff is applicable (only the root shell owns the surface a
     * deep link would otherwise be hidden behind).
     */
    val isRootShell: Boolean

    /** Native → Flutter handoff: open [route] (+ [args]) on the Flutter side and yield. */
    fun openFlutterRoute(route: String, args: Map<String, String>)

    /**
     * Native → Flutter handoff that **keeps the native host alive** (reordering round
     * trip): reorder the Flutter surface to front and push [route]; the native back
     * stack is preserved. [recreateKey]/[recreateArgs] are stashed so the host can be
     * rebuilt if the OS reclaims it while backgrounded.
     */
    fun openFlutterRouteKeepingHost(
        route: String,
        args: Map<String, String>,
        recreateKey: String,
        recreateArgs: Map<String, String>,
    )

    /** Finish the native flow and return [result] to the awaiting Flutter caller. */
    fun finishWithResult(result: Map<String, String>)

    /**
     * Exit the native flow and return to Flutter **without a result** (a plain back-out from
     * the root). The host finishes itself; an awaiting for-result caller is completed with
     * `null` on teardown. Implementations finish *while the current screen is still composed*,
     * so the OS close animation slides it out smoothly — no blank-frame flash from emptying
     * the back stack first.
     */
    fun exit()
}
