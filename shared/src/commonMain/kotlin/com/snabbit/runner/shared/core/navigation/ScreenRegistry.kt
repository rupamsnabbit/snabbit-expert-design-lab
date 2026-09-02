package com.snabbit.runner.shared.core.navigation

import androidx.compose.runtime.LaunchedEffect
import androidx.navigation3.runtime.NavEntry

/**
 * Provides the Compose content for a native [Destination]. Each migrated feature
 * contributes one — returning a [NavEntry] for the destinations it owns, or `null`
 * otherwise — and binds it in Koin (`single { … } bind NativeScreen::class`), so the
 * host collects them via `getAll`. Lives in `commonMain` — Compose/Nav3 glue that is
 * multiplatform now that the Navigation 3 UI artifacts publish iOS binaries (CMP 1.10);
 * the `NavigationController` navigation logic still never references Nav3.
 */
fun interface NativeScreen {
    fun entryFor(destination: Destination): NavEntry<Destination>?
}

/**
 * Resolves a [Destination] to the [NavEntry] that renders it, consulting the
 * registered [NativeScreen]s in order. An unregistered destination is a programming
 * error (a screen navigated somewhere nothing renders): in **debug** we fail fast so
 * the dev sees it immediately; in **release** we log + report a non-fatal and pop the
 * offending entry — the module never renders its own error UI. With no native screens
 * registered the list is empty, which is the correct initial state.
 *
 * [isDebug] is injected (not read from `:app`'s `BuildConfig`) so this stays free of
 * host-module dependencies — the host passes `BuildConfig.DEBUG` in.
 */
class ScreenRegistry(
    private val screens: List<NativeScreen>,
    private val controller: NavigationController,
    private val isDebug: Boolean,
) {
    fun entryFor(destination: Destination): NavEntry<Destination> =
        screens.firstNotNullOfOrNull { it.entryFor(destination) } ?: unresolved(destination)

    private fun unresolved(destination: Destination): NavEntry<Destination> {
        val reason = "No native screen registered for $destination"
        if (isDebug) throw IllegalStateException(reason)
        // Release: log + non-fatal and pop the offending destination — never a
        // broken/blank native screen, never our own error UI.
        return NavEntry(destination) {
            LaunchedEffect(Unit) {
                controller.reportFailure(reason)
                controller.back()
            }
        }
    }
}
