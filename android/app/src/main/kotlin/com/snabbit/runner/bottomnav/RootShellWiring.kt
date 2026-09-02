package com.snabbit.runner.bottomnav

import android.graphics.Color
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import com.snabbit.runner.shared.core.location.LocationAttachable
import com.snabbit.runner.shared.core.permissions.ActivityAttachable
import org.koin.mp.KoinPlatform.getKoin

/**
 * Activity-scoped wiring for **root-shell mode** — when `NavigationHostActivity` is the
 * app's home surface (the bottom-nav shell) rather than a generic native host.
 *
 * Lives in `:app`, not `SnabbitNavHost`, because it is all `ComponentActivity` lifecycle
 * wiring: the two attachables each bind an `ActivityResultLauncher`, which Android only
 * permits **before the Activity is STARTED**. That rules out doing it from composition
 * (`setContent` runs later and recomposes). The Activity calls [applyWindow] before
 * `super.onCreate`, [attach] after it, and holds the handle to [detach] in `onDestroy`.
 *
 * Camera permissions are no longer wired here: the camera resolves a
 * `PermissionManagerCameraController` from Koin (`cameraKoinModule`), which rides the
 * same `PermissionManager` the [ActivityAttachable] below attaches to the Activity.
 *
 * The bottom-nav screen itself is registered in `:shared` at bootstrap
 * (`bottomNavScreenModule`) — this wiring no longer registers any screen.
 */
class RootShellWiring private constructor(
    private val detachers: List<() -> Unit>,
) {
    /** Unbind the attachables from the destroyed Activity instance. Call from `onDestroy`. */
    fun detach() {
        detachers.forEach { it() }
    }

    companion object {
        /**
         * Edge-to-edge with fully transparent bars so the pink home hero bleeds up behind
         * the status/nav bars (Figma 76:31041). `dark(...)` forces light icons over the
         * coloured hero. **Must run AFTER `super.onCreate`** — super applies the window
         * theme (Theme.Light.NoTitleBar), which resets `windowDrawsSystemBarBackgrounds`,
         * so calling this before super gets wiped (opaque black bar). `SnabbitScreen`
         * insets the content via `WindowInsets`, so no further layout work is needed.
         */
        fun applyWindow(activity: ComponentActivity) {
            activity.enableEdgeToEdge(
                statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
                navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            )
        }

        /**
         * Attach the root-shell wiring (lifted from `HomeActivity`) to [activity]: attach the
         * permission + location attachables, and add a back callback that exits the app via
         * [onExit] (e.g. `finishAffinity` — PartnerHome's background services survive and the
         * next cold start re-evaluates the RC flag). **Must be called from `onCreate` before the
         * Activity is STARTED** (the launchers bind on attach). Returns a handle whose [detach]
         * unbinds the attachables in `onDestroy`.
         */
        fun attach(activity: ComponentActivity, onExit: () -> Unit): RootShellWiring {
            val permsAttach = getKoin().get<ActivityAttachable>()
            val locAttach = getKoin().get<LocationAttachable>()
            permsAttach.attachActivity(activity)
            locAttach.attachActivity(activity)
            activity.onBackPressedDispatcher.addCallback(
                activity,
                object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() = onExit()
                },
            )
            return RootShellWiring(
                detachers = listOf({ permsAttach.detach() }, { locAttach.detach() }),
            )
        }
    }
}
