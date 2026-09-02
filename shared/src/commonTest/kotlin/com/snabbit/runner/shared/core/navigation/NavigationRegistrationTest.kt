package com.snabbit.runner.shared.core.navigation

import com.snabbit.runner.shared.core.navigation.di.nativeDestination
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

private data class RegDestA(val id: String) : Destination
private data class RegDestB(val id: String) : Destination

/**
 * Guards the [nativeDestination] helper's core promise: destinations (and their deep-link
 * mappings) registered across feature modules are ALL collected by `getAll`, instead of the
 * last one silently overriding the rest — the Koin same-type last-write-wins trap the
 * per-registration `named` qualifier exists to prevent. Without this, only one native
 * destination could ever be resolvable.
 */
class NavigationRegistrationTest {

    @AfterTest
    fun tearDown() {
        stopKoin()
    }

    @Test
    fun nativeDestination_multipleRegistrations_areAllCollectedByGetAll() {
        val koin = startKoin {
            modules(
                module {
                    nativeDestination<RegDestA>(key = "a", deeplinkValue = "av") { RegDestA(it["id"].orEmpty()) }
                    nativeDestination<RegDestB>(key = "b", deeplinkValue = "bv") { RegDestB(it["id"].orEmpty()) }
                },
            )
        }.koin

        val factories = koin.getAll<DestinationFactory>()
        val mappings = koin.getAll<DeeplinkMapping>()

        // Both registrations are collected — not just the last one.
        assertEquals(2, factories.size)
        assertEquals(2, mappings.size)

        // Each factory / mapping owns only its own key / value.
        assertNotNull(factories.firstNotNullOfOrNull { it.create("a", mapOf("id" to "1")) })
        assertNotNull(factories.firstNotNullOfOrNull { it.create("b", mapOf("id" to "2")) })
        assertNull(factories.firstNotNullOfOrNull { it.create("unknown", emptyMap()) })
        assertNotNull(mappings.firstNotNullOfOrNull { it.resolve("av", emptyMap()) })
        assertNotNull(mappings.firstNotNullOfOrNull { it.resolve("bv", emptyMap()) })
        assertNull(mappings.firstNotNullOfOrNull { it.resolve("unknown", emptyMap()) })
    }
}
