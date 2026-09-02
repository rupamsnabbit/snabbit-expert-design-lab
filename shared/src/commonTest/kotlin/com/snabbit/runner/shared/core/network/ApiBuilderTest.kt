package com.snabbit.runner.shared.core.network

import kotlin.test.Test
import kotlin.test.assertEquals

class ApiBuilderTest {

    @Test fun v1_bareReturnsPrefix() {
        assertEquals("api/v1", Api.v1().build())
    }

    @Test fun v2_bareReturnsPrefix() {
        assertEquals("api/v2", Api.v2().build())
    }

    @Test fun version_acceptsCustomString() {
        assertEquals("api/v3", Api.version("v3").build())
    }

    @Test fun add_singleSegment() {
        assertEquals("api/v1/runners", Api.v1().add("runners").build())
    }

    @Test fun add_chainsMultipleSegments() {
        assertEquals(
            "api/v1/runners/me/registration",
            Api.v1().add("runners").add("me").add("registration").build(),
        )
    }

    @Test fun query_singleParameter() {
        assertEquals(
            "api/v1/runners/me?expand=true",
            Api.v1().add("runners").add("me").query("expand", "true").build(),
        )
    }

    @Test fun query_multipleParameters_joinedWithAmpersand() {
        val out = Api.v1()
            .add("search")
            .query("q", "hello")
            .query("limit", "10")
            .build()
        assertEquals("api/v1/search?q=hello&limit=10", out)
    }

    @Test fun query_withoutSegments() {
        assertEquals(
            "api/v1?debug=1",
            Api.v1().query("debug", "1").build(),
        )
    }

    @Test fun toString_matchesBuild() {
        val path = Api.v1().add("foo").query("k", "v")
        assertEquals(path.build(), path.toString())
    }

    @Test fun build_isIdempotent() {
        val path = Api.v1().add("a").add("b").query("k", "v")
        val first = path.build()
        val second = path.build()
        assertEquals(first, second)
    }

    @Test fun add_thenQuery_segmentsAppearBeforeQuestionMark() {
        val out = Api.v1().add("x").add("y").query("k", "v").build()
        // sanity: segments stitched before the '?' regardless of insertion order
        assertEquals("api/v1/x/y?k=v", out)
    }
}
