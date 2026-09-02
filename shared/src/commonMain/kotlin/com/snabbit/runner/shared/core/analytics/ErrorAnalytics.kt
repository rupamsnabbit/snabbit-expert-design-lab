package com.snabbit.runner.shared.core.analytics

/**
 * Cross-cutting analytics wrapper for the two "X.3 Errors & Loading" events shared across the whole
 * job & shift lifecycle. Lives in `core/analytics` (not a single feature) because the same generic
 * error surface — a full-page state, a bottom sheet, a banner — appears in many features and must
 * emit an identical event shape everywhere. Wraps the core [AnalyticsTracker] so the event names +
 * property keys live in ONE place; mirrors the flat-wrapper convention used by the feature analytics
 * classes ([com.snabbit.runner.shared.features.job.JobAnalytics] etc.).
 *
 * Every name here must also be registered in [AnalyticsRoutesConfig] `SEED.table` or it is dropped;
 * both are already present (`error_screen_load`, `error_screen_cta_click`).
 *
 * Emission conventions (matching the feature wrappers):
 *  - Property values are passed as-is; the tracker's `PropertyValue.sanitize` drops nulls and widens
 *    numbers, so callers may pass nullable values freely and unavailable attributes are simply omitted.
 *  - `error_screen_load` fires ONCE when the error surface first appears — de-dup lives in the caller
 *    (the ViewModel), never here, because this is a Koin single shared across surfaces and per-surface
 *    state would cross-suppress. A re-tapped "Try again" is captured by [errorScreenCtaClick]'s
 *    `retry_attempt`, not a second load event.
 */
class ErrorAnalytics(private val tracker: AnalyticsTracker) {

    /**
     * A generic error / failure surface became visible.
     *
     * @param errorType canonical error identifier (e.g. `check_in_failed`) — see the instrumentation sheet.
     * @param errorFormat how it is shown: `toast` / `banner` / `bottomsheet` / `full_page`.
     * @param errorContext where in the app it occurred (screen/flow name, e.g. `check_in`).
     * @param isNetworkError true when the failure is a connectivity/no-internet error.
     * @param retryAvailable true when the surface offers a retry CTA.
     * @param contactSupportAvailable true when the surface offers a contact-support CTA.
     */
    fun errorScreenLoad(
        errorType: String,
        errorFormat: String,
        errorContext: String,
        isNetworkError: Boolean,
        retryAvailable: Boolean,
        contactSupportAvailable: Boolean,
        /**
         * Caller-supplied context merged into the event — e.g. the job an accept failure belongs to.
         * Deliberately an opaque map rather than named params: this is `core`, shared by surfaces
         * with no job (home, shift login, emergency logout), so a `jobId` here would be a feature
         * concept leaking inward. Caller keys win, so a caller can also override a value above.
         */
        extra: Map<String, Any?> = emptyMap(),
    ) = tracker.track(
        EVENT_ERROR_LOAD,
        mapOf(
            PROP_ERROR_TYPE to errorType,
            PROP_ERROR_FORMAT to errorFormat,
            PROP_ERROR_CONTEXT to errorContext,
            PROP_IS_NETWORK_ERROR to isNetworkError,
            PROP_RETRY_AVAILABLE to retryAvailable,
            PROP_CONTACT_SUPPORT_AVAILABLE to contactSupportAvailable,
        ) + extra,
    )

    /**
     * A CTA on an error surface was tapped (`try_again` / `contact_support` / `dismiss`).
     *
     * @param ctaText which control was tapped.
     * @param errorType the surface's [errorScreenLoad] `error_type`, so the click ties back to the load.
     * @param retryAttempt monotonically-increasing count of `try_again` taps for this surface (null when
     *   the CTA isn't a retry).
     */
    fun errorScreenCtaClick(ctaText: String, errorType: String? = null, retryAttempt: Int? = null) =
        tracker.track(
            EVENT_ERROR_CTA,
            mapOf(PROP_CTA_TEXT to ctaText, PROP_ERROR_TYPE to errorType, PROP_RETRY_ATTEMPT to retryAttempt),
        )

    private companion object {
        // Event names — verbatim from the instrumentation sheet's "X.3 Errors & Loading" rows.
        const val EVENT_ERROR_LOAD = "error_screen_load"
        const val EVENT_ERROR_CTA = "error_screen_cta_click"

        // Property keys — snake_case, verbatim from the sheet's attribute column.
        const val PROP_CTA_TEXT = "cta_text"
        const val PROP_ERROR_TYPE = "error_type"
        const val PROP_ERROR_FORMAT = "error_format"
        const val PROP_ERROR_CONTEXT = "error_context"
        const val PROP_IS_NETWORK_ERROR = "is_network_error"
        const val PROP_RETRY_AVAILABLE = "retry_available"
        const val PROP_CONTACT_SUPPORT_AVAILABLE = "contact_support_available"
        const val PROP_RETRY_ATTEMPT = "retry_attempt"
    }
}
