package com.snabbit.runner.shared.features.kavach.shield.data.gateway

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class StoreShieldProfileGatewayTest {

    private fun store(json: String) = RunnerProfileStore(FakeLogger()).apply { pushProfile(json) }

    @Test
    fun readsSafetyShieldFromPushedProfile() = runTest {
        val gw = StoreShieldProfileGateway(store("""{"user":{"id":1},"safety_shield":{"enabled":true,"consent_given":true,"consent_at":"2026-07-11T00:00:00Z"}}"""))
        assertEquals(true, gw.partnerShieldEnabled())
        assertEquals(true, gw.runnerConsentGiven())
        assertEquals("2026-07-11T00:00:00Z", gw.consentAt())
    }

    @Test
    fun absentSafetyShield_isFailClosed_consentNullPreserved() = runTest {
        val gw = StoreShieldProfileGateway(store("""{"user":{"id":1}}"""))
        assertEquals(false, gw.partnerShieldEnabled())
        assertNull(gw.runnerConsentGiven())   // null != false preserved (still needs the prompt)
    }

    @Test
    fun consentGivenFalse_isDistinctFromNull() = runTest {
        val gw = StoreShieldProfileGateway(store("""{"safety_shield":{"enabled":true,"consent_given":false}}"""))
        assertEquals(false, gw.runnerConsentGiven())
    }

    @Test
    fun nullStore_iosParity_isFailClosed() = runTest {
        // profileModule isn't loaded on iOS → getOrNull() yields null → fail-closed defaults, no crash.
        val gw = StoreShieldProfileGateway(profileStore = null)
        assertEquals(false, gw.partnerShieldEnabled())
        assertNull(gw.runnerConsentGiven())
        assertNull(gw.consentAt())
    }
}
