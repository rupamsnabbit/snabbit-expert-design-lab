package com.snabbit.runner.shared.features.autoot.data.remote.dto

import com.snabbit.runner.shared.features.autoot.domain.model.OtType
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AutoOtDtoTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Test fun decodesFullOffer_andMapsToDomain() {
        val raw = """
            {
              "request_id": 123,
              "ot_type": "END_OT",
              "regular_shift": {"start_time":"2026-02-07T08:00:00+05:30","end_time":"2026-02-07T17:00:00+05:30","ming":600.0},
              "ot_shift": {"start_time":"2026-02-07T08:00:00+05:30","end_time":"2026-02-07T19:00:00+05:30","ming":750.0,"duration":2.0},
              "expiry_duration": 5,
              "status": {"title":"only_today","bg_color":"#FFFFFF","text_color":"#111827"},
              "unexpected_field": "ignored"
            }
        """.trimIndent()

        val d = json.decodeFromString<AutoOtDto>(raw).toDomain()

        assertEquals(123, d.requestId)
        assertEquals(OtType.EndOt, d.otType)
        assertEquals("2026-02-07T08:00:00+05:30", d.otShift?.startTimeIso)
        assertEquals(600.0, d.regularShift?.ming)
        assertEquals(750.0, d.otShift?.ming)
        assertEquals(2, d.otShift?.durationHours) // float 2.0 → Int 2
        assertEquals(5, d.expiryDurationMinutes)
        assertEquals("only_today", d.status?.title)
        assertEquals("#111827", d.status?.textColorHex)
    }

    @Test fun startOtKey_mapsToStartOt() {
        val d = json.decodeFromString<AutoOtDto>("""{"request_id":1,"ot_type":"START_OT"}""").toDomain()
        assertEquals(OtType.StartOt, d.otType)
    }

    @Test fun unknownOrMissingOtType_defaultsToEndOt() {
        assertEquals(OtType.EndOt, json.decodeFromString<AutoOtDto>("""{"ot_type":"WEIRD"}""").toDomain().otType)
        assertEquals(OtType.EndOt, json.decodeFromString<AutoOtDto>("""{"request_id":1}""").toDomain().otType)
    }

    @Test fun emptyObject_hasNullRequestId() {
        assertNull(json.decodeFromString<AutoOtDto>("{}").toDomain().requestId)
    }
}
