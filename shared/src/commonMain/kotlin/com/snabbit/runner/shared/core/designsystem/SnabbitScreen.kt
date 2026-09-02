package com.snabbit.runner.shared.core.designsystem

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.snabbit.design.organisms.SnabbitTopNav
import com.snabbit.design.theme.SnabbitTheme

/**
 * The standard screen scaffold for every Compose Multiplatform screen in this app.
 *
 * It bakes in the chrome every screen needs *identically*, so no screen
 * re-derives it (and no agent gets it wrong). The screen supplies only what is
 * unique to it — the top-nav text, the bottom CTA, and the body.
 *
 * Baked in here:
 * - wraps content in [SnabbitTheme] so DS tokens (`SnabbitTheme.colors/typography/
 *   spacing`) flow to every child,
 * - (font) as of DS 0.15.0 `SnabbitTheme` itself supplies the Outfit family, so every
 *   `SnabbitText` under this scaffold renders in Outfit with no extra wiring.
 * - paints the background with [containerColor] (defaults to `SnabbitTheme.colors.bgPrimary`),
 * - renders a [SnabbitTopNav] (only when [title]/[subtitle]/[onNavigateUp]/
 *   [navigationIcon]/[actions] are provided) that consumes the **status-bar** inset —
 *   edge-to-edge safe on Android 15+/targetSdk 35+, and maps to the top safe-area on
 *   iOS. Pass [navigationIcon] to replace the default back affordance with a custom
 *   leading composable (e.g. a chevron) — it must handle its own click,
 * - hosts an optional [bottomBar] (e.g. a primary CTA) that consumes the
 *   **navigation-bar / gesture** inset (bottom safe-area on iOS),
 * - hosts an optional snackbar driven by [snackbarHostState].
 *
 * The [content] receives the [PaddingValues] that clear the bars — forward them to
 * the body's outermost `Modifier.padding(...)` or `LazyColumn(contentPadding = ...)`.
 *
 * Window insets live here (the app shell), deliberately **not** in the design
 * system: DS components stay presentational and API-symmetric with the React
 * package. See `LanguageScreen` for the golden-path usage.
 */
@Composable
fun SnabbitScreen(
    modifier: Modifier = Modifier,
    title: String? = null,
    subtitle: String? = null,
    onNavigateUp: (() -> Unit)? = null,
    navigationIcon: (@Composable () -> Unit)? = null,
    actions: (@Composable () -> Unit)? = null,
    snackbarHostState: SnackbarHostState? = null,
    bottomBar: (@Composable () -> Unit)? = null,
    containerColor: Color? = null,
    content: @Composable (PaddingValues) -> Unit,
) {
    // Light-only: the Flutter host runs in light theme (MaterialApp sets only
    // `theme: AppTheme.lightTheme`, with no darkTheme/themeMode), so CMP screens
    // must not follow the device's dark-mode setting — otherwise they'd render
    // dark inside an otherwise-light app. Flip this (or thread the host's theme
    // over the bridge) if/when the app adopts dark mode.
    SnabbitTheme(darkTheme = false) {
        Scaffold(
            modifier = modifier,
            containerColor = containerColor ?: SnabbitTheme.colors.bgPrimary,
            topBar = {
                val hasTopNav = title != null || subtitle != null ||
                    onNavigateUp != null || navigationIcon != null || actions != null
                if (hasTopNav) {
                    SnabbitTopNav(
                        modifier = Modifier.windowInsetsPadding(WindowInsets.statusBars),
                        title = title,
                        subtitle = subtitle,
                        onBack = onNavigateUp,
                        showBack = onNavigateUp != null,
                        leading = navigationIcon,
                        actions = actions,
                    )
                }
            },
            snackbarHost = {
                if (snackbarHostState != null) SnackbarHost(snackbarHostState)
            },
            bottomBar = {
                if (bottomBar != null) {
                    // Float the bar above the system gesture / nav bar.
                    Box(Modifier.windowInsetsPadding(WindowInsets.navigationBars)) {
                        bottomBar()
                    }
                }
            },
            content = content,
        )
    }
}
