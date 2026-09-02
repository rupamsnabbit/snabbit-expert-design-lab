package com.snabbit.runner.shared.core.navigation

/**
 * Marker for a native (Compose) navigation target — the base type of everything
 * on the native back stack ([NavigationController.backStack]).
 *
 * Intentionally an **open** interface (not `sealed`) so any feature, in its own
 * package/module, can contribute destinations — this is what makes navigation
 * decentralised and multi-module. Each concrete destination is a `@Serializable`
 * data class/object (forward-looking — for a possible future restore / iOS phase):
 *
 * ```kotlin
 * @Serializable data class JobDetail(val jobId: String) : Destination
 * @Serializable data object Home : Destination
 * ```
 *
 * Keep destinations **pure data** (no platform types, no UI) so `commonMain`
 * stays iOS-compilable and the back stack is unit-testable. Mapping a destination
 * to the Composable that renders it lives in the host's screen registry, not here.
 *
 * Flutter-owned screens are deliberately not modelled here: during the migration
 * the Dart router still owns Flutter routes, so the native back stack holds native
 * destinations only. Returning to Flutter is simply an empty back stack (the host
 * finishes itself), not a back-stack entry.
 */
interface Destination
