package com.snabbit.runner.shared.core.navigation

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private data class ResolvedDest(val key: String) : Destination

class DeeplinkResolverTest {

    @Test
    fun resolve_returnsFirstMatchingMapping() {
        val resolver = DeeplinkResolver(
            listOf(
                DeeplinkMapping { value, _ -> if (value == "a") ResolvedDest("first") else null },
                DeeplinkMapping { value, _ -> if (value == "a") ResolvedDest("second") else null },
            ),
        )

        assertEquals(ResolvedDest("first"), resolver.resolve("a", emptyMap()))
    }

    @Test
    fun resolve_passesParamsToMapping() {
        val resolver = DeeplinkResolver(
            listOf(
                DeeplinkMapping { value, params ->
                    if (value == "job") ResolvedDest(params["id"] ?: "none") else null
                },
            ),
        )

        assertEquals(ResolvedDest("42"), resolver.resolve("job", mapOf("id" to "42")))
    }

    @Test
    fun resolve_noMatch_returnsNull() {
        val resolver = DeeplinkResolver(
            listOf(DeeplinkMapping { value, _ -> if (value == "a") ResolvedDest("x") else null }),
        )

        assertNull(resolver.resolve("b", emptyMap()))
    }

    @Test
    fun resolve_noMappings_returnsNull() {
        assertNull(DeeplinkResolver(emptyList()).resolve("anything", emptyMap()))
    }
}
