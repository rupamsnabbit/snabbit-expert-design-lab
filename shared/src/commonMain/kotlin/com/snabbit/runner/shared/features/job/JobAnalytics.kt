package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics

/**
 * Analytics wrapper for the KMP job lifecycle (New-Job → Check-in → In-Progress → Checkout →
 * Completed). Wraps the core [AnalyticsTracker] so the job module's event names + property keys live in
 * ONE place — mirroring [com.snabbit.runner.shared.features.job.delayedcheckin.DelayedCheckinAnalytics].
 * Names come from the "Expert App — Job Lifecycle" instrumentation sheet (sections S1/S2/S3/S5 + the X
 * cross-cutting events); every name here must also be registered in
 * [com.snabbit.runner.shared.core.analytics.AnalyticsRoutesConfig] `SEED.table` or it is dropped.
 *
 * Emission conventions (matching the wrapper it mirrors):
 *  - Property values are passed as-is; the tracker's `PropertyValue.sanitize` drops nulls and widens
 *    numbers, so callers may pass nullable values freely and unavailable attributes are simply omitted
 *    (never faked).
 *  - The four `*_screen_load` stage events are driven off the `uiState` stream (which re-emits); the
 *    caller ([com.snabbit.runner.shared.features.job.presentation.JobViewModel]) de-dups on stage entry
 *    so each fires once per stage, not per recomposition. De-dup is NOT held here because this is a Koin
 *    single shared across the two new-job hosts — per-host state would cross-suppress. Sheet/sub-flow
 *    loads fire from discrete intents, so they need no de-dup.
 *  - Boolean attributes are sent as booleans (Mixpanel-native); list attributes are comma-joined strings
 *    (the sanitizer would otherwise `toString()` a `List` with a warning).
 */
class JobAnalytics(private val tracker: AnalyticsTracker) {

    // The generic error events (`error_screen_load` / `error_screen_cta_click`) are cross-cutting, so
    // their canonical shape lives in core [ErrorAnalytics]; the job wrappers below delegate to it.
    // Constructed from the same injected tracker (stateless wrapper) — existing call sites + tests are
    // therefore unaffected by the promotion to core.
    private val errorAnalytics = ErrorAnalytics(tracker)

    /**
     * The job every event below is stamped with, set by the ViewModel as the lifecycle advances
     * (mirrors the Dart `JobLifecycleAnalytics.setActiveJob`).
     *
     * Job events carried NO job id at all, which made per-job analysis impossible: a
     * `mqtt_post_action_fallback` could be tied to a runner but never to the job it stalled, so
     * confirming a reported failure meant reconstructing it from backend access logs one 15-minute
     * window at a time. One property removes that entire step.
     *
     * Safe as shared mutable state on this Koin single: both new-job hosts (in-app + draw-over)
     * observe the same lifecycle stream and therefore agree on the current job.
     */
    private var activeJobId: Int? = null

    /** Point subsequent events at [jobId] (null clears — events then simply omit the property). */
    fun setActiveJob(jobId: Int?) {
        activeJobId = jobId
    }

    /**
     * Every event in this wrapper goes through here so the job stamp can't be forgotten at a call
     * site. A null id omits the key entirely rather than sending a placeholder — the tracker's
     * sanitizer drops nulls, so "unknown" and "absent" stay distinguishable downstream.
     * NOTE: the delegated `error_screen_*` events route via core [ErrorAnalytics] and are not
     * stamped; they are cross-cutting and not job-scoped.
     */
    private fun track(name: String, properties: Map<String, Any?> = emptyMap()) =
        // Ambient first so an explicit property of the same name always wins — the stamp must never
        // silently overwrite something a call site deliberately passed.
        tracker.track(name, mapOf(PROP_JOB_ID to activeJobId) + properties)

    // ── S1 — Job Acceptance ────────────────────────────────────────────────────

    /** The new-job accept screen entered (full-screen in-app or the draw-over overlay). */
    fun acceptanceScreenLoad(
        displayMode: String,
        jobType: String,
        denyAvailable: Boolean,
        earnTotal: Int?,
        earningsLineItems: List<String>,
        checkInByTime: String?,
        acceptCountdownSeconds: Int?,
        penaltyNudgeVisible: Boolean,
    ) = track(
        EVENT_ACCEPTANCE_LOAD,
        mapOf(
            PROP_DISPLAY_MODE to displayMode,
            PROP_JOB_TYPE to jobType,
            PROP_DENY_AVAILABLE to denyAvailable,
            PROP_EARN_TOTAL to earnTotal,
            PROP_EARNINGS_LINE_ITEMS to earningsLineItems.joinToStringOrNull(),
            PROP_CHECK_IN_BY_TIME to checkInByTime,
            PROP_ACCEPT_COUNTDOWN to acceptCountdownSeconds,
            PROP_PENALTY_NUDGE_VISIBLE to penaltyNudgeVisible,
        ),
    )

    /** A CTA on the accept screen (`accept_job` / `deny` / `expand_earnings`). */
    fun acceptanceScreenCtaClick(ctaText: String, jobType: String) =
        track(EVENT_ACCEPTANCE_CTA, mapOf(PROP_CTA_TEXT to ctaText, PROP_JOB_TYPE to jobType))

    /** The regular / long-distance deny confirmation sheet opened. */
    fun denyConfirmationLoad(jobEarnings: Int?) =
        track(EVENT_DENY_CONFIRMATION_LOAD, mapOf(PROP_JOB_EARNINGS to jobEarnings))

    /** A CTA on the deny confirmation sheet (`accept_job` / `deny`). */
    fun denyConfirmationCtaClick(ctaText: String) =
        track(EVENT_DENY_CONFIRMATION_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** The last-hour deny confirmation sheet opened (deny here logs the shift out). */
    fun lastHourDenyConfirmationLoad(earningsMissed: Int?, jobEarnings: Int?) =
        track(
            EVENT_LAST_HOUR_DENY_LOAD,
            mapOf(PROP_EARNINGS_MISSED to earningsMissed, PROP_JOB_EARNINGS to jobEarnings),
        )

    /** A CTA on the last-hour deny confirmation sheet (`accept_job` / `logout`). */
    fun lastHourDenyConfirmationCtaClick(ctaText: String) =
        track(EVENT_LAST_HOUR_DENY_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    // The accept timer expiring fires from BOTH new-job hosts' VMs (in-app + draw-over), so de-dup per
    // OFFER HERE — this wrapper is a shared single, so one guard covers both. Keyed on the offer
    // (`"<jobId>:<notifiedAtIso>"`), not the bare id, so a genuinely re-offered job still fires while a
    // repeat of the SAME offer is suppressed. (Unlike the *_screen_load de-dup, which is per-VM because
    // display_mode legitimately differs across the two hosts.)
    private val firedNotAccepted = mutableSetOf<String>()

    /** The accept timer expired with no accept/deny — the offer lapsed ("JOB NOT ACCEPTED"). De-dups on
     *  [offerKey] (the per-offer discriminator) across both hosts; a genuine re-offer fires again. */
    fun jobNotAccepted(offerKey: String, penaltyAmount: Int?) {
        if (!firedNotAccepted.add(offerKey)) return
        track(EVENT_JOB_NOT_ACCEPTED, mapOf(PROP_PENALTY_AMOUNT to penaltyAmount))
    }

    // ── S2 — Check-in ───────────────────────────────────────────────────────────

    /**
     * The check-in screen entered (en-route / at-location, one state-driven screen).
     * NOTE: `customer_name` / `address` are intentionally NOT sent — shipping customer PII to a
     * third-party analytics vendor is a data-exposure risk (S1). Re-add only via a non-identifying
     * `customer_id` after a privacy sign-off.
     */
    fun checkInScreenLoad(
        checkInState: String,
        earnTotal: Int?,
        checkInBonus: Int?,
        checkInBonusForfeited: Boolean,
        timerState: String?,
    ) = track(
        EVENT_CHECK_IN_LOAD,
        mapOf(
            PROP_CHECK_IN_STATE to checkInState,
            PROP_EARN_TOTAL to earnTotal,
            PROP_CHECK_IN_BONUS to checkInBonus,
            PROP_CHECK_IN_BONUS_FORFEITED to checkInBonusForfeited,
            PROP_TIMER_STATE to timerState,
        ),
    )

    /** A CTA on the check-in screen (`check_in` / `map` / `call` / `chat` / `expand_earnings` / …). */
    fun checkInScreenCtaClick(ctaText: String) =
        track(EVENT_CHECK_IN_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** The check-in OTP entry sheet opened. */
    fun checkInOtpLoad() = track(EVENT_CHECK_IN_OTP_LOAD)

    /**
     * A CTA on the check-in OTP sheet (`start_job` with a verification status, or `no_otp`).
     * [errorReason] carries the coarse failure class on a `failed` attempt (`JobActionError.errorKind()`
     * — `network` / `server` / `generic` / …) so a wrong OTP is separable from a dropped connection in
     * the funnel; null (dropped by the sanitizer) on success or a non-submit CTA (ECPO-1059).
     */
    fun checkInOtpCtaClick(
        ctaText: String,
        otpVerificationStatus: String? = null,
        errorReason: String? = null,
    ) = track(
        EVENT_CHECK_IN_OTP_CTA,
        mapOf(
            PROP_CTA_TEXT to ctaText,
            PROP_OTP_VERIFICATION_STATUS to otpVerificationStatus,
            PROP_ERROR_REASON to errorReason,
        ),
    )

    /** The no-OTP phone-number fallback sheet opened. */
    fun noOtpFallbackLoad() = track(EVENT_NO_OTP_FALLBACK_LOAD)

    /**
     * A CTA on the no-OTP fallback sheet (`start_job` with a phone-verification status, or
     * `use_otp_instead`). [errorReason] carries the coarse failure class on a `failed` attempt
     * (see [checkInOtpCtaClick]); null on success or a non-submit CTA (ECPO-1059).
     */
    fun noOtpFallbackCtaClick(
        ctaText: String,
        phoneVerificationStatus: String? = null,
        errorReason: String? = null,
    ) = track(
        EVENT_NO_OTP_FALLBACK_CTA,
        mapOf(
            PROP_CTA_TEXT to ctaText,
            PROP_PHONE_VERIFICATION_STATUS to phoneVerificationStatus,
            PROP_ERROR_REASON to errorReason,
        ),
    )

    /** The "Job Started" confirmation celebration became visible. */
    fun jobStartedLoad() = track(EVENT_JOB_STARTED_LOAD)

    /** A CTA on the "Job Started" confirmation (`ok`). */
    fun jobStartedCtaClick(ctaText: String) =
        track(EVENT_JOB_STARTED_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    // ── S3 — In-progress → Checkout ──────────────────────────────────────────────

    /** The job-in-progress screen entered (duration timer running). */
    fun inProgressScreenLoad(
        timerState: String?,
        timeLeftSeconds: Int?,
        jobDurationMinutes: Int?,
        extended: Boolean,
        extensionMinutes: Int?,
        completeJobEnabled: Boolean,
        jobTiming: String?,
        customerPreferencesShown: Boolean,
    ) = track(
        EVENT_IN_PROGRESS_LOAD,
        // customer_name intentionally NOT sent (PII — S1; see checkInScreenLoad).
        mapOf(
            PROP_TIMER_STATE to timerState,
            PROP_TIME_LEFT to timeLeftSeconds,
            PROP_JOB_DURATION_MINUTES to jobDurationMinutes,
            PROP_EXTENDED to extended,
            PROP_EXTENSION_MINUTES to extensionMinutes,
            PROP_COMPLETE_JOB_ENABLED to completeJobEnabled,
            PROP_JOB_TIMING to jobTiming,
            PROP_CUSTOMER_PREFERENCES_SHOWN to customerPreferencesShown,
        ),
    )

    /** A CTA on the job-in-progress screen (`complete_job` / `chat` / `call` / …). */
    fun inProgressScreenCtaClick(ctaText: String) =
        track(EVENT_IN_PROGRESS_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** The end-of-job offer-help nudge (checkout campaign step) became visible. */
    fun offerHelpNudgeLoad() = track(EVENT_OFFER_HELP_NUDGE_LOAD)

    /** A CTA on the offer-help nudge (`okay`). */
    fun offerHelpNudgeCtaClick(ctaText: String) =
        track(EVENT_OFFER_HELP_NUDGE_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** The checkout OTP entry sheet opened. */
    fun checkoutOtpLoad() = track(EVENT_CHECKOUT_OTP_LOAD)

    /**
     * A CTA on the checkout OTP sheet (`end_job` with a verification status). [errorReason] carries the
     * coarse failure class on a `failed` attempt (see [checkInOtpCtaClick]); null on success (ECPO-1059).
     */
    fun checkoutOtpCtaClick(
        ctaText: String,
        otpVerificationStatus: String? = null,
        errorReason: String? = null,
    ) = track(
        EVENT_CHECKOUT_OTP_CTA,
        mapOf(
            PROP_CTA_TEXT to ctaText,
            PROP_OTP_VERIFICATION_STATUS to otpVerificationStatus,
            PROP_ERROR_REASON to errorReason,
        ),
    )

    /** Auto-checkout fallback fired — the runner never checked out and the duration + grace elapsed. */
    fun autoCheckout(autoCheckoutAfterMinutes: Int?) =
        track(EVENT_AUTO_CHECKOUT, mapOf(PROP_AUTO_CHECKOUT_AFTER_MINUTES to autoCheckoutAfterMinutes))

    // ── S5 — Post-completion ─────────────────────────────────────────────────────

    /** The post-checkout "What tasks did you do?" sheet opened (tasks fetched). */
    fun tasksDoneLoad(tasksShown: List<String>) =
        track(EVENT_TASKS_DONE_LOAD, mapOf(PROP_TASKS_SHOWN to tasksShown.joinToStringOrNull()))

    /** A CTA on the tasks-done sheet (`submit` with the selected task keys + count). */
    fun tasksDoneCtaClick(ctaText: String, tasksSelected: List<String>) =
        track(
            EVENT_TASKS_DONE_CTA,
            mapOf(
                PROP_CTA_TEXT to ctaText,
                PROP_TASKS_SELECTED to tasksSelected.joinToStringOrNull(),
                PROP_TASKS_SELECTED_COUNT to tasksSelected.size,
            ),
        )

    /** The job-completed summary + rate-the-customer screen entered. (Name already routed in SEED.) */
    fun completedScreenLoad(earnTotal: Int?, earningsLineItems: List<String>) =
        track(
            EVENT_COMPLETED_LOAD,
            mapOf(
                PROP_EARN_TOTAL to earnTotal,
                PROP_EARNINGS_LINE_ITEMS to earningsLineItems.joinToStringOrNull(),
            ),
        )

    /**
     * A CTA on the job-completed screen (`rate_customer` with a [rating], `block_customer`, or
     * `ready_for_next_job` with a [returnType]).
     */
    fun completedScreenCtaClick(ctaText: String, rating: String? = null, returnType: String? = null) =
        track(
            EVENT_COMPLETED_CTA,
            mapOf(PROP_CTA_TEXT to ctaText, PROP_RATING to rating, PROP_RETURN_TYPE to returnType),
        )

    /** The block-customer confirmation sheet opened (revealed after a low rating). Uses the opaque
     *  `customer_id`, never the customer's name (PII — S1). */
    fun blockConfirmationLoad(customerId: Int?, triggerRating: String?) =
        track(
            EVENT_BLOCK_CONFIRMATION_LOAD,
            mapOf(PROP_CUSTOMER_ID to customerId, PROP_TRIGGER_RATING to triggerRating),
        )

    /** A CTA on the block-customer confirmation sheet (`yes` / `no`). */
    fun blockConfirmationCtaClick(ctaText: String) =
        track(EVENT_BLOCK_CONFIRMATION_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    // ── Old-flow parity — outcomes / dismiss / unblock the new taxonomy didn't cover ──
    // These reuse the legacy Flutter event names (already in the SEED table with their legacy routing),
    // so the KMP flow continues those existing event streams for the migrated cohort.

    /** The accept flow ran (API returned, any result) — legacy `accept_job_button_clicked`. */
    fun acceptJobButtonClicked() =
        track(EVENT_ACCEPT_JOB_BUTTON_CLICKED, mapOf(PROP_ACTION to "accept job button click"))

    /**
     * The accept finished, however it finished — the event the accept flow never had.
     *
     * `accept_job_button_clicked` fires after the API call *regardless of result*, so success and
     * failure are indistinguishable and nothing records latency. Worse, "the accept succeeded but
     * the screen never advanced" was measurable only via `check_in_screen_load`, which requires the
     * screen to actually render — a backgrounded app looks identical to a stuck one. This fires from
     * the ViewModel, so it is unaffected by whether anything is on screen.
     *
     * **NOT one event per accept.** An accept that times out and *then* recovers emits twice —
     * `timeout` at the threshold, then `state_transition` when the envelope finally lands, carrying
     * the full elapsed time. That second event is the point (it says a stall un-stalled, and when),
     * but it means counting accepts by counting these events over-counts. Count `resolved_by =
     * state_transition + api_error` for one-per-accept, or filter to a single value.
     *
     * **`timeout` means SLOW, not broken.** It is a threshold crossing, not a wedge detector — a
     * healthy-but-late accept trips it and then reports `state_transition` when it lands. The wedge
     * is a `timeout` with **no** following `state_transition` for the same `job_id`.
     *
     * @param resolvedBy what ended the in-flight state, and the only outcome dimension: it is
     *   `state_transition` (the job left New — the healthy path), `api_error` (the POST failed;
     *   see [errorKind]), or `timeout` (still in-flight at [TIMEOUT_MS] — reported only, the spinner
     *   is NOT cleared in this change). A separate success/failure field would be derivable from
     *   this one and could contradict it, so there isn't one.
     * @param msSinceTap milliseconds from the Accept tap to this resolution.
     * @param errorKind coarse failure class (`reassigned` / `server` / `network` / `generic`), so a
     *   benign 409 race is separable from a real failure without plumbing status codes into domain.
     * @param isNetworkError whether the request never got an HTTP answer. Genuinely computed —
     *   `error_screen_load` hardcoded this to `false`, which made "no internet" invisible.
     */
    fun acceptResolved(
        resolvedBy: String,
        msSinceTap: Long,
        errorKind: String? = null,
        isNetworkError: Boolean? = null,
        /**
         * The job this accept was FOR. Passed explicitly (it wins over the ambient stamp in [track])
         * because the ambient id is not this accept's by the time either call site fires:
         * [setActiveJob] runs at the top of the envelope collector and the transition branch at the
         * bottom of the same tick, so `state_transition` would take the id of the envelope that
         * replaced it — null when the job moves to a non-job widget — and a late `api_error` for a
         * superseded job would be filed under whichever job took the store.
         */
        jobId: Int? = null,
    ) = track(
        EVENT_ACCEPT_RESOLVED,
        mapOf(
            PROP_RESOLVED_BY to resolvedBy,
            PROP_MS_SINCE_TAP to msSinceTap,
            PROP_ERROR_KIND to errorKind,
            PROP_IS_NETWORK_ERROR to isNetworkError,
        ) + (jobId?.let { mapOf(PROP_JOB_ID to it) } ?: emptyMap()),
    )

    /** The deny flow ran (API returned, any result) — legacy `deny_job_button_clicked`. */
    fun denyJobButtonClicked() =
        track(EVENT_DENY_JOB_BUTTON_CLICKED, mapOf(PROP_ACTION to "deny job button click"))

    /** The `update_customer_rating` POST succeeded — legacy `runner_rated_the_customer`. */
    fun runnerRatedTheCustomer() =
        track(EVENT_RUNNER_RATED_THE_CUSTOMER, mapOf(PROP_ACTION to "runner rated the customer"))

    /** The check-in OTP sheet was dismissed — legacy `check_in_otp_modal_dismissed`. */
    fun checkInOtpModalDismissed() = track(EVENT_CHECK_IN_OTP_MODAL_DISMISSED)

    /** Unblock tapped on the Completed block card — legacy `rating_customer_unblock_cta`. */
    fun ratingCustomerUnblockCta(unblockedCustomerId: Int?) =
        track(EVENT_RATING_CUSTOMER_UNBLOCK_CTA, mapOf(PROP_UNBLOCKED_CUSTOMER_ID to unblockedCustomerId))

    // ── X — Cross-cutting ─────────────────────────────────────────────────────────

    /** A top action-panel item tapped (`help` / `sos`), tagged with the current job [screenName]. */
    fun topPanelCtaClick(ctaText: String, screenName: String) =
        track(EVENT_TOP_PANEL_CTA, mapOf(PROP_CTA_TEXT to ctaText, PROP_SCREEN_NAME to screenName))

    /** The "Listen" (TTS) speaker was tapped on [screenName]; [playCountOnScreen] = 1 first play, 2+ on
     *  replays. `audio_language` is omitted (not plumbed from the localization store yet). */
    fun audioPlayed(screenName: String, playCountOnScreen: Int) =
        track(
            EVENT_AUDIO_PLAYED,
            mapOf(PROP_SCREEN_NAME to screenName, PROP_PLAY_COUNT_ON_SCREEN to playCountOnScreen),
        )

    /** A localized in-progress voice cue was played (ECPO-982). [cue] = `half_time` / `ten_minutes`
     *  (KMP-timed) or `auto_checkout` (Dart push); [language] is the runner's resolved audio language,
     *  or null when unknown (the sanitizer drops the null property). */
    fun jobInProgressAudioPlayed(cue: String, language: String?, durationMinutes: Int?) =
        track(
            EVENT_JOB_IN_PROGRESS_AUDIO_PLAYED,
            mapOf(
                PROP_CUE to cue,
                PROP_AUDIO_LANGUAGE to language,
                PROP_JOB_DURATION_MINUTES to durationMinutes,
            ),
        )

    /** System back pressed on a job screen (back is otherwise consumed while a job is active). */
    fun jobBackPressed(screenName: String) =
        track(EVENT_JOB_BACK_PRESSED, mapOf(PROP_SCREEN_NAME to screenName))

    /** A generic error / failure surface shown on a job screen — delegates to core [ErrorAnalytics]. */
    fun errorScreenLoad(
        errorType: String,
        errorFormat: String,
        errorContext: String,
        isNetworkError: Boolean,
        retryAvailable: Boolean,
        contactSupportAvailable: Boolean,
        /** Overrides the ambient job for a specific action's failure — see [acceptResolved]. */
        jobId: Int? = null,
    ) = errorAnalytics.errorScreenLoad(
        errorType = errorType,
        errorFormat = errorFormat,
        errorContext = errorContext,
        isNetworkError = isNetworkError,
        retryAvailable = retryAvailable,
        contactSupportAvailable = contactSupportAvailable,
        // This one DELEGATES to core ErrorAnalytics rather than going through [track], so it never
        // received the ambient job stamp at all — job errors were landing unattributed.
        extra = mapOf(PROP_JOB_ID to (jobId ?: activeJobId)),
    )

    /** A CTA on an error surface (`try_again` / `contact_support` / `dismiss`) — e.g. the check-in
     *  location-mismatch bottom sheet's "Try again". [retryAttempt] counts try-again taps. Delegates
     *  to core [ErrorAnalytics]. */
    fun errorScreenCtaClick(ctaText: String, errorType: String? = null, retryAttempt: Int? = null) =
        errorAnalytics.errorScreenCtaClick(ctaText = ctaText, errorType = errorType, retryAttempt = retryAttempt)

    // ── User-profile properties (unrouted `people.set`) ────────────────────────────

    /** People-property: the runner's current blocked-customer count (Mixpanel `people.set`, absolute —
     *  the caller passes the up-to-date total, so this is idempotent, unlike an increment). */
    fun setBlockedCustomers(count: Int) = tracker.setUserProperty(PROP_BLOCKED_CUSTOMERS, count)

    /** Comma-joins a list for a single property value; null when empty so the sanitizer drops the key. */
    private fun List<String>.joinToStringOrNull(): String? = if (isEmpty()) null else joinToString(",")

    companion object {
        // Canonical `screen_name` values (top_panel_cta_click etc.), reused by callers.
        const val SCREEN_ACCEPTANCE = "job_acceptance"
        const val SCREEN_CHECK_IN = "check_in"
        const val SCREEN_IN_PROGRESS = "job_in_progress"
        const val SCREEN_COMPLETED = "job_completed"

        // Event names — verbatim from the Job Lifecycle instrumentation sheet.
        private const val EVENT_ACCEPTANCE_LOAD = "job_acceptance_screen_load"
        private const val EVENT_ACCEPTANCE_CTA = "job_acceptance_screen_cta_click"
        private const val EVENT_DENY_CONFIRMATION_LOAD = "deny_confirmation_bs_load"
        private const val EVENT_DENY_CONFIRMATION_CTA = "deny_confirmation_bs_cta_click"
        private const val EVENT_LAST_HOUR_DENY_LOAD = "last_hour_deny_confirmation_bs_load"
        private const val EVENT_LAST_HOUR_DENY_CTA = "last_hour_deny_confirmation_bs_cta_click"
        private const val EVENT_CHECK_IN_LOAD = "check_in_screen_load"
        private const val EVENT_CHECK_IN_CTA = "check_in_screen_cta_click"
        private const val EVENT_CHECK_IN_OTP_LOAD = "check_in_otp_bs_load"
        private const val EVENT_CHECK_IN_OTP_CTA = "check_in_otp_bs_cta_click"
        private const val EVENT_NO_OTP_FALLBACK_LOAD = "no_otp_fallback_bs_load"
        private const val EVENT_NO_OTP_FALLBACK_CTA = "no_otp_fallback_bs_cta_click"
        private const val EVENT_JOB_STARTED_LOAD = "job_started_bs_load"
        private const val EVENT_JOB_STARTED_CTA = "job_started_bs_cta_click"
        private const val EVENT_IN_PROGRESS_LOAD = "job_in_progress_screen_load"
        private const val EVENT_IN_PROGRESS_CTA = "job_in_progress_screen_cta_click"
        private const val EVENT_OFFER_HELP_NUDGE_LOAD = "offer_help_nudge_bs_load"
        private const val EVENT_OFFER_HELP_NUDGE_CTA = "offer_help_nudge_bs_cta_click"
        private const val EVENT_CHECKOUT_OTP_LOAD = "checkout_otp_bs_load"
        private const val EVENT_CHECKOUT_OTP_CTA = "checkout_otp_bs_cta_click"
        private const val EVENT_TASKS_DONE_LOAD = "tasks_done_bs_load"
        private const val EVENT_TASKS_DONE_CTA = "tasks_done_bs_cta_click"
        private const val EVENT_COMPLETED_LOAD = "job_completed_screen_load"
        private const val EVENT_COMPLETED_CTA = "job_completed_screen_cta_click"
        private const val EVENT_BLOCK_CONFIRMATION_LOAD = "block_confirmation_bs_load"
        private const val EVENT_BLOCK_CONFIRMATION_CTA = "block_confirmation_bs_cta_click"
        private const val EVENT_ACCEPT_JOB_BUTTON_CLICKED = "accept_job_button_clicked"
        private const val EVENT_DENY_JOB_BUTTON_CLICKED = "deny_job_button_clicked"
        private const val EVENT_RUNNER_RATED_THE_CUSTOMER = "runner_rated_the_customer"
        private const val EVENT_CHECK_IN_OTP_MODAL_DISMISSED = "check_in_otp_modal_dismissed"
        private const val EVENT_RATING_CUSTOMER_UNBLOCK_CTA = "rating_customer_unblock_cta"
        private const val EVENT_JOB_NOT_ACCEPTED = "job_not_accepted"
        private const val EVENT_AUTO_CHECKOUT = "auto_checkout"
        private const val EVENT_TOP_PANEL_CTA = "top_panel_cta_click"
        private const val EVENT_AUDIO_PLAYED = "audio_played"
        private const val EVENT_JOB_IN_PROGRESS_AUDIO_PLAYED = "job_in_progress_audio_played"
        private const val EVENT_JOB_BACK_PRESSED = "job_back_pressed"
        private const val EVENT_ACCEPT_RESOLVED = "job_accept_resolved"

        /**
         * How long the accept may stay in-flight before [acceptResolved] reports it as a `timeout`.
         * Sized off measurement, not taste: of the accepts whose realtime deadline already lapsed,
         * ~64% reached the check-in screen within 10s of that, and stretching the wait to five
         * minutes recovered only ~2% more. So past roughly this point, waiting almost never helps —
         * which is exactly what makes it a useful reporting threshold. It stays *reporting-only*
         * here; whether it should also clear the spinner is the decision this event exists to
         * inform.
         */
        const val TIMEOUT_MS = 10_000L

        // Property keys — snake_case, verbatim from the sheet's attribute column.
        private const val PROP_JOB_ID = "job_id"
        private const val PROP_RESOLVED_BY = "resolved_by"
        private const val PROP_MS_SINCE_TAP = "ms_since_tap"
        private const val PROP_ERROR_KIND = "error_kind"
        private const val PROP_IS_NETWORK_ERROR = "is_network_error"
        private const val PROP_CTA_TEXT = "cta_text"
        private const val PROP_ACTION = "action"
        private const val PROP_UNBLOCKED_CUSTOMER_ID = "unblocked_customer_id"
        private const val PROP_DISPLAY_MODE = "display_mode"
        private const val PROP_JOB_TYPE = "job_type"
        private const val PROP_DENY_AVAILABLE = "deny_available"
        private const val PROP_EARN_TOTAL = "earn_total"
        private const val PROP_EARNINGS_LINE_ITEMS = "earnings_line_items"
        private const val PROP_CHECK_IN_BY_TIME = "check_in_by_time"
        private const val PROP_ACCEPT_COUNTDOWN = "accept_countdown"
        private const val PROP_PENALTY_NUDGE_VISIBLE = "penalty_nudge_visible"
        private const val PROP_JOB_EARNINGS = "job_earnings"
        private const val PROP_EARNINGS_MISSED = "earnings_missed"
        private const val PROP_CHECK_IN_STATE = "check_in_state"
        private const val PROP_CHECK_IN_BONUS = "check_in_bonus"
        private const val PROP_CHECK_IN_BONUS_FORFEITED = "check_in_bonus_forfeited"
        private const val PROP_TIMER_STATE = "timer_state"
        private const val PROP_CUSTOMER_ID = "customer_id"
        private const val PROP_OTP_VERIFICATION_STATUS = "otp_verification_status"
        private const val PROP_ERROR_REASON = "error_reason"
        private const val PROP_PHONE_VERIFICATION_STATUS = "phone_verification_status"
        private const val PROP_TIME_LEFT = "time_left"
        private const val PROP_JOB_DURATION_MINUTES = "job_duration_minutes"
        private const val PROP_EXTENDED = "extended"
        private const val PROP_EXTENSION_MINUTES = "extension_minutes"
        private const val PROP_COMPLETE_JOB_ENABLED = "complete_job_enabled"
        private const val PROP_JOB_TIMING = "job_timing"
        private const val PROP_CUSTOMER_PREFERENCES_SHOWN = "customer_preferences_shown"
        private const val PROP_TASKS_SHOWN = "tasks_shown"
        private const val PROP_TASKS_SELECTED = "tasks_selected"
        private const val PROP_TASKS_SELECTED_COUNT = "tasks_selected_count"
        private const val PROP_RATING = "rating"
        private const val PROP_RETURN_TYPE = "return_type"
        private const val PROP_TRIGGER_RATING = "trigger_rating"
        private const val PROP_SCREEN_NAME = "screen_name"
        private const val PROP_PENALTY_AMOUNT = "penalty_amount"
        private const val PROP_AUTO_CHECKOUT_AFTER_MINUTES = "auto_checkout_after_minutes"
        private const val PROP_PLAY_COUNT_ON_SCREEN = "play_count_on_screen"
        private const val PROP_CUE = "cue"
        private const val PROP_AUDIO_LANGUAGE = "audio_language"
        private const val PROP_BLOCKED_CUSTOMERS = "blocked_customers"
    }
}
