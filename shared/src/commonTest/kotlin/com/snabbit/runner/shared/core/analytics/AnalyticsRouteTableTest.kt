package com.snabbit.runner.shared.core.analytics

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AnalyticsRouteTableTest {

    private fun routeTable(
        table: Map<String, Set<String>> = emptyMap(),
        default: Set<String> = emptySet(),
        onUnrouted: (String) -> Unit = {},
    ) = AnalyticsRouteTable(table, default, onUnrouted)

    @Test
    fun listedEvent_routesToUnionOfDefaultAndExplicitOverlay() {
        // default (Mixpanel) MUST still receive an event that also has an
        // explicit AppsFlyer overlay — union, not override.
        val routes = routeTable(
            table = mapOf("otp_verification_success" to setOf(ProviderKeys.APPSFLYER)),
            default = setOf(ProviderKeys.MIXPANEL),
        )

        assertEquals(
            setOf(ProviderKeys.MIXPANEL, ProviderKeys.APPSFLYER),
            routes.destinationsFor("otp_verification_success"),
        )
    }

    @Test
    fun unlistedEvent_routesToDefaultOnly() {
        val routes = routeTable(
            table = mapOf("otp_verification_success" to setOf(ProviderKeys.APPSFLYER)),
            default = setOf(ProviderKeys.MIXPANEL),
        )

        assertEquals(setOf(ProviderKeys.MIXPANEL), routes.destinationsFor("some_other_event"))
    }

    @Test
    fun unlistedEvent_withNonEmptyDefault_doesNotFireOnUnrouted() {
        val unrouted = mutableListOf<String>()
        val routes = routeTable(
            default = setOf(ProviderKeys.MIXPANEL),
            onUnrouted = { unrouted.add(it) },
        )

        routes.destinationsFor("anything")

        assertTrue(unrouted.isEmpty())
    }

    @Test
    fun unroutableEvent_returnsEmptyAndFiresOnUnroutedOnce() {
        val unrouted = mutableListOf<String>()
        val routes = routeTable(
            table = emptyMap(),
            default = emptySet(),
            onUnrouted = { unrouted.add(it) },
        )

        val dest = routes.destinationsFor("orphan_event")

        assertTrue(dest.isEmpty())
        assertEquals(listOf("orphan_event"), unrouted)
    }
}
