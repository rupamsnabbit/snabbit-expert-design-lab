package com.snabbit.runner.shared.features.kavach.shared.domain

import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeShieldConsentApi
import com.snabbit.runner.shared.features.kavach.FakeShieldProfileGateway
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class KavachConsentGateTest {

    private val profile = FakeShieldProfileGateway()
    private val consent = FakeShieldConsentApi()
    private val analytics = FakeAnalyticsTracker()

    // profileStore null → submit()'s refresh is a no-op; the gate logic under test doesn't need it.
    private fun gate() = KavachConsentGate(profile, consent, null, analytics)

    @Test
    fun shouldShow_false_whenPartnerDisabled() = runTest {
        profile.partnerEnabled = false
        assertFalse(gate().shouldShow())
    }

    @Test
    fun shouldShow_false_whenAlreadyConsented() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true
        assertFalse(gate().shouldShow())
    }

    @Test
    fun shouldShow_true_whenPartnerOn_notConsented_anyJobStage() = runTest {
        // Only partner ∧ !consent — no current_state condition (shows on any job stage).
        profile.partnerEnabled = true; profile.consentGiven = null
        assertTrue(gate().shouldShow())
    }

    @Test
    fun submit_success_tracksConsentGiven() = runTest {
        consent.result = true
        assertTrue(gate().submit())
        assertEquals(1, consent.calls)
        assertTrue(analytics.names().contains("expert_shield_consent_given"))
    }

    @Test
    fun submit_failure_doesNotTrack() = runTest {
        consent.result = false
        assertFalse(gate().submit())
        assertFalse(analytics.names().contains("expert_shield_consent_given"))
    }

    @Test
    fun shouldShow_false_afterSuccessfulSubmit_evenIfProfileNotYetRefreshed() = runTest {
        // Optimistic latch: once the POST succeeds the gate won't re-prompt even if the profile
        // snapshot still reads not-consented (a collapsed/slow refresh) — same instance.
        profile.partnerEnabled = true; profile.consentGiven = null
        val g = gate()
        assertTrue(g.submit())
        assertFalse(g.shouldShow())
    }
}
