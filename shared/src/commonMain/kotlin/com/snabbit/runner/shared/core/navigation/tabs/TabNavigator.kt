@file:Suppress("ForbiddenImport") // nav-host chrome uses material3.Scaffold — DS ships no nav host (DS_GAPS.md)

package com.snabbit.runner.shared.core.navigation.tabs

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.backhandler.BackHandler

/**
 * Reusable bottom-navigation container: renders one tab's [content] at a time. The
 * consumer supplies the bar UI via [bottomBar] (so it uses the app design system) and the
 * per-tab UI via [content]. Tabs are single-screen — deeper navigation pushes a
 * destination onto the main `NavigationController` (which covers the bar). If a tab ever
 * needs its own internal back stack, reintroduce a per-tab stack in [TabNavigatorState].
 *
 * Retention across tab switches: each tab's [content] is wrapped in a keyed
 * `SaveableStateProvider`, so its `rememberSaveable` state (scroll, etc.) survives a
 * switch away and back; `ViewModel`s obtained via `viewModel { }` are retained through the
 * enclosing nav-entry `ViewModelStore` (the whole shell is a single `NavDisplay` entry).
 *
 * Back: [BackHandler] takes over unconditionally — a non-start tab returns to the start
 * tab (exit-through-home); at the start tab it calls [onExit] to leave the container.
 *
 * [overlay] renders full-screen **above** the tab content and the bar — an always-on
 * layer driven by state, not navigation (e.g. the active-job screen). It composes after
 * the [Scaffold], so a [BackHandler] the overlay registers while visible wins over the
 * tab-level one above (Compose back dispatch is last-registered-first).
 */
@OptIn(ExperimentalComposeUiApi::class) // BackHandler (compose ui-backhandler) is still experimental
@Composable
fun <Tab> TabNavigator(
    state: TabNavigatorState<Tab>,
    onExit: () -> Unit,
    bottomBar: @Composable (current: Tab, onSelect: (Tab) -> Unit) -> Unit,
    content: @Composable (Tab) -> Unit,
    overlay: @Composable (() -> Unit)? = null,
) {
    BackHandler { if (!state.handleBack()) onExit() }

    val stateHolder = rememberSaveableStateHolder()
    Box(Modifier.fillMaxSize()) {
        // No top/side inset: each tab owns its status-bar inset (tabs wrap SnabbitScreen,
        // whose top nav insets itself). This lets full-bleed tabs — the pink home hero —
        // draw behind the transparent status bar instead of the shell reserving that
        // strip. `padding` still carries the bottom-bar height so content clears the tab
        // bar; the bar handles its own navigation-bar inset.
        Scaffold(
            bottomBar = { bottomBar(state.currentTab, state::switchTab) },
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
        ) { padding ->
            Box(Modifier.padding(padding)) {
                // Keyed by tab so each tab's saveable state (scroll, etc.) is retained across switches.
                stateHolder.SaveableStateProvider(state.currentTab.toString()) {
                    content(state.currentTab)
                }
            }
        }
        // Above the tabs + bar. Renders nothing until the overlay decides to show itself.
        overlay?.invoke()
    }
}
