package com.snabbit.runner.shared.features.shift.presentation.login

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/**
 * Analytics for the shift-login (selfie) funnel — expert-v2 event dictionary
 * (PRD M4.2–4.8). Thin wrapper over [AnalyticsTracker]; event names + property
 * keys are the expert-v2 spec names and are the source of truth here (net-new
 * KMP events — NOT copied from the legacy Dart `capture_image_*` camera events,
 * which stay as-is for non-KMP users).
 *
 * Every event routes to both Mixpanel + CleverTap via `AnalyticsRoutesConfig`.
 *
 * `loginType` is `daily` for the only login path that exists in KMP today; the
 * `first_login` / `no_show` variants land when those screens are built.
 */
class ShiftLoginAnalytics(private val tracker: AnalyticsTracker) {

    /** Selfie intro sheet shown (flow entry). */
    fun introShown(loginType: String) =
        tracker.track(EVENT_INTRO_LOAD, mapOf(PROP_LOGIN_TYPE to loginType))

    /** Intro sheet OK / dismiss → camera. */
    fun introAcknowledged(loginType: String) =
        tracker.track(EVENT_INTRO_CTA, mapOf(PROP_CTA_TEXT to CTA_OKAY, PROP_LOGIN_TYPE to loginType))

    /** Camera opened. */
    fun captureShown(loginType: String) =
        tracker.track(EVENT_CAPTURE_LOAD, mapOf(PROP_LOGIN_TYPE to loginType))

    /** Selfie captured. */
    fun captured(loginType: String) =
        tracker.track(EVENT_CAPTURE_CTA, mapOf(PROP_CTA_TEXT to CTA_CAPTURE, PROP_LOGIN_TYPE to loginType))

    /** Face-match / uniform check result. [failureCodes] empty on pass; the
     *  per-check statuses are derived from the server's `SelfieValidationCode`s.
     *  Spec `liveness_status` is DEFERRED — the server returns no liveness signal in
     *  the code list (see LLD). `failure_codes` is a KMP-only triage extra (not in the
     *  dictionary), kept deliberately for debugging retake failures. */
    fun checkResult(loginType: String, passed: Boolean, failureCodes: List<String>) =
        tracker.track(
            EVENT_CHECK_RESULT,
            mapOf(
                PROP_LOGIN_TYPE to loginType,
                PROP_OVERALL_RESULT to if (passed) RESULT_PASS else RESULT_FAIL,
                PROP_UNIFORM_STATUS to statusFor(CODE_UNIFORM in failureCodes),
                PROP_FACE_MATCH_STATUS to statusFor(
                    CODE_FACE_MISMATCH in failureCodes || CODE_FACE_NOT_DETECTED in failureCodes,
                ),
                PROP_FAILURE_CODES to failureCodes.joinToString(","),
            ),
        )

    private fun statusFor(failed: Boolean) = if (failed) RESULT_FAIL else RESULT_PASS

    /** Retake sheet shown after a validation failure. [failureCodes] → the spec
     *  `failure_reason` enum (`uniform` / `face_match`). */
    fun retakeShown(loginType: String, failureCodes: List<String>) =
        tracker.track(
            EVENT_RETAKE_LOAD,
            mapOf(PROP_LOGIN_TYPE to loginType, PROP_FAILURE_REASON to failureReasonFor(failureCodes)),
        )

    private fun failureReasonFor(codes: List<String>): String = when {
        CODE_UNIFORM in codes -> REASON_UNIFORM
        CODE_FACE_MISMATCH in codes || CODE_FACE_NOT_DETECTED in codes -> REASON_FACE_MATCH
        else -> REASON_UNIFORM
    }

    /** Retake CTA tapped. */
    fun retakeTapped(loginType: String) =
        tracker.track(EVENT_RETAKE_CTA, mapOf(PROP_CTA_TEXT to CTA_RETAKE, PROP_LOGIN_TYPE to loginType))

    /** Login succeeded (selfie passed). */
    fun loginSucceeded(loginType: String, coinsEarned: Int) =
        tracker.track(
            EVENT_LOGIN_SUCCESS,
            mapOf(PROP_LOGIN_TYPE to loginType, PROP_COINS_EARNED to coinsEarned),
        )

    private companion object {
        const val EVENT_INTRO_LOAD = "selfie_intro_bs_load"
        const val EVENT_INTRO_CTA = "selfie_intro_bs_cta_click"
        const val EVENT_CAPTURE_LOAD = "selfie_capture_screen_load"
        const val EVENT_CAPTURE_CTA = "selfie_capture_screen_cta_click"
        const val EVENT_CHECK_RESULT = "selfie_check_result"
        const val EVENT_RETAKE_LOAD = "selfie_retake_bs_load"
        const val EVENT_RETAKE_CTA = "selfie_retake_bs_cta_click"
        const val EVENT_LOGIN_SUCCESS = "login_success_screen_load"

        const val PROP_LOGIN_TYPE = "login_type"
        const val PROP_CTA_TEXT = "cta_text"
        const val PROP_OVERALL_RESULT = "overall_result"
        const val PROP_FAILURE_CODES = "failure_codes"
        const val PROP_UNIFORM_STATUS = "uniform_check_status"
        const val PROP_FACE_MATCH_STATUS = "face_match_status"
        const val CODE_UNIFORM = "UniformNotDetected"
        const val CODE_FACE_MISMATCH = "FaceMismatch"
        const val CODE_FACE_NOT_DETECTED = "FaceNotDetected"
        const val PROP_FAILURE_REASON = "failure_reason"
        const val PROP_COINS_EARNED = "coins_earned"

        const val REASON_UNIFORM = "uniform"
        const val REASON_FACE_MATCH = "face_match"
        const val CTA_OKAY = "okay"
        const val CTA_CAPTURE = "capture"
        const val CTA_RETAKE = "retake_selfie"
        const val RESULT_PASS = "pass"
        const val RESULT_FAIL = "fail"
    }
}
