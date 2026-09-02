package com.snabbit.runner.shared.core.navigation

/**
 * Maps a resolved deep-link value to a native [Destination], or `null` if this
 * mapping does not own that value.
 *
 * Decentralised, multi-module by design: each migrated feature contributes its
 * own mapping (bound in Koin and collected via `getAll`), so adding a deep-linked
 * native screen never edits a central `when`. The input is the **already
 * resolved** `deep_link_value` (+ params) from the existing deeplink stack
 * (`DeeplinkDispatcher` → Dart `DeeplinkRouter`); this layer does not resolve
 * AppsFlyer OneLink itself — it only routes a resolved value to a destination.
 */
fun interface DeeplinkMapping {
    fun resolve(value: String, params: Map<String, String?>): Destination?
}
