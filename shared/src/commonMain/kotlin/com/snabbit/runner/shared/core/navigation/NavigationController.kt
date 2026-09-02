package com.snabbit.runner.shared.core.navigation

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.snapshots.SnapshotStateList
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.CompletableDeferred

/**
 * Owns the native back stack and is the single action surface for navigating
 * between native (Compose) [Destination]s. A process-scoped Koin singleton.
 *
 * This is a **plain state holder, not an MVI store**: navigation actions are direct
 * methods that mutate [backStack] in place — the idiomatic Nav3 "own the list" model
 * (no intent/reducer, no effect channel). The method surface mirrors Flutter's
 * `Navigator`: [navigate]/[back]/[replace]/[resetTo]/[popUntil]/[pushAndRemoveUntil]/
 * [maybePop], plus [navigateForResult]/[popWithResult] for native→native results.
 *
 * The actions that must cross into the Android host — open a Flutter route ([requestFlutterRoute],
 * or [requestFlutterRouteKeepingHost] for the keep-host round trip), finish with a result —
 * go through the [host] callback ([NavigationHost]). Failures are logged via [reportFailure]
 * (the bridge returns a failure status to the caller — the module renders no error UI).
 * Returning to Flutter is simply an **empty [backStack]** (the host finishes itself); the
 * single-surface rule is one *foreground* surface, so [requestFlutterRouteKeepingHost] can
 * keep this stack alive in the background. `SnapshotStateList` is multiplatform
 * (`compose.runtime`), so this stays iOS-safe and unit-testable (mutations don't need a
 * composition).
 *
 * Process-death restore is intentionally not implemented — the app returns to
 * Flutter's cold start.
 */
class NavigationController(
    private val deeplinkResolver: DeeplinkResolver,
    private val destinationFactories: List<DestinationFactory> = emptyList(),
    private val logger: Logger,
    private val crashReporter: CrashReporter,
) {
    /** The native back stack — Nav3's `NavDisplay` observes and renders this directly. */
    val backStack: SnapshotStateList<Destination> = mutableStateListOf()

    /**
     * The Android host (a separate Activity) that performs the two actions shared code
     * can't — open a Flutter route, finish with a result. Set by the host while it is
     * attached; `null` when no host is foreground. A plain cross-layer callback, **not**
     * an MVI effect bus.
     */
    var host: NavigationHost? = null

    /** Awaiting [navigateForResult] callers, keyed by the back-stack index of the pushed entry. */
    private val pendingResults = mutableMapOf<Int, CompletableDeferred<Map<String, String>?>>()

    /** The destination on top, or `null` when the native host is empty. */
    val current: Destination? get() = backStack.lastOrNull()

    /** True when popping stays within the native stack (doesn't return to Flutter) — Flutter's `canPop`. */
    val canGoBack: Boolean get() = backStack.size > 1

    /** Push [destination] onto the stack (Flutter `push`). */
    fun navigate(destination: Destination) {
        backStack.add(destination)
    }

    /**
     * Push [destination] and **suspend until it is popped**, returning the result it
     * popped with via [popWithResult], or `null` for any other pop ([back]/[popUntil]/
     * [resetTo]/[clear]) — the caller never hangs. The Kotlin analog of
     * `await Navigator.push(...)`. Call from a `viewModelScope`.
     */
    suspend fun navigateForResult(destination: Destination): Map<String, String>? {
        backStack.add(destination)
        val deferred = CompletableDeferred<Map<String, String>?>()
        pendingResults[backStack.lastIndex] = deferred
        return deferred.await()
    }

    /**
     * Pop the top destination. Within the native stack this pops one entry. At the **root**
     * it returns to Flutter: if a [host] is attached it asks the host to
     * [exit][NavigationHost.exit] — finish while the current screen is still composed, so the
     * OS close animation slides it out smoothly (no white/blank flash from emptying the stack
     * first); the stack is cleared on the host's teardown. With **no host**, it empties the
     * stack, which is itself the return-to-Flutter signal. Flutter `pop` (without a result).
     */
    fun back() {
        if (backStack.size > 1) {
            backStack.removeAt(backStack.lastIndex)
            reconcilePendingResults()
            return
        }
        val currentHost = host
        if (currentHost != null) {
            currentHost.exit()
        } else {
            backStack.clear()
            reconcilePendingResults()
        }
    }

    /** Pop the top and return [result] to a [navigateForResult] caller awaiting it (Flutter `pop(result)`). */
    fun popWithResult(result: Map<String, String>) {
        if (backStack.isEmpty()) return
        pendingResults.remove(backStack.lastIndex)?.complete(result)
        backStack.removeAt(backStack.lastIndex)
        reconcilePendingResults()
    }

    /** Pop only if there's something to pop within the native stack; else `false` (no exit to Flutter). Flutter `maybePop`. */
    fun maybePop(): Boolean {
        if (backStack.size <= 1) return false
        backStack.removeAt(backStack.lastIndex)
        reconcilePendingResults()
        return true
    }

    /**
     * Pop until [predicate] matches the top, or the **root** is reached — never below it.
     * An unmatched predicate must not drain the stack to empty: an empty stack routes through
     * the host's blank-frame `finish` path instead of the smooth [back]/[NavigationHost.exit]
     * return-to-Flutter. If nothing matched we stop at the root and [reportFailure] the misuse.
     * Flutter `popUntil`.
     */
    fun popUntil(predicate: (Destination) -> Boolean) {
        while (backStack.size > 1 && !predicate(backStack.last())) {
            backStack.removeAt(backStack.lastIndex)
        }
        if (backStack.isNotEmpty() && !predicate(backStack.last())) {
            reportFailure("popUntil: predicate matched no destination on the stack; stopped at root")
        }
        reconcilePendingResults()
    }

    /** Push [destination] after popping until [predicate] matches. Flutter `pushAndRemoveUntil`. */
    fun pushAndRemoveUntil(destination: Destination, predicate: (Destination) -> Boolean) {
        while (backStack.isNotEmpty() && !predicate(backStack.last())) {
            backStack.removeAt(backStack.lastIndex)
        }
        reconcilePendingResults()
        backStack.add(destination)
    }

    /** Replace the top destination (adds when empty). Flutter `pushReplacement`. */
    fun replace(destination: Destination) {
        if (backStack.isEmpty()) {
            backStack.add(destination)
        } else {
            // The replaced entry's awaiter (if any) gets null — it's gone.
            pendingResults.remove(backStack.lastIndex)?.complete(null)
            backStack[backStack.lastIndex] = destination
        }
    }

    /** Clear the stack and start fresh at [destination] (land on a root). */
    fun resetTo(destination: Destination) {
        cancelAllPendingResults()
        backStack.clear()
        backStack.add(destination)
    }

    /**
     * Routes an already-resolved deep-link value to a native destination. Returns
     * `true` if a native screen owns the value (and was pushed), `false` otherwise
     * (so the Dart `DeeplinkRouter` keeps handling Flutter-owned values unchanged).
     */
    fun handleResolvedDeeplink(value: String, params: Map<String, String?>): Boolean {
        val destination = deeplinkResolver.resolve(value, params) ?: return false
        warnIfSessionActive("deep link '$value'")
        backStack.add(destination)
        return true
    }

    /**
     * Opens a native destination identified by [key] (+ [args]), as requested by Flutter
     * via the bridge. Returns `true` if a [DestinationFactory] owns the key (and it was
     * pushed), `false` otherwise (the bridge returns that status to the Flutter caller).
     */
    fun openByKey(key: String, args: Map<String, String?>): Boolean {
        val destination = destinationFactories.firstNotNullOfOrNull { it.create(key, args) } ?: return false
        warnIfSessionActive("native destination '$key'")
        backStack.add(destination)
        return true
    }

    /**
     * Requests navigation to a Flutter-owned [route] (a native → Flutter handoff).
     * Delegates to the [host], which forwards it to Flutter and finishes. Does not touch
     * the native back stack.
     */
    fun requestFlutterRoute(route: String, args: Map<String, String> = emptyMap()) {
        host?.openFlutterRoute(route, args)
    }

    /**
     * Native → Flutter handoff that **keeps this native screen alive** (the reordering
     * round trip): the host reorders the Flutter surface to front and pushes [route],
     * but the native back stack is preserved so the user can return here. [recreateKey]
     * /[recreateArgs] let the host be rebuilt if the OS reclaims it while backgrounded.
     * Does not touch the back stack.
     */
    fun requestFlutterRouteKeepingHost(
        route: String,
        args: Map<String, String> = emptyMap(),
        recreateKey: String,
        recreateArgs: Map<String, String> = emptyMap(),
    ) {
        host?.openFlutterRouteKeepingHost(route, args, recreateKey, recreateArgs)
    }

    /**
     * Finishes the native flow and returns [result] to the Flutter caller that opened it
     * *for a result* (the `startActivityForResult` equivalent). With a [host] attached it
     * finishes via the host **while the current screen is still composed** (smooth OS close,
     * no blank-frame flash — the stack is cleared on teardown); with no host it empties the
     * stack (the return-to-Flutter signal). Native→native result awaiters are cancelled (null).
     */
    fun finishWithResult(result: Map<String, String>) {
        cancelAllPendingResults()
        val currentHost = host
        if (currentHost != null) {
            // Don't clear the stack first — keep the screen composed so the close animation
            // slides it out (no white flash). onDestroy's terminal teardown clears it.
            currentHost.finishWithResult(result)
        } else {
            backStack.clear()
        }
    }

    /**
     * Logs a navigation failure and reports it as a non-fatal (so a misconfigured route
     * is visible in the crash dashboard). Pure observability — the module renders **no**
     * error UI; the bridge returns a failure status to the caller.
     */
    fun reportFailure(reason: String) {
        logger.e(TAG, "Navigation failure: $reason")
        crashReporter.report(NavigationException(reason), mapOf("reason" to reason))
    }

    /**
     * Nested-session guard. Opening a native destination or routing a deep link **from Flutter**
     * while a native [backStack] already exists is the unsupported native→Flutter→native case:
     * the single flat stack appends here, so back from the new screen returns to the old native
     * stack instead of the intervening Flutter screen (a wrong back path). The proper fix is a
     * session-scoped stack per host launch (tracked as a follow-up); until then we don't change
     * behaviour but [reportFailure] so the misuse is visible. See
     * KMP_NAVIGATION_INTEGRATION_GUIDE → "One native session at a time".
     */
    private fun warnIfSessionActive(opening: String) {
        if (backStack.isNotEmpty()) {
            reportFailure(
                "Opening $opening while a native session is already active — nested " +
                    "native<->Flutter sessions are not yet supported (single-session model)",
            )
        }
    }

    /**
     * Empties the native back stack. Called by the host on terminal teardown so a
     * finished session never leaves stale entries for the next host launch.
     */
    fun clear() {
        cancelAllPendingResults()
        backStack.clear()
    }

    /** Complete (with `null`) any awaiting result whose entry is no longer on the stack. */
    private fun reconcilePendingResults() {
        pendingResults.keys.filter { it >= backStack.size }.forEach {
            pendingResults.remove(it)?.complete(null)
        }
    }

    /** Complete (with `null`) and drop every awaiting result (full reset / teardown). */
    private fun cancelAllPendingResults() {
        pendingResults.values.forEach { it.complete(null) }
        pendingResults.clear()
    }

    private companion object {
        const val TAG = "NavigationController"
    }
}

/**
 * Raised to report a navigation failure as a non-fatal so it surfaces in the crash
 * dashboard. [message] is the human-readable reason.
 */
class NavigationException(message: String) : Exception(message)
