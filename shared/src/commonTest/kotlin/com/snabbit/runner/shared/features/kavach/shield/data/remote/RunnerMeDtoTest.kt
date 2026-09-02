package com.snabbit.runner.shared.features.kavach.shield.data.remote

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RunnerMeDtoTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Test
    fun parsesSafetyShieldAtRoot_ignoringOtherProfileKeys() {
        val body = """{"user":{"id":42,"name":"x"},"safety_shield":{"enabled":true,"consent_given":true,"consent_at":"2026-07-10T09:00:00Z"},"other":123}"""
        val dto = json.decodeFromString<RunnerMeDto>(body)
        val ss = dto.safetyShield
        assertTrue(ss != null)
        assertEquals(true, ss.enabled)
        assertEquals(true, ss.consentGiven)
        assertEquals("2026-07-10T09:00:00Z", ss.consentAt)
    }

    @Test
    fun absentBlock_isNull() {
        assertNull(json.decodeFromString<RunnerMeDto>("""{"user":{"id":1}}""").safetyShield)
    }

    @Test
    fun emptyBlock_appliesDefaults() {
        val ss = json.decodeFromString<RunnerMeDto>("""{"safety_shield":{}}""").safetyShield
        assertTrue(ss != null)
        assertEquals(false, ss.enabled)   // ?? false
        assertNull(ss.consentGiven)       // null (needs-consent), NOT false
        assertNull(ss.consentAt)
    }

    @Test
    fun consentGivenFalse_isPreservedDistinctFromNull() {
        val ss = json.decodeFromString<RunnerMeDto>("""{"safety_shield":{"consent_given":false}}""").safetyShield
        assertEquals(false, ss?.consentGiven)
    }
}
