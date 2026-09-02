package com.snabbit.runner.shared.core.network

private const val REDACTED = "{redacted}"

/**
 * Four digits in one path segment is an id, not an endpoint name. No static
 * segment in this API carries that many (`v1` is the only one with a digit at
 * all), so the threshold never eats a route name while catching numeric ids,
 * epoch timestamps and phone numbers — raw or percent-encoded.
 */
private const val MIN_ID_DIGITS = 4

private const val UUID_LENGTH = 36

/**
 * Log-safe rendering of a request URL: identifying path segments are replaced with
 * `{redacted}` and the query string is dropped entirely.
 *
 * Why this exists: [SnabbitHttpClientImpl] logs every call, and two of those three
 * log lines are `w()` / `e()`, which keep writing to logcat on release builds (see
 * `DebugLogGate` — silencing error breadcrumbs in production is not an option). The
 * raw URLs carry identifiers and PII:
 *
 *  - `/api/v1/jobs/{jobId}/{action}`
 *  - `/api/v1/runner_job/penalty/{runnerJobId}/disposition`
 *  - `/api/v1/runners/phone_call/{phoneNumber}` — a customer/helpline number
 *  - `/api/v1/runners/me/helpline?type=…`, `…/presigned-url?job_id=…&timestamp=…`
 *
 * What survives is exactly what triage needs — method, endpoint shape, status,
 * duration, error type — e.g. `POST /api/v1/jobs/{redacted}/start -> 500 in 812ms`.
 * Full URLs are still available on debug builds through Chucker, which is wired for
 * the same OkHttp engine and ships only in debug.
 *
 * Absolute URLs need no special case: split on `/`, the scheme and host land in
 * their own segments and pass through unless they themselves look like ids.
 */
internal fun redactUrlForLog(url: String): String {
    val withoutFragment = url.substringBefore('#')
    val path = withoutFragment.substringBefore('?')
    val hadQuery = withoutFragment.length > path.length
    val redactedPath = path
        .split('/')
        .joinToString("/") { segment -> if (isIdentifierSegment(segment)) REDACTED else segment }
    return if (hadQuery) "$redactedPath?$REDACTED" else redactedPath
}

/** True when [segment] looks like an id/phone/token rather than a route name. */
private fun isIdentifierSegment(segment: String): Boolean {
    if (segment.isEmpty()) return false
    if (segment.all { it.isDigit() }) return true
    if (segment.count { it.isDigit() } >= MIN_ID_DIGITS) return true
    // Canonical UUIDs are hex, so one can carry fewer than MIN_ID_DIGITS digits.
    return isUuid(segment)
}

private fun isUuid(segment: String): Boolean =
    segment.length == UUID_LENGTH &&
        segment[8] == '-' &&
        segment[13] == '-' &&
        segment[18] == '-' &&
        segment[23] == '-' &&
        segment.all { it == '-' || it.isDigit() || it.lowercaseChar() in 'a'..'f' }
