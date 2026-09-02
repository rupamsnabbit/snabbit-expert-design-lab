package com.snabbit.runner.shared.features.job.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.job_accept_in
import com.snabbit.runner.shared.resources.job_accept_job
import com.snabbit.runner.shared.resources.job_accepted
import com.snabbit.runner.shared.resources.job_attendance_absent
import com.snabbit.runner.shared.resources.job_attendance_present
import com.snabbit.runner.shared.resources.job_auto_checkout_callout
import com.snabbit.runner.shared.resources.job_auto_checkout_label
import com.snabbit.runner.shared.resources.job_call_action
import com.snabbit.runner.shared.resources.job_chat_action
import com.snabbit.runner.shared.resources.job_check_in
import com.snabbit.runner.shared.resources.job_check_in_by
import com.snabbit.runner.shared.resources.job_check_in_by_caps
import com.snabbit.runner.shared.resources.job_check_in_location_error_subtitle
import com.snabbit.runner.shared.resources.job_check_in_location_error_title
import com.snabbit.runner.shared.resources.job_complete_job
import com.snabbit.runner.shared.resources.job_completed_title
import com.snabbit.runner.shared.resources.job_confirm_action
import com.snabbit.runner.shared.resources.job_customer_blocked_toast
import com.snabbit.runner.shared.resources.job_customer_fallback
import com.snabbit.runner.shared.resources.job_customer_preferences_title
import com.snabbit.runner.shared.resources.job_deny
import com.snabbit.runner.shared.resources.job_deny_lose_earnings_title
import com.snabbit.runner.shared.resources.job_deny_miss_earnings_title
import com.snabbit.runner.shared.resources.job_denied
import com.snabbit.runner.shared.resources.job_duration_label
import com.snabbit.runner.shared.resources.job_end_campaign_title
import com.snabbit.runner.shared.resources.job_end_job
import com.snabbit.runner.shared.resources.job_enter_otp_title
import com.snabbit.runner.shared.resources.job_enter_otp_to_end_job_title
import com.snabbit.runner.shared.resources.job_enter_phone_title
import com.snabbit.runner.shared.resources.job_extended_callout
import com.snabbit.runner.shared.resources.job_generic_error
import com.snabbit.runner.shared.resources.job_in_progress_title
import com.snabbit.runner.shared.resources.job_listen
import com.snabbit.runner.shared.resources.job_logged_out_subtitle
import com.snabbit.runner.shared.resources.job_logged_out_title
import com.snabbit.runner.shared.resources.job_logout
import com.snabbit.runner.shared.resources.job_map_action
import com.snabbit.runner.shared.resources.job_mark_attendance_title
import com.snabbit.runner.shared.resources.job_network_error
import com.snabbit.runner.shared.resources.job_new_job_title
import com.snabbit.runner.shared.resources.job_next_job_ready_callout
import com.snabbit.runner.shared.resources.job_no_otp
import com.snabbit.runner.shared.resources.job_ok_action
import com.snabbit.runner.shared.resources.job_okay_action
import com.snabbit.runner.shared.resources.job_otp_helper
import com.snabbit.runner.shared.resources.job_otp_incorrect
import com.snabbit.runner.shared.resources.job_phone_helper
import com.snabbit.runner.shared.resources.job_phone_mismatch
import com.snabbit.runner.shared.resources.job_ready_for_next_job
import com.snabbit.runner.shared.resources.job_reassigned
import com.snabbit.runner.shared.resources.job_red_card_nudge
import com.snabbit.runner.shared.resources.job_running_late
import com.snabbit.runner.shared.resources.job_select_task_hint
import com.snabbit.runner.shared.resources.job_start_job
import com.snabbit.runner.shared.resources.job_started
import com.snabbit.runner.shared.resources.job_tasks_done_title
import com.snabbit.runner.shared.resources.job_time_left
import com.snabbit.runner.shared.resources.job_time_up_callout
import com.snabbit.runner.shared.resources.job_timing_label
import com.snabbit.runner.shared.resources.job_try_again
import com.snabbit.runner.shared.resources.job_use_otp_instead
import com.snabbit.runner.shared.resources.job_you_earned
import com.snabbit.runner.shared.resources.job_you_will_earn
import org.jetbrains.compose.resources.getString
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * UI text for the Job screen. Two-tier i18n (PR #452, like `CameraStrings`): the English **fallbacks**
 * live in `composeResources` (per-locale `values-*` folders later) and are resolved by
 * [rememberJobStrings]; the host can still **override** any label at runtime by passing the app's
 * server-driven i18n value into the corresponding field. A caller wanting the fallbacks uses
 * `rememberJobStrings()`; a caller with server labels passes them as named arguments.
 *
 * The transient action messages (accept/deny/error toasts, inline errors) are emitted by the
 * ViewModels as semantic [JobMessage]s and resolved here via [resolve] — so the strings never live
 * on the ViewModels.
 */
data class JobStrings(
    /** Top-nav header pills (Figma 1:28063). */
    val topNavHelpLabel: String = "Help",
    val topNavSosLabel: String = "SOS",
    /** i18n key `new_job_assigned` (header). */
    val newJobTitle: String,
    /** i18n key `you_will_earn`. */
    val youWillEarn: String,
    /** i18n key `accept_job_cap` (footer caption). */
    val acceptIn: String,
    /** i18n key `accept_job`. */
    val acceptJob: String,
    /** i18n key `deny`. */
    val deny: String,
    /** i18n key `check_in_by` (earnings highlighted row label). */
    val checkInBy: String,
    /** i18n key `check_in` — check-in stage primary CTA (opens the OTP sheet). */
    val checkIn: String,
    /** i18n key `check_in_by_caps` — check-in footer caption prefix ("CHECK IN BY 7:45 PM"). */
    val checkInByCaps: String,
    /** i18n key `getting_late_capital` — check-in footer caption once the deadline passed. */
    val runningLate: String,
    /** Navigation-card quick-action label — Map. */
    val mapAction: String,
    /** Navigation-card quick-action label — Call. */
    val callAction: String,
    /** Navigation-card quick-action label — Chat. */
    val chatAction: String,
    /** i18n key `listen` — navigation-card read-aloud pill. */
    val listen: String,
    /** Navigation-card fallback when `customer_name` is absent. */
    val customerFallback: String,
    /** i18n key `enter_otp_to_start_job` — check-in OTP sheet title. */
    val enterOtpTitle: String,
    /** i18n key `ask_customer_for_otp` — helper under the OTP cells. */
    val otpHelper: String,
    /** i18n key `start_job` — check-in OTP sheet primary CTA. */
    val startJob: String,
    /** i18n key `no_otp` — in-sheet no-OTP check-in fallback CTA. */
    val noOtp: String,
    /** i18n key `otp_incorrect_try_again` — wrong-OTP inline error. */
    val otpIncorrect: String,
    /** i18n key `enter_customer_phone_number` — no-OTP (phone) check-in sheet title. */
    val enterPhoneTitle: String,
    /** Helper under the phone field on the no-OTP check-in sheet. */
    val phoneHelper: String,
    /** i18n key `use_otp_instead` — switch from the phone sheet back to the OTP sheet. */
    val useOtpInstead: String,
    /** i18n key `check_in_phone_number_error_title` — phone-mismatch inline error. */
    val phoneMismatch: String,
    /** i18n key `check_in_location_error_title` — phone check-in "not at the job location" error title. */
    val checkInLocationErrorTitle: String,
    /** i18n key `check_in_location_error_subtitle` — the "not at location" error supporting line. */
    val checkInLocationErrorSubtitle: String,
    /** i18n key `try_again` — the "not at location" error retry CTA. */
    val tryAgain: String,
    /** Generic action-failure message. */
    val genericError: String,
    /** i18n key `common.network_error` — no-connection copy for a transport failure (ECPO-1059). */
    val networkError: String,
    /** i18n key `job_reassigned` (HTTP 409 on accept/deny). */
    val jobReassigned: String,
    /** Success toast copy after a 2xx `accept_job` (placeholder pending Figma copy). */
    val jobAccepted: String,
    /** Success toast copy after a 2xx `deny_job` (placeholder pending Figma copy). */
    val jobDenied: String,
    /** Red-card penalty nudge copy on the new-job accept screen (Figma node 1535:11788). */
    val redCardNudge: String,

    // ── Deny / logout / next-day-attendance flow (JobDenyFlowSheet) ──
    /**
     * i18n key `denial_loss_earnings` — deny/logout warning title. `{amount}` is replaced with
     * the formatted money the runner forfeits (Figma nodes 14:11821 / 98:36589).
     */
    val denyMissEarningsTitle: String,
    /** Deny warning title when no explicit loss amount is available (Figma placeholder copy). */
    val denyLoseEarningsTitle: String,
    /** i18n key `logout` — last-hour deny secondary CTA (denying forces a logout). */
    val logout: String,
    /** i18n key `mark_tomorrows_attendance` — next-working-day attendance step title (Figma 132:38277). */
    val markAttendanceTitle: String,
    /** i18n key `present` — attendance "I'm coming" CTA. */
    val attendancePresent: String,
    /** i18n key `absent` — attendance "I'm not coming" CTA. */
    val attendanceAbsent: String,
    /** i18n key `thank_you!` — logged-out success title. */
    val loggedOutTitle: String,
    /** i18n key `you_have_been_logged_out_successfully` — logged-out success subtitle. */
    val loggedOutSubtitle: String,

    // ── Successful check-in (SuccessfulCheckIn) ──
    /** i18n key `job_started` — successful-check-in title under the green check (Figma 132:*). */
    val jobStarted: String,
    /** i18n key `okay` / `ok` — successful-check-in primary CTA (auto-advances on the progress fill). */
    val okAction: String,

    // ── Checkout OTP (CheckoutSheet) ──
    /** i18n key `enter_otp_to_end_job` — checkout OTP sheet title (Figma 10:13893). */
    val enterOtpToEndJobTitle: String,
    /** i18n key `end_job` — checkout OTP sheet primary CTA. */
    val endJob: String,

    // ── Post-job-end campaign (PostJobEndCampaign) ──
    /** i18n key `ask_if_you_can_help` — post-job-end campaign title (Figma 10:14765). */
    val jobEndCampaignTitle: String,
    /** i18n key `okay` — post-job-end campaign auto-advancing CTA. */
    val okayAction: String,

    // ── In-progress (InProgressContent) ──
    /** i18n key `job_in_progress` — the in-progress job-state header. */
    val jobInProgressTitle: String,
    /** i18n key `complete_job` — the in-progress footer CTA. */
    val completeJob: String,
    /** i18n key `time_left` — the pill-progress label while the job runs. */
    val timeLeft: String,
    /** i18n key `auto_checkout_in` — the pill label once past end-time (auto-checkout window). */
    val autoCheckoutLabel: String,
    /** i18n key `job_timing` — the job-details "Job Timing" row label. */
    val jobTimingLabel: String,
    /** i18n key `duration` — the job-details "Duration" row label. */
    val durationLabel: String,
    /** i18n key `customer_preferences` — the preferences card heading. */
    val customerPreferencesTitle: String,
    /** i18n key `time_up` — status callout in the final minute (matches Flutter "Time is up!"). */
    val timeUpCallout: String,
    /** i18n key `auto_checkout_warning` — status callout during the auto-checkout window. */
    val autoCheckoutCallout: String,
    /** i18n key `next_job_ready` — status callout when the next job is ready. */
    val nextJobReadyCallout: String,
    /** i18n key `job_extended` — status tooltip when the job duration was extended (`{duration}` → e.g. "15 min"). */
    val jobExtendedCallout: String,

    // ── Post-checkout house-tasks sheet (HouseTasksSheetContent — ECPO-528) ──
    // Also reuses `tryAgain` (fetch-error retry) and `genericError` (fetch/submit failure copy) above.
    /** i18n key `choose_jobs_done_now` — the house-tasks sheet title. */
    val tasksDoneTitle: String,
    /** i18n key `confirm` — the house-tasks confirm CTA (a plain button, not auto-advancing). */
    val confirmAction: String,
    /** i18n key `select_at_least_one_task` — inline hint when Confirm is tapped with nothing selected. */
    val selectTaskHint: String,

    // ── Completed (CompletedContent) ──
    /** i18n key `job_completed` — the completed job-state header. */
    val jobCompletedTitle: String,
    /**
     * i18n key `calculating_your_earnings` — completed-screen placeholder title shown while the backend
     * hasn't computed the payout yet (the envelope sends `payout_info` null at checkout; a later
     * `current_state` poll fills it in and the real earnings card replaces this).
     */
    val calculatingEarningsTitle: String = "Calculating your earnings",
    /** i18n key `check_on_earnings_page_later` — the calculating-earnings placeholder subtitle. */
    val calculatingEarningsSubtitle: String = "You can check this on earnings page later",
    val youEarned: String,
    /** i18n key `ready_for_next_job` — the completed-screen footer CTA. */
    val readyForNextJob: String,
    /** i18n key `customer_blocked` — the post-block success toast copy. */
    val customerBlockedToast: String,
    /** i18n key `common.checkin_pill` — templated collapsed-summary pill ("Check In by {time}");
     * localizes with correct word order (Hindi puts {time} first), unlike the bare [checkInBy]. */
    val checkInByPill: String = "Check In by {time}",
)

/**
 * [JobStrings] with every label defaulted to its `composeResources` fallback. Each parameter defaults
 * to a `stringResource(...)` lookup, so passing nothing yields the fully-localised fallbacks and
 * passing a named argument overrides just that label with a server-driven value.
 */
@Composable
fun rememberJobStrings(
    newJobTitle: String = stringResource(Res.string.job_new_job_title),
    youWillEarn: String = stringResource(Res.string.job_you_will_earn),
    acceptIn: String = stringResource(Res.string.job_accept_in),
    acceptJob: String = stringResource(Res.string.job_accept_job),
    deny: String = stringResource(Res.string.job_deny),
    checkInBy: String = stringResource(Res.string.job_check_in_by),
    checkIn: String = stringResource(Res.string.job_check_in),
    checkInByCaps: String = stringResource(Res.string.job_check_in_by_caps),
    runningLate: String = stringResource(Res.string.job_running_late),
    mapAction: String = stringResource(Res.string.job_map_action),
    callAction: String = stringResource(Res.string.job_call_action),
    chatAction: String = stringResource(Res.string.job_chat_action),
    listen: String = stringResource(Res.string.job_listen),
    customerFallback: String = stringResource(Res.string.job_customer_fallback),
    enterOtpTitle: String = stringResource(Res.string.job_enter_otp_title),
    otpHelper: String = stringResource(Res.string.job_otp_helper),
    startJob: String = stringResource(Res.string.job_start_job),
    noOtp: String = stringResource(Res.string.job_no_otp),
    otpIncorrect: String = stringResource(Res.string.job_otp_incorrect),
    enterPhoneTitle: String = stringResource(Res.string.job_enter_phone_title),
    phoneHelper: String = stringResource(Res.string.job_phone_helper),
    useOtpInstead: String = stringResource(Res.string.job_use_otp_instead),
    phoneMismatch: String = stringResource(Res.string.job_phone_mismatch),
    checkInLocationErrorTitle: String = stringResource(Res.string.job_check_in_location_error_title),
    checkInLocationErrorSubtitle: String = stringResource(Res.string.job_check_in_location_error_subtitle),
    tryAgain: String = stringResource(Res.string.job_try_again),
    genericError: String = stringResource(Res.string.job_generic_error),
    networkError: String = stringResource(Res.string.job_network_error),
    jobReassigned: String = stringResource(Res.string.job_reassigned),
    jobAccepted: String = stringResource(Res.string.job_accepted),
    jobDenied: String = stringResource(Res.string.job_denied),
    redCardNudge: String = stringResource(Res.string.job_red_card_nudge),
    denyMissEarningsTitle: String = stringResource(Res.string.job_deny_miss_earnings_title),
    denyLoseEarningsTitle: String = stringResource(Res.string.job_deny_lose_earnings_title),
    logout: String = stringResource(Res.string.job_logout),
    markAttendanceTitle: String = stringResource(Res.string.job_mark_attendance_title),
    attendancePresent: String = stringResource(Res.string.job_attendance_present),
    attendanceAbsent: String = stringResource(Res.string.job_attendance_absent),
    loggedOutTitle: String = stringResource(Res.string.job_logged_out_title),
    loggedOutSubtitle: String = stringResource(Res.string.job_logged_out_subtitle),
    jobStarted: String = stringResource(Res.string.job_started),
    okAction: String = stringResource(Res.string.job_ok_action),
    enterOtpToEndJobTitle: String = stringResource(Res.string.job_enter_otp_to_end_job_title),
    endJob: String = stringResource(Res.string.job_end_job),
    jobEndCampaignTitle: String = stringResource(Res.string.job_end_campaign_title),
    okayAction: String = stringResource(Res.string.job_okay_action),
    jobInProgressTitle: String = stringResource(Res.string.job_in_progress_title),
    completeJob: String = stringResource(Res.string.job_complete_job),
    timeLeft: String = stringResource(Res.string.job_time_left),
    autoCheckoutLabel: String = stringResource(Res.string.job_auto_checkout_label),
    jobTimingLabel: String = stringResource(Res.string.job_timing_label),
    durationLabel: String = stringResource(Res.string.job_duration_label),
    customerPreferencesTitle: String = stringResource(Res.string.job_customer_preferences_title),
    timeUpCallout: String = stringResource(Res.string.job_time_up_callout),
    autoCheckoutCallout: String = stringResource(Res.string.job_auto_checkout_callout),
    nextJobReadyCallout: String = stringResource(Res.string.job_next_job_ready_callout),
    jobExtendedCallout: String = stringResource(Res.string.job_extended_callout),
    tasksDoneTitle: String = stringResource(Res.string.job_tasks_done_title),
    confirmAction: String = stringResource(Res.string.job_confirm_action),
    selectTaskHint: String = stringResource(Res.string.job_select_task_hint),
    jobCompletedTitle: String = stringResource(Res.string.job_completed_title),
    youEarned: String = stringResource(Res.string.job_you_earned),
    readyForNextJob: String = stringResource(Res.string.job_ready_for_next_job),
    customerBlockedToast: String = stringResource(Res.string.job_customer_blocked_toast),
): JobStrings = remember(
    newJobTitle, youWillEarn, acceptIn, acceptJob, deny, checkInBy, checkIn, checkInByCaps, runningLate,
    mapAction, callAction, chatAction, listen, customerFallback, enterOtpTitle, otpHelper, startJob,
    noOtp, otpIncorrect, enterPhoneTitle, phoneHelper, useOtpInstead, phoneMismatch,
    checkInLocationErrorTitle, checkInLocationErrorSubtitle, tryAgain, genericError, networkError,
    jobReassigned,
    jobAccepted, jobDenied, redCardNudge, denyMissEarningsTitle, denyLoseEarningsTitle, logout,
    markAttendanceTitle, attendancePresent, attendanceAbsent, loggedOutTitle, loggedOutSubtitle,
    jobStarted, okAction, enterOtpToEndJobTitle, endJob, jobEndCampaignTitle, okayAction,
    jobInProgressTitle, completeJob, timeLeft, autoCheckoutLabel, jobTimingLabel, durationLabel,
    customerPreferencesTitle, timeUpCallout, autoCheckoutCallout, nextJobReadyCallout, jobExtendedCallout,
    tasksDoneTitle, confirmAction, selectTaskHint, jobCompletedTitle, youEarned, readyForNextJob,
    customerBlockedToast,
) {
    JobStrings(
        newJobTitle = newJobTitle,
        youWillEarn = youWillEarn,
        acceptIn = acceptIn,
        acceptJob = acceptJob,
        deny = deny,
        checkInBy = checkInBy,
        checkIn = checkIn,
        checkInByCaps = checkInByCaps,
        runningLate = runningLate,
        mapAction = mapAction,
        callAction = callAction,
        chatAction = chatAction,
        listen = listen,
        customerFallback = customerFallback,
        enterOtpTitle = enterOtpTitle,
        otpHelper = otpHelper,
        startJob = startJob,
        noOtp = noOtp,
        otpIncorrect = otpIncorrect,
        enterPhoneTitle = enterPhoneTitle,
        phoneHelper = phoneHelper,
        useOtpInstead = useOtpInstead,
        phoneMismatch = phoneMismatch,
        checkInLocationErrorTitle = checkInLocationErrorTitle,
        checkInLocationErrorSubtitle = checkInLocationErrorSubtitle,
        tryAgain = tryAgain,
        genericError = genericError,
        networkError = networkError,
        jobReassigned = jobReassigned,
        jobAccepted = jobAccepted,
        jobDenied = jobDenied,
        redCardNudge = redCardNudge,
        denyMissEarningsTitle = denyMissEarningsTitle,
        denyLoseEarningsTitle = denyLoseEarningsTitle,
        logout = logout,
        markAttendanceTitle = markAttendanceTitle,
        attendancePresent = attendancePresent,
        attendanceAbsent = attendanceAbsent,
        loggedOutTitle = loggedOutTitle,
        loggedOutSubtitle = loggedOutSubtitle,
        jobStarted = jobStarted,
        okAction = okAction,
        enterOtpToEndJobTitle = enterOtpToEndJobTitle,
        endJob = endJob,
        jobEndCampaignTitle = jobEndCampaignTitle,
        okayAction = okayAction,
        jobInProgressTitle = jobInProgressTitle,
        completeJob = completeJob,
        timeLeft = timeLeft,
        autoCheckoutLabel = autoCheckoutLabel,
        jobTimingLabel = jobTimingLabel,
        durationLabel = durationLabel,
        customerPreferencesTitle = customerPreferencesTitle,
        timeUpCallout = timeUpCallout,
        autoCheckoutCallout = autoCheckoutCallout,
        nextJobReadyCallout = nextJobReadyCallout,
        jobExtendedCallout = jobExtendedCallout,
        tasksDoneTitle = tasksDoneTitle,
        confirmAction = confirmAction,
        selectTaskHint = selectTaskHint,
        jobCompletedTitle = jobCompletedTitle,
        youEarned = youEarned,
        readyForNextJob = readyForNextJob,
        customerBlockedToast = customerBlockedToast,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map ([LocalizationStore]) onto these [JobStrings]:
 * every localizable field resolves via `getMessage("<key>", <englishFallback>)`, so an
 * absent key (before the backend serves it, or an unmatched/invented key) falls back to
 * the composeResources English — safe by construction. Keys follow the PM localization
 * catalog (dotted namespace). Baked into [rememberJobStrings] so all call sites localize.
 *
 * [checkInByCaps] localizes from the templated `check_in.footer_ontime_label` ("… {time}"), the
 * consumer (JobFooter) filling `{time}`. [checkInBy] (bare prefix) localizes from the invented
 * `check_in.check_in_by_label` — absent from the CSV, so it stays English until the PM adds it.
 * [customerFallback] is left unchanged — a brand fallback name, not display copy.
 * Placeholder tokens are single-brace `{x}` to match the server copy. Several keys are
 * INVENTED (no CSV row) pending backend — see the PR description.
 */
fun JobStrings.localized(l10n: LocalizationStore): JobStrings = copy(
    topNavHelpLabel = l10n.getMessage("common.help", topNavHelpLabel),
    topNavSosLabel = l10n.getMessage("common.sos", topNavSosLabel),
    newJobTitle = l10n.getMessage("job_acceptance.header", newJobTitle),
    youWillEarn = l10n.getMessage("common.earn_label", youWillEarn),
    acceptIn = l10n.getMessage("job_acceptance.timer_label", acceptIn),
    acceptJob = l10n.getMessage("job_acceptance.cta_accept", acceptJob),
    deny = l10n.getMessage("job_acceptance.cta_deny", deny),
    checkIn = l10n.getMessage("check_in.cta", checkIn),
    checkInBy = l10n.getMessage("check_in.check_in_by_label", checkInBy),
    checkInByCaps = l10n.getMessage("check_in.footer_ontime_label", checkInByCaps),
    checkInByPill = l10n.getMessage("common.checkin_pill", checkInByPill),
    runningLate = l10n.getMessage("check_in.status_running_late", runningLate),
    mapAction = l10n.getMessage("common.action_map", mapAction),
    callAction = l10n.getMessage("common.action_call", callAction),
    chatAction = l10n.getMessage("common.action_chat", chatAction),
    listen = l10n.getMessage("common.listen", listen),
    enterOtpTitle = l10n.getMessage("check_in_otp.title", enterOtpTitle),
    otpHelper = l10n.getMessage("common.otp_share_prompt", otpHelper),
    startJob = l10n.getMessage("check_in_otp.cta_start_job", startJob),
    noOtp = l10n.getMessage("check_in_otp.cta_no_otp", noOtp),
    otpIncorrect = l10n.getMessage("check_in_otp.otp_incorrect", otpIncorrect),
    enterPhoneTitle = l10n.getMessage("check_in_otp.phone_title", enterPhoneTitle),
    phoneHelper = l10n.getMessage("check_in_otp.phone_subtitle", phoneHelper),
    useOtpInstead = l10n.getMessage("check_in_otp.cta_use_otp", useOtpInstead),
    phoneMismatch = l10n.getMessage("check_in_otp.phone_mismatch", phoneMismatch),
    checkInLocationErrorTitle =
        l10n.getMessage("check_in_otp.location_error_title", checkInLocationErrorTitle),
    checkInLocationErrorSubtitle =
        l10n.getMessage("check_in_otp.location_error_subtitle", checkInLocationErrorSubtitle),
    tryAgain = l10n.getMessage("common.try_again", tryAgain),
    genericError = l10n.getMessage("common.generic_error", genericError),
    // INVENTED key (no CSV row yet) — falls back to the composeResources English until the PM adds it.
    networkError = l10n.getMessage("common.network_error", networkError),
    jobReassigned = l10n.getMessage("job_acceptance.reassigned", jobReassigned),
    jobAccepted = l10n.getMessage("job_acceptance.accepted_toast", jobAccepted),
    jobDenied = l10n.getMessage("job_acceptance.denied_toast", jobDenied),
    redCardNudge = l10n.getMessage("job_acceptance.penalty_card", redCardNudge),
    // deny_last_hour.title embeds ₹ before {amount} while the consumer's formatRupees() also
    // prepends ₹; JobDenyFlowSheet collapses a leading "₹{amount}" → "{amount}" before filling,
    // so localizing here no longer doubles the ₹.
    denyMissEarningsTitle = l10n.getMessage("deny_last_hour.title", denyMissEarningsTitle),
    denyLoseEarningsTitle = l10n.getMessage("deny_long_distance.title", denyLoseEarningsTitle),
    logout = l10n.getMessage("deny_last_hour.cta_logout", logout),
    markAttendanceTitle = l10n.getMessage("attendance_overlay.title", markAttendanceTitle),
    attendancePresent = l10n.getMessage("home.present", attendancePresent),
    attendanceAbsent = l10n.getMessage("home.absent", attendanceAbsent),
    loggedOutTitle = l10n.getMessage("logout.thank_you_title", loggedOutTitle),
    loggedOutSubtitle = l10n.getMessage("logout.success_subtitle", loggedOutSubtitle),
    jobStarted = l10n.getMessage("job_started.title", jobStarted),
    okAction = l10n.getMessage("job_started.cta_ok", okAction),
    enterOtpToEndJobTitle = l10n.getMessage("end_job_otp.title", enterOtpToEndJobTitle),
    endJob = l10n.getMessage("end_job_otp.cta_end_job", endJob),
    jobEndCampaignTitle = l10n.getMessage("job.end_campaign_title", jobEndCampaignTitle),
    okayAction = l10n.getMessage("task_summary.cta_okay", okayAction),
    jobInProgressTitle = l10n.getMessage("job_in_progress.header", jobInProgressTitle),
    completeJob = l10n.getMessage("job_in_progress.cta_complete", completeJob),
    timeLeft = l10n.getMessage("job_in_progress.timer_label", timeLeft),
    autoCheckoutLabel =
        l10n.getMessage("job_in_progress.auto_checkout_label", autoCheckoutLabel),
    jobTimingLabel = l10n.getMessage("job_in_progress.job_timing_label", jobTimingLabel),
    durationLabel = l10n.getMessage("job_in_progress.duration_label", durationLabel),
    customerPreferencesTitle =
        l10n.getMessage("job_in_progress.section_customer_prefs", customerPreferencesTitle),
    timeUpCallout = l10n.getMessage("job_in_progress.time_up_callout", timeUpCallout),
    autoCheckoutCallout =
        l10n.getMessage("job_in_progress.auto_checkout_callout", autoCheckoutCallout),
    nextJobReadyCallout =
        l10n.getMessage("job_in_progress.next_job_ready_callout", nextJobReadyCallout),
    // banner_extended uses {mins}; the English fallback uses {duration}. The consumer
    // (InProgressContent) replaces both tokens, so either spelling resolves.
    jobExtendedCallout = l10n.getMessage("job_in_progress.banner_extended", jobExtendedCallout),
    tasksDoneTitle = l10n.getMessage("task_summary.title", tasksDoneTitle),
    confirmAction = l10n.getMessage("common.confirm", confirmAction),
    selectTaskHint = l10n.getMessage("task_summary.select_task_hint", selectTaskHint),
    jobCompletedTitle = l10n.getMessage("job_completed.header", jobCompletedTitle),
    calculatingEarningsTitle =
        l10n.getMessage("job_completed.calculating_title", calculatingEarningsTitle),
    calculatingEarningsSubtitle =
        l10n.getMessage("job_completed.calculating_subtitle", calculatingEarningsSubtitle),
    youEarned = l10n.getMessage("job_completed.earned_label", youEarned),
    readyForNextJob = l10n.getMessage("job_completed.cta_ready_next", readyForNextJob),
    customerBlockedToast = l10n.getMessage("job_completed.toast_blocked", customerBlockedToast),
)

/** Resolves a semantic [JobMessage] to its display copy from these [JobStrings]. */
fun JobStrings.resolve(message: JobMessage): String = when (message) {
    JobMessage.JobAccepted -> jobAccepted
    JobMessage.JobDenied -> jobDenied
    JobMessage.Reassigned -> jobReassigned
    JobMessage.Generic -> genericError
    JobMessage.CheckInLocation -> checkInLocationErrorTitle
    JobMessage.OtpIncorrect -> otpIncorrect
    JobMessage.NetworkError -> networkError
    JobMessage.PhoneMismatch -> phoneMismatch
    JobMessage.SelectTaskHint -> selectTaskHint
    is JobMessage.Server -> message.text
}

/**
 * Non-composable resolver for the "customer blocked" toast copy — for a platform host that must show it
 * OUTSIDE composition (the OS toast fired after `JobActivity.finish()`, ECPO #10, which a Compose toast
 * wouldn't survive). Reads the same `composeResources` fallback as [rememberJobStrings]; exposed from
 * `:shared` because the generated `Res` is internal to this module.
 */
suspend fun jobCustomerBlockedToastText(): String = getString(Res.string.job_customer_blocked_toast)
