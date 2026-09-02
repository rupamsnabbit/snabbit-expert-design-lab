package com.snabbit.runner.shared.features.job.delayedcheckin

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics

/**
 * Analytics wrapper for the delayed check-in penalty overlay + job-support
 * funnel. Wraps the core [AnalyticsTracker] — event names and property keys
 * below are copied VERBATIM from the Dart source of truth (read-only
 * parity sources; renaming any of them is a parity break):
 *  - Event names: `lib/utils/tracking_events.dart` ("Delayed check-in
 *    penalty" section).
 *  - Property keys: the `JobLifecycleAnalytics.logEvent(...)` call sites in
 *    `lib/widgets/delayed_checkin/job_support_bottom_sheet.dart`.
 */
class DelayedCheckinAnalytics(private val tracker: AnalyticsTracker) {

    // Cross-cutting X.3 error event, delegated to the canonical helper over the same tracker.
    private val errorAnalytics = ErrorAnalytics(tracker)

    // One popup-viewed event per countdown deadline, not per recomposition /
    // re-push of the same countdown. AwaitingCheckin.dedupeKey is the
    // deadline's epoch-ms; skips the track() call (not just re-tracks with
    // a flag) so a caller retrying after a transient failure elsewhere can't
    // accidentally double count.
    private var lastPopupDedupeKey: Long? = null

    /** The delayed check-in penalty popup became visible. */
    fun popupViewed(dedupeKey: Long, receivedRedCards: Int) {
        if (lastPopupDedupeKey == dedupeKey) return
        lastPopupDedupeKey = dedupeKey
        tracker.track(
            EVENT_POPUP_VIEWED,
            mapOf(PROP_RECEIVED_RED_CARDS to receivedRedCards),
        )
    }

    /** The runner tapped "Call Support Partner". */
    fun ctaClicked() {
        tracker.track(EVENT_CTA_CLICKED)
    }

    /** No `JobSupportConfig` was available (app config fetch never completed / omitted it). */
    fun configMissing() {
        tracker.track(EVENT_CONFIG_MISSING)
    }

    /** The runner picked a disposition option and tapped Submit. */
    fun submitted(dispositionTag: String, runnerJobId: Int) {
        tracker.track(
            EVENT_SUBMITTED,
            mapOf(
                PROP_DISPOSITION_TAG to dispositionTag,
                PROP_RUNNER_JOB_ID to runnerJobId,
            ),
        )
    }

    /** The disposition POST returned 2xx. */
    fun submissionSuccess(dispositionTag: String, statusCode: Int?) {
        tracker.track(
            EVENT_SUBMISSION_SUCCESS,
            mapOf(
                PROP_DISPOSITION_TAG to dispositionTag,
                PROP_STATUS_CODE to statusCode,
            ),
        )
    }

    /** The disposition POST failed (non-2xx or transport error). */
    fun submissionFailed(dispositionTag: String, statusCode: Int?) {
        tracker.track(
            EVENT_SUBMISSION_FAILED,
            mapOf(
                PROP_DISPOSITION_TAG to dispositionTag,
                PROP_STATUS_CODE to statusCode,
            ),
        )
    }

    /** The dialler was launched with the resolved helpline number (non-Ameyo path). */
    fun callInitiated(phone: String) {
        tracker.track(EVENT_CALL_INITIATED, mapOf(PROP_PHONE to phone))
    }

    /** X.3 cross-cutting error event for the submit-failure toast — delegates to [ErrorAnalytics].
     *  The surface is fixed (a `toast` in the `check_in` context); only network-vs-server varies. */
    fun submitErrorScreenLoad(isNetworkError: Boolean) =
        errorAnalytics.errorScreenLoad(
            errorType = "delayed_checkin_failed",
            errorFormat = "toast",
            errorContext = "check_in",
            isNetworkError = isNetworkError,
            retryAvailable = false,
            contactSupportAvailable = false,
        )

    private companion object {
        // Event names — verbatim from lib/utils/tracking_events.dart.
        const val EVENT_POPUP_VIEWED = "delayed_checkin_penalty_popup_viewed"
        const val EVENT_CTA_CLICKED = "job_support_cta_clicked"
        const val EVENT_CONFIG_MISSING = "job_support_config_missing"
        const val EVENT_SUBMITTED = "job_support_submitted"
        const val EVENT_SUBMISSION_SUCCESS = "job_support_submission_success"
        const val EVENT_SUBMISSION_FAILED = "job_support_submission_failed"
        const val EVENT_CALL_INITIATED = "job_support_call_initiated"

        // Property keys — verbatim from job_support_bottom_sheet.dart call sites.
        const val PROP_RECEIVED_RED_CARDS = "received_red_cards"
        const val PROP_DISPOSITION_TAG = "disposition_tag"
        const val PROP_RUNNER_JOB_ID = "runner_job_id"
        const val PROP_STATUS_CODE = "status_code"
        const val PROP_PHONE = "phone"
    }
}
