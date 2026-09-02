package com.snabbit.runner.shared.core.network

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

/**
 * Pins [redactUrlForLog] — the gate that keeps ids and PII out of logcat.
 *
 * The client's warn/error log lines still write on release builds (debug-level is
 * gated, error breadcrumbs are not), so the redaction — not the log level — is what
 * stops `/api/v1/jobs/8412/start` and `/api/v1/runners/phone_call/+919876543210`
 * from landing in a log any app with READ_LOGS can read. Each case below is a real
 * endpoint from this module.
 */
class LogSafeUrlTest {

    @Test
    fun numeric_job_id_is_redacted_and_the_route_shape_survives() {
        assertEquals(
            "/api/v1/jobs/{redacted}/start",
            redactUrlForLog("/api/v1/jobs/8412/start"),
        )
    }

    @Test
    fun penalty_disposition_id_is_redacted() {
        assertEquals(
            "/api/v1/runner_job/penalty/{redacted}/disposition",
            redactUrlForLog("/api/v1/runner_job/penalty/993041/disposition"),
        )
    }

    @Test
    fun phone_number_is_redacted_raw_and_percent_encoded() {
        // SosApiImpl percent-encodes the leading '+'; CallingDataSourceImpl does not.
        assertEquals(
            "/api/v1/runners/phone_call/{redacted}",
            redactUrlForLog("/api/v1/runners/phone_call/+919876543210"),
        )
        assertEquals(
            "/api/v1/runners/phone_call/{redacted}",
            redactUrlForLog("/api/v1/runners/phone_call/%2B919876543210"),
        )
    }

    @Test
    fun query_string_is_dropped_whole() {
        // job_id / timestamp / type all ride the query on this branch.
        assertEquals(
            "/api/v1/audio/presigned-url?{redacted}",
            redactUrlForLog("/api/v1/audio/presigned-url?job_id=8412&timestamp=1763712000&is_sos=true"),
        )
        assertEquals(
            "/api/v1/runners/me/helpline?{redacted}",
            redactUrlForLog("/api/v1/runners/me/helpline?type=late"),
        )
    }

    @Test
    fun fragment_is_dropped() {
        assertEquals("/api/v1/runners/me", redactUrlForLog("/api/v1/runners/me#anchor"))
    }

    @Test
    fun static_routes_pass_through_untouched() {
        // `v1` has a digit but nowhere near the id threshold — route shape must survive
        // or the log line stops being triage data.
        for (url in STATIC_ROUTES) {
            assertEquals(url, redactUrlForLog(url))
        }
    }

    @Test
    fun uuid_segment_is_redacted_even_when_it_is_mostly_hex_letters() {
        assertEquals(
            "/api/v1/uploads/{redacted}/complete",
            redactUrlForLog("/api/v1/uploads/deadbeef-cafe-babe-face-abcdefabcdef/complete"),
        )
    }

    @Test
    fun absolute_url_keeps_scheme_and_host_but_loses_the_signature() {
        // The rare absolute case (a presigned host). Host is triage-useful; the signed
        // query is not, and must never be logged.
        val redacted = redactUrlForLog("https://bucket.s3.amazonaws.com/audio/8412/clip.m4a?X-Amz-Signature=abc123")
        assertEquals("https://bucket.s3.amazonaws.com/audio/{redacted}/clip.m4a?{redacted}", redacted)
        assertFalse(redacted.contains("X-Amz-Signature"))
    }

    @Test
    fun empty_and_root_inputs_are_stable() {
        assertEquals("", redactUrlForLog(""))
        assertEquals("/", redactUrlForLog("/"))
    }

    private companion object {
        val STATIC_ROUTES = listOf(
            "/api/v1/runners/me",
            "/api/v1/runners/me/app/current_state",
            "/api/v1/runners/me/shift/login",
            "/api/v1/runners/me/emergency_logout/availability",
            "/api/v1/runners/me/provisional_attendance/mark",
            "/api/v1/runners/me/safety-shield/consent",
            "/api/v1/runners/me/home_banners",
            "/api/v1/runners/me/period_leave/availability",
            "/api/v1/audio/upload-complete",
            "/api/v1/jobs/kmp/task_collection",
            "/api/v1/seva/nearby",
        )
    }
}
