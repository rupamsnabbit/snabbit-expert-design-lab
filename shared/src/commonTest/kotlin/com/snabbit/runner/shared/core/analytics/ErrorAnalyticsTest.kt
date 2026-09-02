package com.snabbit.runner.shared.core.analytics

import kotlin.test.Test
import kotlin.test.assertEquals

class ErrorAnalyticsTest {

    @Test
    fun errorScreenLoad_emitsNameAndAllFlags() {
        val fake = FakeAnalyticsTracker()
        ErrorAnalytics(fake).errorScreenLoad(
            errorType = "check_in_failed",
            errorFormat = "bottomsheet",
            errorContext = "check_in",
            isNetworkError = true,
            retryAvailable = true,
            contactSupportAvailable = false,
        )
        val e = fake.events.single()
        assertEquals("error_screen_load", e.name)
        assertEquals("check_in_failed", e.props["error_type"])
        assertEquals("bottomsheet", e.props["error_format"])
        assertEquals("check_in", e.props["error_context"])
        assertEquals(true, e.props["is_network_error"])
        assertEquals(true, e.props["retry_available"])
        assertEquals(false, e.props["contact_support_available"])
    }

    @Test
    fun errorScreenCtaClick_carriesCtaTextTypeAndRetryAttempt() {
        val fake = FakeAnalyticsTracker()
        ErrorAnalytics(fake).errorScreenCtaClick(
            ctaText = "try_again",
            errorType = "auto_ot_failed",
            retryAttempt = 2,
        )
        val e = fake.events.single()
        assertEquals("error_screen_cta_click", e.name)
        assertEquals("try_again", e.props["cta_text"])
        assertEquals("auto_ot_failed", e.props["error_type"])
        assertEquals(2, e.props["retry_attempt"])
    }

    @Test
    fun errorScreenCtaClick_defaultsLeaveTypeAndRetryNull() {
        val fake = FakeAnalyticsTracker()
        ErrorAnalytics(fake).errorScreenCtaClick(ctaText = "dismiss")
        val e = fake.events.single()
        assertEquals("dismiss", e.props["cta_text"])
        // The real tracker's PropertyValue.sanitize drops null keys; the fake keeps them, so the
        // caller-side contract (nullable → omitted downstream) is what we assert here.
        assertEquals(null, e.props["error_type"])
        assertEquals(null, e.props["retry_attempt"])
    }
}
