package com.snabbit.runner.shared.core.navigation

/**
 * Builds a native [Destination] from a string [key] (+ args) supplied by Flutter
 * via the bridge (`openNativeDestination`), or `null` if this factory doesn't own
 * the key.
 *
 * Decentralised, multi-module: each migrated feature contributes one (bound in
 * Koin, collected via `getAll`), so letting Flutter open a native screen never
 * edits a central map. Mirrors [DeeplinkMapping] for the explicit-open path.
 */
fun interface DestinationFactory {
    fun create(key: String, args: Map<String, String?>): Destination?
}
