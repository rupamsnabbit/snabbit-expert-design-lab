package com.snabbit.runner.navigation

import android.app.ActivityOptions
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.CompositionLocalProvider
import com.snabbit.runner.BuildConfig
import com.snabbit.runner.MainActivity
import com.snabbit.runner.R
import com.snabbit.runner.bottomnav.RootShellWiring
import com.snabbit.runner.navigation.bridge.NavigationBridgePlugin
import com.snabbit.runner.shared.core.navigation.LocalRootShellExit
import com.snabbit.runner.shared.core.navigation.NativeScreen
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.NavigationHost
import com.snabbit.runner.shared.core.permissions.ActivityAttachable
import com.snabbit.runner.shared.core.navigation.SnabbitNavHost
import org.koin.core.context.GlobalContext
import org.koin.mp.KoinPlatform.getKoin

/**
 * Native host for the KMP navigation module. A single, long-lived Activity that runs
 * Nav3's [NavDisplay] over the [NavigationController]'s back stack, rendering one
 * full-screen native (Compose) destination at a time. Launched from Flutter by the
 * navigation bridge; **finishes itself when the native stack empties** so the Flutter
 * surface returns to front (single-active-surface rule) — this also guarantees no host
 * instance can sit on a blank/black frame.
 *
 * The "single active surface" rule is **one foreground surface**, not one *live* one:
 * [openFlutterRouteKeepingHost] (the reordering round trip) keeps this Activity alive in
 * the background while a Flutter route is shown over it, so the user can return here with
 * the native stack intact.
 *
 * It registers itself as the controller's [NavigationHost] while attached, performing
 * the two cross-layer actions shared code can't — opening a Flutter route and finishing
 * with a result — by forwarding to the bridge.
 *
 * State retention: the back stack (a `SnapshotStateList`) is rendered directly; Nav3's
 * entry decorators (SaveableStateHolder + ViewModelStore) retain each entry's state
 * across navigation and configuration change. Process death intentionally returns to
 * Flutter's cold start rather than restoring the native stack.
 */
class NavigationHostActivity : ComponentActivity(), NavigationHost {

    private val controller: NavigationController by lazy { getKoin().get() }

    /** Root-shell only: the Activity-scoped wiring handle, detached in onDestroy.
     *  Null for generic (non-root-shell) instances. */
    private var rootShellWiring: RootShellWiring? = null

    /** True when this instance was launched in root-shell mode (the app's home surface).
     *  Read once in [onCreate] from [EXTRA_ROOT_SHELL]; exposed via [isRootShell] so the
     *  deep-link keep-host handoff only fires when the shell owns the foreground surface. */
    private var rootShellMode = false

    override val isRootShell: Boolean get() = rootShellMode

    override fun onCreate(savedInstanceState: Bundle?) {
        // Root-shell mode makes THIS Activity the app's home surface (used only for the
        // bottom-nav shell). Off by default → the generic host path is unchanged. The
        // window setup must run before super.onCreate; the rest of the wiring after it.
        rootShellMode = intent.getBooleanExtra(EXTRA_ROOT_SHELL, false)
        val rootShell = rootShellMode
        super.onCreate(savedInstanceState)
        // Edge-to-edge must run AFTER super.onCreate. super applies the window
        // theme (NormalTheme → Theme.Light.NoTitleBar), which resets
        // windowDrawsSystemBarBackgrounds — so enableEdgeToEdge run *before* super
        // is wiped and the system paints an opaque black status bar. After super
        // it sticks and the pink hero bleeds up behind a transparent bar.
        if (rootShell) RootShellWiring.applyWindow(this)

        // KMP/Koin may have fail-opened (never started). Don't crash resolving the
        // controller — yield to Flutter, which is underneath.
        if (GlobalContext.getOrNull() == null) {
            Log.w(TAG, "KMP/Koin not started; cannot show native host — returning to Flutter")
            finish()
            return
        }

        controller.host = this
        NavigationBridgePlugin.onHostCreated()

        if (rootShell) rootShellWiring = RootShellWiring.attach(this, onExit = ::finishAffinity)

        // Permission system: register Grant's launcher on THIS Activity — SafetyHome (the native
        // permission caller) runs here, so this is the resumed Activity when it requests mic/location.
        // Must run before STARTED (here in onCreate). Detached in onDestroy. (The Flutter MainActivity
        // deliberately does NOT attach — no permission caller runs there.)
        getKoin().get<ActivityAttachable>().attachActivity(this)

        setContent {
            // The Nav3 host + screens live in :shared (SnabbitNavHost renders the registered
            // screens). This Activity supplies the debug flag, the return-to-Flutter exit,
            // and — via LocalRootShellExit — the app-exit action the root-shell bottom-nav
            // reads for its start-tab back (finishAffinity; the same action RootShellWiring
            // uses). Providing it unconditionally is safe: only the root-shell shell reads it.
            CompositionLocalProvider(LocalRootShellExit provides { finishAffinity() }) {
                SnabbitNavHost(
                    controller = controller,
                    screens = getKoin().getAll<NativeScreen>(),
                    isDebug = BuildConfig.DEBUG,
                    onExit = { finish() },
                )
            }
        }
    }

    /**
     * `singleTop` re-launch hook. A re-open (e.g. the bridge's SINGLE_TOP open-then-open) lands
     * here instead of a fresh [onCreate]. This host is **state-driven** — it renders
     * [NavigationController.backStack], which the bridge already updated before launching — so
     * there is nothing to read from the Intent (the host declares no deep-link intent-filters;
     * external deep links land on `MainActivity`/Flutter, not here). Keep `getIntent()` current
     * per Android convention and take no navigation action, so a re-delivery is never silently
     * mishandled.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    // --- NavigationHost: the two cross-layer actions, forwarded to the bridge ---

    override fun openFlutterRoute(route: String, args: Map<String, String>) {
        NavigationBridgePlugin.deliverResult(null) // a handoff has no for-result value
        NavigationBridgePlugin.emitOpenFlutterRoute(route, args)
        finish()
    }

    override fun openFlutterRouteKeepingHost(
        route: String,
        args: Map<String, String>,
        recreateKey: String,
        recreateArgs: Map<String, String>,
    ) {
        // Keep THIS Activity alive: reorder MainActivity to front and push the route.
        // NO finish, NO NEW_TASK/CLEAR_TOP — this screen stays in the task beneath it so
        // the user can return (the reordering round trip). Stash key+args for reclaim.
        NavigationBridgePlugin.rememberHostRecreation(recreateKey, recreateArgs)
        NavigationBridgePlugin.emitPushHostBackedRoute(route, args)
        reorderFlutterToFront()
    }

    /**
     * Reorder MainActivity (Flutter) to front, keeping THIS host alive beneath it.
     * Forward-slide the KMP→Flutter handoff (forward leg of the keep-host round trip):
     * Flutter enters from the right, this host exits to the left. The return leg reverses
     * it (Flutter exits right, host enters from left) so "back" feels like back. Full-width,
     * edge-adjacent anims keep the screen covered during the slide. makeCustomAnimation is
     * the non-deprecated launch-transition API.
     */
    private fun reorderFlutterToFront() {
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            ActivityOptions.makeCustomAnimation(
                this,
                R.anim.nav_enter_from_right,
                R.anim.nav_exit_to_left,
            ).toBundle(),
        )
    }

    override fun onResume() {
        super.onResume()
        // Mark the root shell foreground and drain any held cohort deeplink so it opens ON TOP
        // of the now-foreground shell (not covered by this launch/re-launch).
        NavigationBridgePlugin.onHostResumed(rootShellMode)
    }

    override fun onPause() {
        super.onPause()
        NavigationBridgePlugin.onHostPaused(rootShellMode)
    }

    override fun finishWithResult(result: Map<String, String>) {
        NavigationBridgePlugin.deliverResult(result)
        finish()
    }

    override fun exit() {
        // Finish WITHOUT clearing the back stack first — the current screen stays composed,
        // so the OS close animation slides it out (no white flash from rendering an empty
        // frame). onDestroy's terminal path clears the stack + delivers null to any caller.
        finish()
    }

    override fun onDestroy() {
        // KMP/Koin never started → onCreate bailed before touching `controller`, so don't
        // lazy-init it here (getKoin() would throw). Mirrors the onCreate guard.
        if (GlobalContext.getOrNull() == null) {
            super.onDestroy()
            return
        }
        // Detach the root-shell attachables from THIS destroyed instance (Koin keeps the
        // singletons alive but their launchers must unbind). No-op for generic instances
        // (null). Independent of controller ownership below — it's per-instance.
        rootShellWiring?.detach()
        rootShellWiring = null
        val terminal = isFinishing
        // Always detach + mark host not-alive when THIS instance is destroyed (a
        // non-terminal OS reclaim also lands here) — so `returnToNativeHost` recreates
        // instead of reordering a dead Activity. The terminal teardown is nested here too:
        // only tear down while THIS instance still owns the controller, so a fast
        // close→reopen (old host destroyed after a new one took over) can't wipe the new
        // host's back stack or null-complete its for-result caller.
        if (controller.host === this) {
            // Detach the permission launcher only while THIS instance still owns the host — a fast
            // close→reopen means a new host already re-attached, and we must not release its launcher.
            getKoin().get<ActivityAttachable>().detach()
            controller.host = null
            NavigationBridgePlugin.onHostDestroyed(terminal)
            // Terminal finish (back-out / swiped away / handoff): complete any awaiting
            // for-result caller with null and clear the stack so no stale entries remain.
            if (terminal) {
                NavigationBridgePlugin.deliverResult(null)
                controller.clear()
            }
        }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "NavigationHost"

        /** Intent extra: launch this host in root-shell mode (the app's home surface).
         *  Absent/false → generic host behaviour (opaque surface, finish-on-empty). */
        const val EXTRA_ROOT_SHELL = "root_shell"
    }
}
