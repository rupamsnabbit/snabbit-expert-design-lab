package com.snabbit.runner.shared.features.kavach.shield.data.remote

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CurrentStateDtoTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private fun slice(body: String): ShieldWidgetSlice {
        val wd = json.decodeFromString<CurrentStateDto>(body).widgetData as JsonObject
        return json.decodeFromJsonElement(ShieldWidgetSlice.serializer(), wd)
    }

    @Test
    fun parsesEnvelope_andShieldSliceFromWidgetData() {
        val body = """{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{"job_id":650,"snabbit_shield_consent_enabled":true,"snabbit_shield_auto_enabled":true,"unrelated":"x"}}"""
        val dto = json.decodeFromString<CurrentStateDto>(body)
        assertEquals("RUNNER_JOB_IN_PROGRESS", dto.widgetName)
        val s = slice(body)
        assertEquals(true, s.customerConsentEnabled)
        assertEquals(true, s.autoEnabled)
        assertEquals(650, s.jobIdAsInt())
    }

    @Test
    fun jobId_toleratesDoubleAndString() {
        assertEquals(650, slice("""{"widget_data":{"job_id":650.0}}""").jobIdAsInt())
        assertEquals(650, slice("""{"widget_data":{"job_id":"650"}}""").jobIdAsInt())
    }

    @Test
    fun jobId_absent_isNull_andFlagsDefaultFalse() {
        val s = slice("""{"widget_data":{}}""")
        assertNull(s.jobIdAsInt())
        assertEquals(false, s.customerConsentEnabled)
        assertEquals(false, s.autoEnabled)
    }

    @Test
    fun widgetData_absent_isNull() {
        assertTrue(json.decodeFromString<CurrentStateDto>("""{"widget_name":"X"}""").widgetData == null)
    }
}
