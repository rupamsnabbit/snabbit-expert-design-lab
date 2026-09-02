package com.snabbit.runner.shared.core.navigation

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Host-provided "exit the app" action for the root-shell start-tab back press.
 *
 * The bottom-nav shell ([com.snabbit.runner.shared.features.bottomnav]) is the app's home
 * surface; pressing back on its start tab exits the app. That exit is platform-specific
 * (`finishAffinity()` on Android — there is no equivalent on iOS), so instead of the shell
 * reaching a platform Activity directly, the host injects the action through this
 * CompositionLocal. `NavigationHostActivity` provides `{ finishAffinity() }`; an iOS host
 * would provide its own. The default is a **no-op** so a screen composed outside a root
 * shell (or before a host provides it) degrades safely instead of crashing.
 *
 * `staticCompositionLocalOf` because the value is host-stable — it never changes within a
 * composition, so reads shouldn't force recomposition tracking.
 */
val LocalRootShellExit = staticCompositionLocalOf<() -> Unit> { {} }
