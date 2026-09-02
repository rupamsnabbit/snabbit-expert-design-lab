package com.snabbit.runner.navigation.bridge

import android.app.Activity
import android.app.ActivityOptions
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.snabbit.runner.R
import com.snabbit.runner.navigation.NavigationHostActivity
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.ShellLoanRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Pigeon bridge for the KMP navigation module. Owns both directions:
 *  - **Dart → KMP** ([NavigationHostApi]): open a native destination, route a
 *    resolved deep-link value, or pop. Each delegates to [NavigationController]
 *    (Koin singleton) and launches [NavigationHostActivity].
 *  - **KMP → Dart** ([NavCommandsStreamHandler]): a stream of [NavCommand]s the
 *    host emits (`OpenFlutterRoute` for a terminal handoff; `PushHostBackedRoute`
 *    for the keep-host round trip). The sink is held statically
 *    because [NavigationHostActivity] is a *separate* Activity outside the Flutter
 *    engine and routes back through this engine-bound channel — the same reason
 *    `LanguagePlugin`/`DeeplinkPlugin` hold their channels statically.
 *
 * Registered in `MainActivity.configureFlutterEngine`. [ActivityAware] supplies
 * the host Activity used to launch [NavigationHostActivity].
 */
class NavigationBridgePlugin :
    FlutterPlugin, ActivityAware, NavigationHostApi, KoinComponent {

    private val controller: NavigationController by inject()
    private val loanRequest: ShellLoanRequest by inject()
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NavigationHostApi.setUp(binding.binaryMessenger, this)
        NavCommandsStreamHandler.register(binding.binaryMessenger, commandsStreamHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NavigationHostApi.setUp(binding.binaryMessenger, null)
        sink = null
        // Drop any command buffered for a transiently-absent listener — the engine (and its
        // Dart isolate) is going away, so there is nothing left to flush it to.
        pendingCommand = null
        // Drop any awaiting for-result callback so it can't leak or fire on a dead
        // channel (the Dart isolate is going away with the engine).
        pendingResultCallback = null
        // Drop keep-host round-trip state — it's meaningless without the engine.
        recreation = null
        hostAlive = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- NavigationHostApi: Dart → KMP -------------------------------------

    override fun openNativeDestination(key: String, args: Map<String?, String?>): Boolean {
        // Confirm a host Activity can launch BEFORE mutating the back stack, so a
        // missing Activity can't leave a dangling destination on the controller.
        // The boolean return is the consumer's failure signal (the module shows no UI).
        val host = activity
        if (host == null) {
            controller.reportFailure("${NavigationBridgeError.NO_HOST_ACTIVITY_FOUND} open key=$key")
            return false
        }
        return if (controller.openByKey(key, args.stringKeyed())) {
            // ponytail: single root shell today; hardcoded key, promote to registration
            // metadata when a second appears.
            launchHost(host, rootShell = (key == "bottom_nav_shell"))
            true
        } else {
            controller.reportFailure("${NavigationBridgeError.NO_NATIVE_DEST_REGISTERED} key=$key")
            false
        }
    }

    override fun handleResolvedDeeplink(value: String, params: Map<String?, String?>): Boolean {
        // No host Activity → report not-handled so the Dart DeepLinkRouter keeps
        // routing it as a Flutter route (instead of consuming it into a dead end).
        val host = activity ?: run {
            // Mirror the other host-null branches so a native-owned deep link that can't be
            // opened is visible on the dashboard, not silently indistinguishable from a
            // genuinely unknown Flutter path.
            controller.reportFailure("${NavigationBridgeError.NO_HOST_FOR_RESOLVED_DEEPLINK} value=$value")
            return false
        }
        val handled = controller.handleResolvedDeeplink(value, params.stringKeyed())
        if (handled) launchHost(host)
        return handled
    }

    override fun openDeeplinkViaHost(route: String, args: Map<String?, String?>): Boolean {
        // Deep-link keep-host handoff for a FLUTTER destination: only applies when a live
        // ROOT-SHELL host owns the foreground surface (the MQTT-cohort shell). Otherwise
        // return false so the Dart DeepLinkRouter navigates on Flutter itself — unchanged
        // behaviour for non-cohort runners and cohort runners who failed open to Flutter.
        val host = controller.host
        // Require the root-shell host to be the RESUMED foreground surface — not just
        // alive. A host that is alive but not foreground (mid-launch, or paused because a
        // OneLink/notification brought Flutter forward) would otherwise reorder Flutter up
        // and then be covered when the shell resumes. The router holds the deeplink until
        // isRootShellForeground() and drains it on the shell's onResume, so this is TRUE then.
        if (host == null || !host.isRootShell || !rootShellForeground) {
            return false
        }
        // Recreate fallback used only if the OS reclaims the backgrounded shell mid-excursion;
        // the common case reorders the live shell forward (its actual tab intact) via
        // returnToNativeHost. "Home" mirrors NavTab.Home (startNavTab defaults to it anyway).
        controller.requestFlutterRouteKeepingHost(
            route = route,
            args = args.nonNullStringMap(),
            recreateKey = "bottom_nav_shell",
            recreateArgs = mapOf("initialTab" to "Home"),
        )
        return true
    }

    override fun isRootShellForeground(): Boolean = rootShellForeground

    override fun showLoanInShell(): Boolean {
        // Loan is migrated to the Profile-tab native sheet. Same gate as openDeeplinkViaHost:
        // only when a live ROOT-SHELL host owns the RESUMED foreground surface (the MQTT-cohort
        // shell). Otherwise false → the Dart router shows the Flutter loan sheet (unchanged for
        // non-cohort runners). The router holds the cohort deeplink until isRootShellForeground(),
        // so this is TRUE for a cohort loan deeplink.
        val host = controller.host
        if (host == null || !host.isRootShell || !rootShellForeground) {
            return false
        }
        // Stay on the native shell (NO reorder/keep-host, unlike a Flutter destination): signal
        // the running shell to switch to Profile + open the loan sheet. The shell and
        // ProfileTabContent observe this holder; ProfileTabContent consumes it.
        loanRequest.request()
        return true
    }

    override fun openNativeDestinationForResult(
        key: String,
        args: Map<String?, String?>,
        callback: (Result<Map<String?, String?>?>) -> Unit,
    ) {
        // No host Activity → complete the awaiting caller now (don't push, don't hang).
        val host = activity
        if (host == null) {
            callback(Result.success(null))
            controller.reportFailure("${NavigationBridgeError.NO_HOST_ACTIVITY_FOUND} open-for-result key=$key")
            return
        }
        // One for-result flow at a time. If one is already awaiting, DON'T evict it — that
        // would complete the live caller with null, indistinguishable from a genuine user
        // cancel (a silent data-integrity bug). Reject the NEW call instead and report it.
        if (pendingResultCallback != null) {
            controller.reportFailure(
                "${NavigationBridgeError.FOR_RESULT_ALREADY_IN_FLIGHT} key=$key — rejecting the " +
                    "new call to protect the live one",
            )
            callback(Result.success(null))
            return
        }
        pendingResultCallback = callback
        if (controller.openByKey(key, args.stringKeyed())) {
            launchHost(host)
        } else {
            pendingResultCallback = null
            callback(Result.success(null))
            controller.reportFailure("${NavigationBridgeError.NO_NATIVE_DEST_REGISTERED} key=$key")
        }
    }

    override fun back() {
        controller.back()
    }

    override fun exitNativeShell() {
        // Forced logout (401). handle403 has already navigated the Flutter navigator to
        // login BEHIND this shell; finish the shell so that login surface is revealed.
        // exit() finishes while the screen is still composed (smooth close) and its
        // onDestroy terminal path clears the native back stack (and nulls recreation via
        // onHostDestroyed). No live host → non-cohort runner, or the runner already
        // handed off to Flutter: no-op, but defensively clear any residual nav/recreation
        // state so a stray returnToNativeHost can't rebuild a shell for a logged-out
        // session. Runs on the platform main thread (Pigeon @HostApi handler), so the
        // Activity finish is safely on-main.
        val host = controller.host
        if (host != null) {
            host.exit()
        } else {
            controller.clear()
            recreation = null
        }
    }

    override fun returnToNativeHost(callback: (Result<Unit>) -> Unit) {
        // The keep-host round trip's return leg: bring the native host back to front.
        val host = activity
        if (host == null) {
            controller.reportFailure(NavigationBridgeError.NO_HOST_TO_RETURN)
            callback(Result.success(Unit))
            return
        }
        if (controller.backStack.isNotEmpty()) {
            // The native back stack lives in the process-scoped controller, so it
            // survives the host being backgrounded OR reclaimed by the OS — only full
            // process death clears it. Reorder the live instance forward, or (if it was
            // reclaimed) start a fresh one that re-renders the surviving stack. Either
            // way we land on its TOP entry, so a multi-entry stack [B, C, …] returns to
            // C, not a single recreated screen.
            // rootShell = true: the keep-host round trip only ever leaves from the
            // bottom-nav shell, so a reclaimed host recreated here (onCreate re-run)
            // needs EXTRA_ROOT_SHELL too, or RootShellWiring.applyWindow never runs
            // and the bars fall back to opaque black (ECPO status-bar bug).
            launchHost(host, reorder = hostAlive, rootShell = true, slideBack = true)
            // Round trip complete — drop the stashed recreation so a LATER trip can't
            // rebuild this trip's (now stale) screen if the host is reclaimed empty.
            recreation = null
        } else {
            // Stack is gone (singleton cleared / process recreated) — rebuild the entry
            // screen from the stashed key+args as a last resort. Note this restores only
            // a single entry; a deep native stack is not reconstructed (no-restore contract).
            val recreate = recreation
            if (recreate != null && controller.openByKey(recreate.first, recreate.second)) {
                launchHost(host, rootShell = true, slideBack = true)
                recreation = null
            } else {
                controller.reportFailure(
                    "${NavigationBridgeError.RETURN_NO_STACK_OR_RECREATION} empty native stack " +
                        "and no recreation state",
                )
            }
        }
        callback(Result.success(Unit))
    }

    private fun launchHost(
        host: Activity,
        reorder: Boolean = false,
        rootShell: Boolean = false,
        slideBack: Boolean = false,
    ) {
        // SINGLE_TOP reuses the one host instance if it's already foreground, so a
        // rapid open-then-open (e.g. a for-result interleave) doesn't stack a second.
        // REORDER_TO_FRONT brings an alive-but-backgrounded host forward without
        // recreating it (the keep-host return leg) — harmless when none exists.
        val intent = Intent(host, NavigationHostActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (reorder) intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        if (rootShell) intent.putExtra(NavigationHostActivity.EXTRA_ROOT_SHELL, true)
        // Return leg of the keep-host round trip: reverse-slide (host enters from the
        // left, Flutter exits to the right) so "back" reads as back — the mirror of the
        // forward handoff's enter-from-right. The default REORDER open animation would
        // otherwise slide the host in from the right like a forward push. Full-width,
        // edge-adjacent anims keep the screen covered, masking the brief home-frame during
        // the reorder. makeCustomAnimation is the non-deprecated launch-anim API.
        val options = if (slideBack) {
            ActivityOptions.makeCustomAnimation(
                host,
                R.anim.nav_enter_from_left,
                R.anim.nav_exit_to_right,
            ).toBundle()
        } else {
            null
        }
        host.startActivity(intent, options)
    }

    private val commandsStreamHandler = object : NavCommandsStreamHandler() {
        override fun onListen(p0: Any?, sink: PigeonEventSink<NavCommand>) {
            NavigationBridgePlugin.sink = sink
            // Flush a command emitted while no listener was attached (engine detach/reattach),
            // so a terminal handoff is delivered late rather than lost.
            pendingCommand?.let { buffered ->
                pendingCommand = null
                mainHandler.post { NavigationBridgePlugin.sink?.success(buffered) }
            }
        }

        override fun onCancel(p0: Any?) {
            NavigationBridgePlugin.sink = null
        }
    }

    /**
     * Cross-Activity static state. [NavigationHostActivity] is a *separate* Activity outside the
     * Flutter engine, so it reaches this engine-bound plugin through these statics.
     *
     * **Threading invariant:** every field here is confined to the **main looper**. The Pigeon
     * `@HostApi` handlers dispatch on the platform main thread (no TaskQueue) and every host->Dart
     * emit hops through [mainHandler], so all reads/writes land on one thread — no `@Volatile`
     * needed. Keep it that way: if a background TaskQueue is ever added, revisit this.
     */
    companion object {
        /** Engine-bound event sink; the host pushes [NavCommand]s through it. */
        private var sink: PigeonEventSink<NavCommand>? = null

        /**
         * A KMP->Dart command emitted while no EventChannel listener was attached (engine
         * detach/reattach). Buffered here and flushed on the next `onListen`, so a terminal
         * handoff is delivered late rather than silently dropped. At most one (single surface).
         */
        private var pendingCommand: NavCommand? = null

        /** The awaiting `openNativeDestinationForResult` caller, if any (one at a time). */
        private var pendingResultCallback: ((Result<Map<String?, String?>?>) -> Unit)? = null

        /**
         * Stashed key+args to rebuild the native host if the OS reclaims it during a
         * keep-host round trip ([emitPushHostBackedRoute]). Null when no round trip is
         * in flight; dropped on terminal teardown.
         */
        private var recreation: Pair<String, Map<String, String>>? = null

        /** True while a host Activity instance exists (between its onCreate and onDestroy). */
        private var hostAlive: Boolean = false

        /**
         * True while the ROOT-SHELL host is the RESUMED foreground surface (between its
         * onResume and onPause). The deeplink router reads this (via [isRootShellForeground])
         * to hold a cohort deeplink until the shell is actually up, and the shell's onResume
         * signals Dart to drain — so a held deeplink opens ON TOP of the shell.
         */
        private var rootShellForeground: Boolean = false

        private val mainHandler = Handler(Looper.getMainLooper())

        private const val TAG = "NavigationBridge"

        /**
         * Emits a [NavCommand] to Dart on the main looper. If no listener is attached (engine
         * transiently detached), the command is BUFFERED and flushed on the next `onListen` —
         * never dropped, since the caller ([NavigationHostActivity]) has usually already
         * `finish()`ed and a lost handoff would strand the user on Flutter with no route pushed.
         */
        private fun emit(command: NavCommand) {
            mainHandler.post {
                val activeSink = sink
                if (activeSink != null) {
                    activeSink.success(command)
                } else {
                    pendingCommand = command
                    Log.w(TAG, "nav command buffered (no EventChannel listener yet): ${command.type}")
                }
            }
        }

        /**
         * Emits an `OpenFlutterRoute` command to Dart — a terminal native → Flutter handoff,
         * signalled by [NavigationHostActivity].
         */
        fun emitOpenFlutterRoute(route: String, args: Map<String, String>) =
            emit(
                NavCommand(
                    type = NavCommandType.OPEN_FLUTTER_ROUTE,
                    route = route,
                    args = HashMap<String?, String?>(args),
                ),
            )

        /**
         * Emits a `PushHostBackedRoute` command to Dart: open [route] on the Flutter side
         * while the native host stays alive behind it (the keep-host round trip). Dismissing
         * that route calls back through `returnToNativeHost`.
         */
        fun emitPushHostBackedRoute(route: String, args: Map<String, String>) =
            emit(
                NavCommand(
                    type = NavCommandType.PUSH_HOST_BACKED_ROUTE,
                    route = route,
                    args = HashMap<String?, String?>(args),
                ),
            )

        /**
         * The host Activity resumed (became the foreground surface). For the ROOT SHELL this
         * (a) marks it foreground so a held cohort deeplink may now open over it, and (b) signals
         * Dart to drain any held deeplink — so a deeplink held while the shell was launching/
         * re-launching opens ON TOP of the now-foreground shell instead of being covered by it.
         * Called by [NavigationHostActivity.onResume].
         */
        fun onHostResumed(isRootShell: Boolean) {
            if (!isRootShell) return
            rootShellForeground = true
            emit(NavCommand(type = NavCommandType.DRAIN_DEEPLINKS, route = "", args = null))
        }

        /** The host Activity paused (no longer foreground). Clears the root-shell foreground
         *  flag so a deeplink arriving now is held until the shell resumes again. */
        fun onHostPaused(isRootShell: Boolean) {
            if (isRootShell) rootShellForeground = false
        }

        /**
         * Completes a pending `openNativeDestinationForResult` future. Called by
         * [NavigationHostActivity] when the native flow ends: with the result on
         * `finishWithResult`, or `null` when it returns to Flutter / hands off
         * without one. No-op when no caller is awaiting.
         */
        fun deliverResult(result: Map<String, String>?) {
            val callback = pendingResultCallback ?: return
            pendingResultCallback = null
            mainHandler.post { callback(Result.success(result?.let { HashMap<String?, String?>(it) })) }
        }

        /**
         * Stash the key+args needed to rebuild the native host if the OS reclaims it
         * during a keep-host round trip. Called by [NavigationHostActivity] just before
         * it backgrounds itself for the handoff.
         */
        fun rememberHostRecreation(key: String, args: Map<String, String>) {
            recreation = key to args
        }

        /** The host Activity was created — it's alive and can be reordered forward. */
        fun onHostCreated() {
            hostAlive = true
        }

        /**
         * The host Activity was destroyed. On a terminal finish (back-out / handoff /
         * swipe-away) also drop the recreation state — the session is over. A
         * non-terminal OS reclaim keeps it so the host can be rebuilt on return.
         */
        fun onHostDestroyed(terminal: Boolean) {
            hostAlive = false
            if (terminal) recreation = null
        }
    }
}

/** Drops null keys: Flutter's `Map<String?, String?>` → KMP's `Map<String, String?>`. */
private fun Map<String?, String?>.stringKeyed(): Map<String, String?> =
    entries.mapNotNull { (k, v) -> k?.let { it to v } }.toMap()

/** Drops null keys AND null values: Flutter's `Map<String?, String?>` → `Map<String, String>`
 *  (the arg shape [NavigationController.requestFlutterRouteKeepingHost] expects). The deep-link
 *  args are always non-null strings, so nothing is dropped in practice. */
private fun Map<String?, String?>.nonNullStringMap(): Map<String, String> =
    entries.mapNotNull { (k, v) -> if (k != null && v != null) k to v else null }.toMap()
