package com.snabbit.runner.shared.core.navigation

/**
 * Resolves a deep-link value to a native [Destination] by consulting the
 * registered [DeeplinkMapping]s in order, returning the first match (or `null`
 * when no native screen owns the value — the Dart `DeeplinkRouter` then keeps
 * handling it as a Flutter route, unchanged).
 *
 * Stateless and pure — unit-testable with fake mappings.
 */
class DeeplinkResolver(
    private val mappings: List<DeeplinkMapping>,
) {
    fun resolve(value: String, params: Map<String, String?>): Destination? =
        mappings.firstNotNullOfOrNull { it.resolve(value, params) }
}
