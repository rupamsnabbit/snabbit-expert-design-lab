package com.snabbit.runner.shared.features.seva

import com.snabbit.runner.shared.features.seva.data.remote.dto.SevaNearbyDto
import com.snabbit.runner.shared.features.seva.domain.model.SevaKind
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Decode + `toDomain()` coverage for the `/seva/nearby` DTO. Uses the same
 * lenient Json the data source uses so the DTO defaults (a washroom carries no
 * `photos`/`contact*`) and the array-flatten + kind-tagging are all exercised.
 */
class SevaNearbyMapperTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // Mirrors the real wire contract: userLat/Lng is the origin, dLat/dLng are
    // small deltas off it (as staging sends), radius echo ignored. One washroom
    // (no photos/contact), one resting place (with them).
    private val body = """
        {
          "userLat": 28.6139, "userLng": 77.2090, "radius": 500,
          "washrooms": [
            {"id":"SEVA-W-1042","name":"Cafe Coffee Day - CP","category":"Cafe",
             "dLat":0.0012,"dLng":0.0008,"road":"Barakhamba Road","distance":142}
          ],
          "restingPlaces": [
            {"id":"SEVA-R-0217","name":"Runner Rest Point - CP","category":"Snabbit Hub",
             "dLat":-0.0019,"dLng":-0.0015,"road":"Janpath","distance":235,"type":"resting",
             "photos":["https://x/rest_0217_1.jpg"],"contactName":"Rakesh",
             "contactNumber":"+919812345678","contactDetail":"Ask at reception"}
          ]
        }
    """.trimIndent()

    @Test fun flattensBothArrays_tagsKind_rebasesDeltas() {
        val points = json.decodeFromString<SevaNearbyDto>(body).toDomain()

        assertEquals(2, points.size)
        val washroom = points[0]
        assertEquals("SEVA-W-1042", washroom.id)
        assertEquals("Cafe Coffee Day - CP", washroom.name)
        assertEquals(28.6139 + 0.0012, washroom.lat)   // userLat + dLat
        assertEquals(77.2090 + 0.0008, washroom.lng)   // userLng + dLng
        assertEquals(142, washroom.distanceMeters)
        assertEquals(SevaKind.Washroom, washroom.kind)

        val resting = points[1]
        assertEquals("SEVA-R-0217", resting.id)
        assertEquals(28.6139 + -0.0019, resting.lat)   // negative delta rebases too
        assertEquals(77.2090 + -0.0015, resting.lng)
        assertEquals("Janpath", resting.road)
        assertEquals(SevaKind.Resting, resting.kind)
    }

    @Test fun emptyArrays_produceEmptyList() {
        val points = json.decodeFromString<SevaNearbyDto>(
            """{"userLat":0,"userLng":0,"radius":500,"washrooms":[],"restingPlaces":[]}""",
        ).toDomain()

        assertTrue(points.isEmpty())
    }

    @Test fun missingArrays_defaultToEmpty() {
        // Backend guarantees `[]`, but the DTO defaults guard a sparse body too.
        val points = json.decodeFromString<SevaNearbyDto>("""{"radius":500}""").toDomain()

        assertTrue(points.isEmpty())
    }
}
