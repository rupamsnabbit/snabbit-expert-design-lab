package com.snabbit.runner.job

import android.content.Intent
import com.snabbit.runner.shared.features.job.delayedcheckin.presentation.DelayedCheckinStrings
import com.snabbit.runner.shared.features.job.presentation.JobStrings

/**
 * Single source of truth for the i18n labels the native job hosts pass to the
 * KMP [JobStrings]. Both [JobActivity] (foreground) and
 * [com.snabbit.runner.job.overlay.NewJobOverlaySpec] (over-other-apps overlay)
 * build the SAME strings from these extras, so the two surfaces never drift.
 *
 * Labels arrive as Intent extras and fall back to the composeResources labels
 * ([rememberJobStrings]) when absent (the launcher does not always supply them).
 */
object JobScreenExtras {

    const val EXTRA_NEW_JOB_TITLE = "extra_new_job_title"
    const val EXTRA_YOU_WILL_EARN = "extra_you_will_earn"
    const val EXTRA_ACCEPT_IN = "extra_accept_in"
    const val EXTRA_ACCEPT_JOB = "extra_accept_job"
    const val EXTRA_DENY = "extra_deny"
    const val EXTRA_CHECK_IN_BY = "extra_check_in_by"
    // Check-in FOOTER captions (JobStrings.checkIn/checkInByCaps/runningLate). Distinct from the
    // earnings-row `extra_check_in_by`; without these the plain check-in footer showed English
    // ("CHECK IN BY", "RUNNING LATE") while the delayed-checkin footer beside it was localized.
    const val EXTRA_CHECK_IN = "extra_check_in"
    const val EXTRA_CHECK_IN_BY_CAPS = "extra_check_in_by_caps"
    const val EXTRA_RUNNING_LATE = "extra_running_late"
    const val EXTRA_GENERIC_ERROR = "extra_generic_error"
    const val EXTRA_JOB_REASSIGNED = "extra_job_reassigned"
    const val EXTRA_JOB_ACCEPTED = "extra_job_accepted"
    const val EXTRA_JOB_DENIED = "extra_job_denied"
    const val EXTRA_RED_CARD_NUDGE = "extra_red_card_nudge"

    /** The logged-in runner's profile `service_id` (Int) — drives the New-Job Cook/Expert glyph. */
    const val EXTRA_SERVICE_ID = "extra_service_id"

    // Delayed check-in (job_support_bottom_sheet) i18n labels → [DelayedCheckinStrings] via
    // [delayedCheckinStringsFrom]. (These declarations were dropped by the refactor/job-v2 → expert-v2
    // auto-merge while their usages below survived; restored to their original values.)
    const val EXTRA_DC_CALL_SUPPORT_TITLE = "extra_dc_call_support_title"
    const val EXTRA_DC_CALL_SUPPORT_SUBTITLE = "extra_dc_call_support_subtitle"
    const val EXTRA_DC_SUBMIT = "extra_dc_submit"
    const val EXTRA_DC_RUNNING_LATE = "extra_dc_running_late"
    const val EXTRA_DC_CHECK_IN = "extra_dc_check_in"
    const val EXTRA_DC_HELP = "extra_dc_help"
    const val EXTRA_DC_CALL_PARTNER_SUPPORT = "extra_dc_call_partner_support"
    const val EXTRA_DC_CALLBACK_TOAST = "extra_dc_callback_toast"
    const val EXTRA_DC_SUPPORT_DETAILS_NOT_FOUND = "extra_dc_support_details_not_found"
    const val EXTRA_DC_HELPLINE_UNAVAILABLE = "extra_dc_helpline_unavailable"
    const val EXTRA_DC_SUBMIT_FAILED = "extra_dc_submit_failed"
    const val EXTRA_DC_RED_CARD_RECEIVED = "extra_dc_red_card_received"
    const val EXTRA_DC_RED_CARDS_RECEIVED = "extra_dc_red_cards_received"

    /**
     * Overrides the composeResources-resolved [base] with any server-driven i18n labels supplied as
     * [intent] extras. An absent extra keeps the [base] (composeResources) value, so the fallbacks stay
     * localised. Call in composition with `rememberJobStrings()` as [base].
     */
    fun applyOverrides(base: JobStrings, intent: Intent?): JobStrings {
        if (intent == null) return base
        return base.copy(
            newJobTitle = intent.getStringExtra(EXTRA_NEW_JOB_TITLE) ?: base.newJobTitle,
            youWillEarn = intent.getStringExtra(EXTRA_YOU_WILL_EARN) ?: base.youWillEarn,
            acceptIn = intent.getStringExtra(EXTRA_ACCEPT_IN) ?: base.acceptIn,
            acceptJob = intent.getStringExtra(EXTRA_ACCEPT_JOB) ?: base.acceptJob,
            deny = intent.getStringExtra(EXTRA_DENY) ?: base.deny,
            checkInBy = intent.getStringExtra(EXTRA_CHECK_IN_BY) ?: base.checkInBy,
            genericError = intent.getStringExtra(EXTRA_GENERIC_ERROR) ?: base.genericError,
            jobReassigned = intent.getStringExtra(EXTRA_JOB_REASSIGNED) ?: base.jobReassigned,
            jobAccepted = intent.getStringExtra(EXTRA_JOB_ACCEPTED) ?: base.jobAccepted,
            jobDenied = intent.getStringExtra(EXTRA_JOB_DENIED) ?: base.jobDenied,
            redCardNudge = intent.getStringExtra(EXTRA_RED_CARD_NUDGE) ?: base.redCardNudge,
        )
    }

    /** Builds [DelayedCheckinStrings] from [intent]'s extras, defaulting each missing label. */
    fun delayedCheckinStringsFrom(intent: Intent?): DelayedCheckinStrings {
        val defaults = DelayedCheckinStrings()
        if (intent == null) return defaults
        return DelayedCheckinStrings(
            callSupportTitle = intent.getStringExtra(EXTRA_DC_CALL_SUPPORT_TITLE) ?: defaults.callSupportTitle,
            callSupportSubtitle = intent.getStringExtra(EXTRA_DC_CALL_SUPPORT_SUBTITLE) ?: defaults.callSupportSubtitle,
            submit = intent.getStringExtra(EXTRA_DC_SUBMIT) ?: defaults.submit,
            runningLate = intent.getStringExtra(EXTRA_DC_RUNNING_LATE) ?: defaults.runningLate,
            checkIn = intent.getStringExtra(EXTRA_DC_CHECK_IN) ?: defaults.checkIn,
            help = intent.getStringExtra(EXTRA_DC_HELP) ?: defaults.help,
            callPartnerSupport = intent.getStringExtra(EXTRA_DC_CALL_PARTNER_SUPPORT) ?: defaults.callPartnerSupport,
            callbackToast = intent.getStringExtra(EXTRA_DC_CALLBACK_TOAST) ?: defaults.callbackToast,
            supportDetailsNotFound = intent.getStringExtra(EXTRA_DC_SUPPORT_DETAILS_NOT_FOUND)
                ?: defaults.supportDetailsNotFound,
            helplineUnavailable = intent.getStringExtra(EXTRA_DC_HELPLINE_UNAVAILABLE) ?: defaults.helplineUnavailable,
            submitFailed = intent.getStringExtra(EXTRA_DC_SUBMIT_FAILED) ?: defaults.submitFailed,
            redCardReceived = intent.getStringExtra(EXTRA_DC_RED_CARD_RECEIVED) ?: defaults.redCardReceived,
            redCardsReceived = intent.getStringExtra(EXTRA_DC_RED_CARDS_RECEIVED) ?: defaults.redCardsReceived,
        )
    }

    /** The runner's `service_id` from [intent], or null when the extra is absent. */
    fun serviceIdFrom(intent: Intent?): Int? =
        if (intent?.hasExtra(EXTRA_SERVICE_ID) == true) intent.getIntExtra(EXTRA_SERVICE_ID, -1) else null

    /** Copies the job string extras (+ the service_id) from [JobActivity]'s launch [intent] onto [target]. */
    fun copyExtras(source: Intent?, target: Intent) {
        source ?: return
        for (key in EXTRA_KEYS) {
            source.getStringExtra(key)?.let { target.putExtra(key, it) }
        }
        serviceIdFrom(source)?.let { target.putExtra(EXTRA_SERVICE_ID, it) }
    }

    private val EXTRA_KEYS = arrayOf(
        EXTRA_NEW_JOB_TITLE,
        EXTRA_YOU_WILL_EARN,
        EXTRA_ACCEPT_IN,
        EXTRA_ACCEPT_JOB,
        EXTRA_DENY,
        EXTRA_CHECK_IN_BY,
        EXTRA_CHECK_IN,
        EXTRA_CHECK_IN_BY_CAPS,
        EXTRA_RUNNING_LATE,
        EXTRA_GENERIC_ERROR,
        EXTRA_JOB_REASSIGNED,
        EXTRA_JOB_ACCEPTED,
        EXTRA_JOB_DENIED,
        EXTRA_RED_CARD_NUDGE,
        EXTRA_DC_CALL_SUPPORT_TITLE,
        EXTRA_DC_CALL_SUPPORT_SUBTITLE,
        EXTRA_DC_SUBMIT,
        EXTRA_DC_RUNNING_LATE,
        EXTRA_DC_CHECK_IN,
        EXTRA_DC_HELP,
        EXTRA_DC_CALL_PARTNER_SUPPORT,
        EXTRA_DC_CALLBACK_TOAST,
        EXTRA_DC_SUPPORT_DETAILS_NOT_FOUND,
        EXTRA_DC_HELPLINE_UNAVAILABLE,
        EXTRA_DC_SUBMIT_FAILED,
        EXTRA_DC_RED_CARD_RECEIVED,
        EXTRA_DC_RED_CARDS_RECEIVED,
    )
}
