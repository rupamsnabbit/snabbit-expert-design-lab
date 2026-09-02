package com.snabbit.runner.shared.core.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.navigation3.rememberViewModelStoreNavEntryDecorator
import androidx.navigation3.runtime.rememberSaveableStateHolderNavEntryDecorator
import androidx.navigation3.scene.DialogSceneStrategy
import androidx.navigation3.scene.SinglePaneSceneStrategy
import androidx.navigation3.ui.NavDisplay
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.navigation.scene.BottomSheetSceneStrategy

/**
 * The reusable Nav3 host for the KMP navigation module: runs [NavDisplay] over the
 * [NavigationController]'s back stack, rendering one native (Compose) [Destination] at a
 * time. Extracted from the `:app` host Activity so the host lives once, in `:shared` —
 * any platform host (the Android host Activity today, a `ComposeUIViewController` on iOS
 * tomorrow) just calls this composable instead of re-declaring the decorators + scene
 * strategies.
 *
 * Lives in `commonMain`: [NavDisplay], the scene strategies and the ViewModelStore
 * decorator come from the Compose Multiplatform Navigation 3 artifacts (the JetBrains
 * `org.jetbrains.androidx.*` fork of `navigation3-ui` / `lifecycle-viewmodel-navigation3`),
 * which publish iOS binaries as of CMP 1.10; `navigation3-runtime` was already fully
 * multiplatform. On Android the fork delegates to the same Google impl, so behaviour is
 * unchanged.
 *
 * State retention: the back stack (a `SnapshotStateList`) is rendered directly; the entry
 * decorators (SaveableStateHolder + ViewModelStore) retain each entry's state across
 * navigation and configuration change.
 *
 * @param screens the registered [NativeScreen]s (collected via Koin `getAll`).
 * @param isDebug forwarded to [ScreenRegistry] — fail-fast on an unresolved destination in
 *   debug, log-and-pop in release. The host passes `BuildConfig.DEBUG`.
 * @param onExit invoked when the back stack empties (return to Flutter) — the host finishes.
 */
@Composable
fun SnabbitNavHost(
    controller: NavigationController,
    screens: List<NativeScreen>,
    isDebug: Boolean,
    onExit: () -> Unit,
) {
    val screenRegistry = remember(screens, controller, isDebug) {
        ScreenRegistry(screens, controller, isDebug)
    }

    // The app is light-only (Flutter uses AppTheme.lightTheme), but the host's window
    // theme (@style/NormalTheme) is DayNight — in dark mode the window is black. SnabbitTheme
    // (darkTheme = false) forces the light DS scheme, and the opaque Surface fill stops the
    // dark window bleeding through native screens (text/icons stay readable).
    SnabbitTheme(darkTheme = false) {
        Surface(modifier = Modifier.fillMaxSize()) {
            val backStack = controller.backStack
            when {
                backStack.isNotEmpty() -> NavDisplay(
                    backStack = backStack,
                    onBack = { controller.back() },
                    entryDecorators = listOf(
                        // SaveableStateHolder first (rememberSaveable + state retention
                        // across navigation / config change), then a per-entry ViewModelStore.
                        rememberSaveableStateHolderNavEntryDecorator(),
                        rememberViewModelStoreNavEntryDecorator(),
                    ),
                    // Overlay strategies first; single-pane is the full-screen fallback.
                    sceneStrategies = listOf(
                        BottomSheetSceneStrategy<Destination>(),
                        DialogSceneStrategy<Destination>(),
                        SinglePaneSceneStrategy<Destination>(),
                    ),
                    entryProvider = { key -> screenRegistry.entryFor(key) },
                )

                // Empty stack = return to Flutter. The host finishes so no instance ever
                // sits on a blank frame (also catches any stranded instance).
                else -> LaunchedEffect(Unit) { onExit() }
            }
        }
    }
}
