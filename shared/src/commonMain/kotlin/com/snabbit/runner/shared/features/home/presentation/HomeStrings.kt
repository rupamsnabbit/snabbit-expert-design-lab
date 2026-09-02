package com.snabbit.runner.shared.features.home.presentation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.contact_call_initiated
import com.snabbit.runner.shared.resources.contact_call_number_unavailable
import com.snabbit.runner.shared.resources.home_change_attendance_confirm_title
import com.snabbit.runner.shared.resources.home_earning_loss_no_amount_title
import com.snabbit.runner.shared.resources.home_earning_loss_subtitle
import com.snabbit.runner.shared.resources.home_earning_loss_title_prefix
import com.snabbit.runner.shared.resources.home_earning_loss_title_suffix
import com.snabbit.runner.shared.resources.home_earning_loss_title_verb
import com.snabbit.runner.shared.resources.home_error_no_connection
import com.snabbit.runner.shared.resources.home_error_server
import com.snabbit.runner.shared.resources.home_error_unauthorized
import com.snabbit.runner.shared.resources.home_error_unknown
import com.snabbit.runner.shared.resources.home_hotspot_distance_template
import com.snabbit.runner.shared.resources.home_hotspot_map_label
import com.snabbit.runner.shared.resources.home_hotspot_reached_distance
import com.snabbit.runner.shared.resources.home_hotspot_title_not_reached
import com.snabbit.runner.shared.resources.home_hotspot_title_reached
import com.snabbit.runner.shared.resources.home_lunch_end_break_cta
import com.snabbit.runner.shared.resources.home_lunch_end_confirm_primary_cta
import com.snabbit.runner.shared.resources.home_lunch_end_confirm_secondary_cta
import com.snabbit.runner.shared.resources.home_lunch_end_confirm_title
import com.snabbit.runner.shared.resources.home_lunch_request_title
import com.snabbit.runner.shared.resources.home_lunch_skip_break_cta
import com.snabbit.runner.shared.resources.home_lunch_starting_in_label
import com.snabbit.runner.shared.resources.home_lunch_take_break_cta
import com.snabbit.runner.shared.resources.home_lunch_time_left_label
import com.snabbit.runner.shared.resources.home_map_widget_dismiss_helper
import com.snabbit.runner.shared.resources.home_map_widget_logout_cta
import com.snabbit.runner.shared.resources.home_map_widget_logout_shift_ends_template
import com.snabbit.runner.shared.resources.home_map_widget_lunch_in_template
import com.snabbit.runner.shared.resources.home_map_widget_lunch_time
import com.snabbit.runner.shared.resources.home_map_widget_searching_for_jobs
import com.snabbit.runner.shared.resources.home_mark_tomorrow_title
import com.snabbit.runner.shared.resources.home_more_from_snabbit_header
import com.snabbit.runner.shared.resources.home_see_you_tomorrow_refer_cta
import com.snabbit.runner.shared.resources.home_see_you_tomorrow_title
import com.snabbit.runner.shared.resources.home_sheet_absent_cta
import com.snabbit.runner.shared.resources.home_sheet_close
import com.snabbit.runner.shared.resources.home_sheet_present_cta
import com.snabbit.runner.shared.resources.home_today_change_cta
import com.snabbit.runner.shared.resources.home_today_login_cta
import com.snabbit.runner.shared.resources.home_today_status_absent
import com.snabbit.runner.shared.resources.home_today_status_absent_terminal
import com.snabbit.runner.shared.resources.home_today_status_false_attendance
import com.snabbit.runner.shared.resources.home_today_status_no_show
import com.snabbit.runner.shared.resources.home_today_status_no_show_terminal
import com.snabbit.runner.shared.resources.home_today_status_present
import com.snabbit.runner.shared.resources.home_top_nav_bell_label
import com.snabbit.runner.shared.resources.home_top_nav_saathi_label
import com.snabbit.runner.shared.resources.home_top_nav_sos_label
import com.snabbit.runner.shared.resources.home_tomorrow_absent_cta
import com.snabbit.runner.shared.resources.home_tomorrow_earn_prefix
import com.snabbit.runner.shared.resources.home_tomorrow_mark_attendance_prompt
import com.snabbit.runner.shared.resources.home_tomorrow_present_cta
import com.snabbit.runner.shared.resources.home_waiver_cta
import com.snabbit.runner.shared.resources.home_waiver_subtitle_template
import com.snabbit.runner.shared.resources.home_waiver_title
import com.snabbit.runner.shared.resources.home_waiver_warning_pill
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * User-facing copy for the Home screen.
 *
 * Same two-tier i18n as [com.snabbit.runner.shared.core.camera.ui.CameraStrings]:
 * the **fallbacks** live in `composeResources` and are resolved by
 * [rememberHomeStrings]; the host may **override** any label at runtime with the
 * app's server-driven i18n value by passing a named argument.
 */
data class HomeStrings(
    val topNavSosLabel: String,
    val topNavSaathiLabel: String,
    val topNavBellLabel: String,
    val moreFromSnabbitHeader: String,
    val tomorrowEarnPrefix: String,
    val tomorrowMarkAttendancePrompt: String,
    val tomorrowAbsentCta: String,
    val tomorrowPresentCta: String,
    val todayStatusPresent: String,
    val todayStatusAbsent: String,
    val todayStatusNoShow: String,
    val todayStatusFalseAttendance: String,
    val todayStatusAbsentTerminal: String,
    val todayStatusNoShowTerminal: String,
    val todayChangeCta: String,
    val todayLoginCta: String,
    val hotspotTitleNotReached: String,
    val hotspotTitleReached: String,
    val hotspotMapLabel: String,
    /** Template with `{distance}`. */
    val hotspotDistanceTemplate: String,
    val hotspotReachedDistance: String,
    val sheetAbsentCta: String,
    val sheetPresentCta: String,
    val sheetCloseContentDescription: String,
    val earningLossTitlePrefix: String,
    val earningLossTitleVerb: String,
    val earningLossTitleSuffix: String,
    val earningLossSubtitle: String,
    val earningLossNoAmountTitle: String,
    val markTomorrowTitle: String,
    val changeAttendanceConfirmTitle: String,
    val waiverWarningPill: String,
    val waiverTitle: String,
    /** Template with `{count}`. */
    val waiverSubtitleTemplate: String,
    val waiverCta: String,
    val errorNoConnection: String,
    val errorUnauthorized: String,
    val errorServer: String,
    val errorUnknown: String,
    val mapWidgetSearchingForJobs: String,
    val mapWidgetLogoutCta: String,
    /** Template with `{time}`. */
    val mapWidgetLogoutShiftEndsTemplate: String,
    val mapWidgetDismissHelper: String,
    val mapWidgetLunchTime: String,
    /** Template with `{time}` — the `mm:ss` until the break starts. */
    val mapWidgetLunchInTemplate: String,
    val lunchTimeLeftLabel: String,
    val lunchStartingInLabel: String,
    val lunchEndBreakCta: String,
    val lunchRequestTitle: String,
    val lunchTakeBreakCta: String,
    val lunchSkipBreakCta: String,
    val lunchEndConfirmTitle: String,
    val lunchEndConfirmPrimaryCta: String,
    val lunchEndConfirmSecondaryCta: String,

    // ── Suspended card (RUNNER_SUSPENDED — Dart `runner_suspended.dart`) ──
    // Copy + fallbacks mirror the Dart `languageProvider.getMessage` keys
    // (`account_suspended`, `account_suspended_aadhaar`, `come_back_to_work`,
    // `request_submitted`, `update_aadhaar`, `go_to_earnings`) verbatim. Hardcoded
    // defaults (no `composeResources` entry yet) — override via a named arg.
    val suspendedTitle: String = "Your documents are being verified",
    val suspendedTitleAadhaar: String =
        "Your account is suspended as Aadhaar verification is incomplete",
    val suspendedComeBackCta: String = "Come Back to Work",
    val suspendedRequestSubmittedCta: String = "Request submitted",
    val suspendedUpdateAadhaarCta: String = "Update Aadhaar",
    val suspendedGoToEarningsCta: String = "Go to Earnings",

    // ── See-you-tomorrow card (RUNNER_SEE_YOU_TOMORROW — Dart `see_you_tomorrow.dart`) ──
    // composeResources-backed fallbacks (resolved by [rememberHomeStrings]);
    // override via a named arg. "Go to Earnings" reuses [suspendedGoToEarningsCta].
    val seeYouTomorrowTitle: String,
    val seeYouTomorrowReferCta: String,

    // ── Saathi support-call feedback toast — reuses the shipped job-contact copy ──
    val callInitiated: String,
    val callNumberUnavailable: String,

    // ── GPS-off enable sheet (ECPO-873, reduced scope) — Flutter parity ──
    // Hardcoded defaults only; SERVICE_OFF is new (Dart delegates GPS-off to the
    // OS dialog). Unlike the suspended-card strings above, these keys are NOT
    // wired into `localized()` / `store.getMessage(...)`, so there is no server
    // override yet.
    val locationEnableTitle: String = "Turn on your location",
    val locationEnableBody: String = "Turn on your device location to keep finding work near you.",
    val locationEnableCta: String = "Turn on GPS",
) {
    /** Resolve a domain [RunnerActionError] to its snackbar message. */
    fun errorFor(error: RunnerActionError): String = when (error) {
        RunnerActionError.NoConnection -> errorNoConnection
        RunnerActionError.Unauthorized -> errorUnauthorized
        RunnerActionError.Server -> errorServer
        is RunnerActionError.Unknown -> errorUnknown
    }

    /** Resolve a [SaathiCallFeedback] to its toast copy (reuses the job-contact strings). */
    fun saathiFeedbackFor(feedback: SaathiCallFeedback): String = when (feedback) {
        SaathiCallFeedback.CallInitiated -> callInitiated
        SaathiCallFeedback.NumberUnavailable -> callNumberUnavailable
    }
}

/**
 * [HomeStrings] with every label defaulted to its `composeResources` fallback.
 * Pass a named argument to override just that label with a server-driven value.
 */
@Composable
fun rememberHomeStrings(
    topNavSosLabel: String = stringResource(Res.string.home_top_nav_sos_label),
    topNavSaathiLabel: String = stringResource(Res.string.home_top_nav_saathi_label),
    topNavBellLabel: String = stringResource(Res.string.home_top_nav_bell_label),
    moreFromSnabbitHeader: String = stringResource(Res.string.home_more_from_snabbit_header),
    tomorrowEarnPrefix: String = stringResource(Res.string.home_tomorrow_earn_prefix),
    tomorrowMarkAttendancePrompt: String = stringResource(Res.string.home_tomorrow_mark_attendance_prompt),
    tomorrowAbsentCta: String = stringResource(Res.string.home_tomorrow_absent_cta),
    tomorrowPresentCta: String = stringResource(Res.string.home_tomorrow_present_cta),
    todayStatusPresent: String = stringResource(Res.string.home_today_status_present),
    todayStatusAbsent: String = stringResource(Res.string.home_today_status_absent),
    todayStatusNoShow: String = stringResource(Res.string.home_today_status_no_show),
    todayStatusFalseAttendance: String = stringResource(Res.string.home_today_status_false_attendance),
    todayStatusAbsentTerminal: String = stringResource(Res.string.home_today_status_absent_terminal),
    todayStatusNoShowTerminal: String = stringResource(Res.string.home_today_status_no_show_terminal),
    todayChangeCta: String = stringResource(Res.string.home_today_change_cta),
    todayLoginCta: String = stringResource(Res.string.home_today_login_cta),
    hotspotTitleNotReached: String = stringResource(Res.string.home_hotspot_title_not_reached),
    hotspotTitleReached: String = stringResource(Res.string.home_hotspot_title_reached),
    hotspotMapLabel: String = stringResource(Res.string.home_hotspot_map_label),
    hotspotDistanceTemplate: String = stringResource(Res.string.home_hotspot_distance_template),
    hotspotReachedDistance: String = stringResource(Res.string.home_hotspot_reached_distance),
    sheetAbsentCta: String = stringResource(Res.string.home_sheet_absent_cta),
    sheetPresentCta: String = stringResource(Res.string.home_sheet_present_cta),
    sheetCloseContentDescription: String = stringResource(Res.string.home_sheet_close),
    earningLossTitlePrefix: String = stringResource(Res.string.home_earning_loss_title_prefix),
    earningLossTitleVerb: String = stringResource(Res.string.home_earning_loss_title_verb),
    earningLossTitleSuffix: String = stringResource(Res.string.home_earning_loss_title_suffix),
    earningLossSubtitle: String = stringResource(Res.string.home_earning_loss_subtitle),
    earningLossNoAmountTitle: String = stringResource(Res.string.home_earning_loss_no_amount_title),
    markTomorrowTitle: String = stringResource(Res.string.home_mark_tomorrow_title),
    changeAttendanceConfirmTitle: String = stringResource(Res.string.home_change_attendance_confirm_title),
    waiverWarningPill: String = stringResource(Res.string.home_waiver_warning_pill),
    waiverTitle: String = stringResource(Res.string.home_waiver_title),
    waiverSubtitleTemplate: String = stringResource(Res.string.home_waiver_subtitle_template),
    waiverCta: String = stringResource(Res.string.home_waiver_cta),
    errorNoConnection: String = stringResource(Res.string.home_error_no_connection),
    errorUnauthorized: String = stringResource(Res.string.home_error_unauthorized),
    errorServer: String = stringResource(Res.string.home_error_server),
    errorUnknown: String = stringResource(Res.string.home_error_unknown),
    mapWidgetSearchingForJobs: String = stringResource(Res.string.home_map_widget_searching_for_jobs),
    mapWidgetLogoutCta: String = stringResource(Res.string.home_map_widget_logout_cta),
    mapWidgetLogoutShiftEndsTemplate: String = stringResource(Res.string.home_map_widget_logout_shift_ends_template),
    mapWidgetDismissHelper: String = stringResource(Res.string.home_map_widget_dismiss_helper),
    mapWidgetLunchTime: String = stringResource(Res.string.home_map_widget_lunch_time),
    mapWidgetLunchInTemplate: String = stringResource(Res.string.home_map_widget_lunch_in_template),
    lunchTimeLeftLabel: String = stringResource(Res.string.home_lunch_time_left_label),
    lunchStartingInLabel: String = stringResource(Res.string.home_lunch_starting_in_label),
    lunchEndBreakCta: String = stringResource(Res.string.home_lunch_end_break_cta),
    lunchRequestTitle: String = stringResource(Res.string.home_lunch_request_title),
    lunchTakeBreakCta: String = stringResource(Res.string.home_lunch_take_break_cta),
    lunchSkipBreakCta: String = stringResource(Res.string.home_lunch_skip_break_cta),
    lunchEndConfirmTitle: String = stringResource(Res.string.home_lunch_end_confirm_title),
    lunchEndConfirmPrimaryCta: String = stringResource(Res.string.home_lunch_end_confirm_primary_cta),
    lunchEndConfirmSecondaryCta: String = stringResource(Res.string.home_lunch_end_confirm_secondary_cta),
    seeYouTomorrowTitle: String = stringResource(Res.string.home_see_you_tomorrow_title),
    seeYouTomorrowReferCta: String = stringResource(Res.string.home_see_you_tomorrow_refer_cta),
    callInitiated: String = stringResource(Res.string.contact_call_initiated),
    callNumberUnavailable: String = stringResource(Res.string.contact_call_number_unavailable),
): HomeStrings = remember(
    // remember() caps at ~no practical limit via vararg keys; list all so a
    // host override of any single label re-builds the object.
    listOf(
        topNavSosLabel, topNavSaathiLabel, topNavBellLabel, moreFromSnabbitHeader,
        tomorrowEarnPrefix, tomorrowMarkAttendancePrompt, tomorrowAbsentCta, tomorrowPresentCta,
        todayStatusPresent, todayStatusAbsent, todayStatusNoShow, todayStatusFalseAttendance,
        todayStatusAbsentTerminal, todayStatusNoShowTerminal, todayChangeCta, todayLoginCta,
        hotspotTitleNotReached, hotspotTitleReached, hotspotMapLabel, hotspotDistanceTemplate,
        hotspotReachedDistance, sheetAbsentCta, sheetPresentCta, sheetCloseContentDescription,
        earningLossTitlePrefix, earningLossTitleVerb, earningLossTitleSuffix, earningLossSubtitle,
        earningLossNoAmountTitle, markTomorrowTitle, changeAttendanceConfirmTitle, waiverWarningPill,
        waiverTitle, waiverSubtitleTemplate, waiverCta, errorNoConnection, errorUnauthorized,
        errorServer, errorUnknown, mapWidgetSearchingForJobs, mapWidgetLogoutCta,
        mapWidgetLogoutShiftEndsTemplate, mapWidgetDismissHelper, mapWidgetLunchTime,
        mapWidgetLunchInTemplate, lunchTimeLeftLabel, lunchStartingInLabel, lunchEndBreakCta, lunchRequestTitle,
        lunchTakeBreakCta, lunchSkipBreakCta, lunchEndConfirmTitle, lunchEndConfirmPrimaryCta,
        lunchEndConfirmSecondaryCta, seeYouTomorrowTitle, seeYouTomorrowReferCta,
        callInitiated, callNumberUnavailable,
    ),
) {
    HomeStrings(
        topNavSosLabel = topNavSosLabel,
        topNavSaathiLabel = topNavSaathiLabel,
        topNavBellLabel = topNavBellLabel,
        moreFromSnabbitHeader = moreFromSnabbitHeader,
        tomorrowEarnPrefix = tomorrowEarnPrefix,
        tomorrowMarkAttendancePrompt = tomorrowMarkAttendancePrompt,
        tomorrowAbsentCta = tomorrowAbsentCta,
        tomorrowPresentCta = tomorrowPresentCta,
        todayStatusPresent = todayStatusPresent,
        todayStatusAbsent = todayStatusAbsent,
        todayStatusNoShow = todayStatusNoShow,
        todayStatusFalseAttendance = todayStatusFalseAttendance,
        todayStatusAbsentTerminal = todayStatusAbsentTerminal,
        todayStatusNoShowTerminal = todayStatusNoShowTerminal,
        todayChangeCta = todayChangeCta,
        todayLoginCta = todayLoginCta,
        hotspotTitleNotReached = hotspotTitleNotReached,
        hotspotTitleReached = hotspotTitleReached,
        hotspotMapLabel = hotspotMapLabel,
        hotspotDistanceTemplate = hotspotDistanceTemplate,
        hotspotReachedDistance = hotspotReachedDistance,
        sheetAbsentCta = sheetAbsentCta,
        sheetPresentCta = sheetPresentCta,
        sheetCloseContentDescription = sheetCloseContentDescription,
        earningLossTitlePrefix = earningLossTitlePrefix,
        earningLossTitleVerb = earningLossTitleVerb,
        earningLossTitleSuffix = earningLossTitleSuffix,
        earningLossSubtitle = earningLossSubtitle,
        earningLossNoAmountTitle = earningLossNoAmountTitle,
        markTomorrowTitle = markTomorrowTitle,
        changeAttendanceConfirmTitle = changeAttendanceConfirmTitle,
        waiverWarningPill = waiverWarningPill,
        waiverTitle = waiverTitle,
        waiverSubtitleTemplate = waiverSubtitleTemplate,
        waiverCta = waiverCta,
        errorNoConnection = errorNoConnection,
        errorUnauthorized = errorUnauthorized,
        errorServer = errorServer,
        errorUnknown = errorUnknown,
        mapWidgetSearchingForJobs = mapWidgetSearchingForJobs,
        mapWidgetLogoutCta = mapWidgetLogoutCta,
        mapWidgetLogoutShiftEndsTemplate = mapWidgetLogoutShiftEndsTemplate,
        mapWidgetDismissHelper = mapWidgetDismissHelper,
        mapWidgetLunchTime = mapWidgetLunchTime,
        mapWidgetLunchInTemplate = mapWidgetLunchInTemplate,
        lunchTimeLeftLabel = lunchTimeLeftLabel,
        lunchStartingInLabel = lunchStartingInLabel,
        lunchEndBreakCta = lunchEndBreakCta,
        lunchRequestTitle = lunchRequestTitle,
        lunchTakeBreakCta = lunchTakeBreakCta,
        lunchSkipBreakCta = lunchSkipBreakCta,
        lunchEndConfirmTitle = lunchEndConfirmTitle,
        lunchEndConfirmPrimaryCta = lunchEndConfirmPrimaryCta,
        lunchEndConfirmSecondaryCta = lunchEndConfirmSecondaryCta,
        seeYouTomorrowTitle = seeYouTomorrowTitle,
        seeYouTomorrowReferCta = seeYouTomorrowReferCta,
        callInitiated = callInitiated,
        callNumberUnavailable = callNumberUnavailable,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [HomeStrings] (baked into
 * [rememberHomeStrings]); a missing key falls back to the current English value, so
 * this is behaviour-preserving. Keys follow the PM localization catalog (dotted),
 * except the suspended-card keys which reuse the existing flat server keys.
 */
fun HomeStrings.localized(store: LocalizationStore): HomeStrings = copy(
    topNavSosLabel = store.getMessage("common.sos", topNavSosLabel),
    topNavSaathiLabel = store.getMessage("common.saathi", topNavSaathiLabel),
    topNavBellLabel = store.getMessage("home.top_nav_notifications", topNavBellLabel),
    moreFromSnabbitHeader = store.getMessage("home.more_from_snabbit", moreFromSnabbitHeader),
    tomorrowEarnPrefix = store.getMessage("home.earn_label", tomorrowEarnPrefix),
    tomorrowMarkAttendancePrompt =
        store.getMessage("home.mark_attendance", tomorrowMarkAttendancePrompt),
    tomorrowAbsentCta = store.getMessage("home.absent", tomorrowAbsentCta),
    tomorrowPresentCta = store.getMessage("home.present", tomorrowPresentCta),
    todayStatusPresent = store.getMessage("home.status_present", todayStatusPresent),
    todayStatusAbsent = store.getMessage("home.absent", todayStatusAbsent),
    todayStatusNoShow = store.getMessage("home.status_no_show", todayStatusNoShow),
    todayStatusFalseAttendance =
        store.getMessage("home.status_false_attendance", todayStatusFalseAttendance),
    todayStatusAbsentTerminal = store.getMessage("absent_today.title", todayStatusAbsentTerminal),
    todayStatusNoShowTerminal =
        store.getMessage("home.status_no_show_terminal", todayStatusNoShowTerminal),
    todayChangeCta = store.getMessage("home.change", todayChangeCta),
    todayLoginCta = store.getMessage("home.cta_login", todayLoginCta),
    hotspotTitleNotReached = store.getMessage("home.your_hotspot", hotspotTitleNotReached),
    hotspotTitleReached = store.getMessage("home.hotspot_reached", hotspotTitleReached),
    hotspotMapLabel = store.getMessage("common.action_map", hotspotMapLabel),
    hotspotDistanceTemplate = store.getMessage("home.distance_away", hotspotDistanceTemplate),
    hotspotReachedDistance = store.getMessage("home.hotspot_reached_distance", hotspotReachedDistance),
    sheetAbsentCta = store.getMessage("home.absent", sheetAbsentCta),
    sheetPresentCta = store.getMessage("home.present", sheetPresentCta),
    sheetCloseContentDescription = store.getMessage("home.sheet_close", sheetCloseContentDescription),
    earningLossTitlePrefix = store.getMessage("home.earning_loss_title_prefix", earningLossTitlePrefix),
    earningLossTitleVerb = store.getMessage("home.earning_loss_title_verb", earningLossTitleVerb),
    earningLossTitleSuffix = store.getMessage("home.earning_loss_title_suffix", earningLossTitleSuffix),
    earningLossSubtitle = store.getMessage("change_earn.subtitle", earningLossSubtitle),
    earningLossNoAmountTitle =
        store.getMessage("home.earning_loss_no_amount_title", earningLossNoAmountTitle),
    markTomorrowTitle = store.getMessage("attendance_overlay.title", markTomorrowTitle),
    changeAttendanceConfirmTitle =
        store.getMessage("change_confirm.title", changeAttendanceConfirmTitle),
    waiverWarningPill = store.getMessage("change_waived.warning", waiverWarningPill),
    waiverTitle = store.getMessage("change_waived.title", waiverTitle),
    waiverSubtitleTemplate = store.getMessage("change_waived.subtitle", waiverSubtitleTemplate),
    waiverCta = store.getMessage("change_waived.cta", waiverCta),
    errorNoConnection = store.getMessage("home.error_no_connection", errorNoConnection),
    errorUnauthorized = store.getMessage("home.error_unauthorized", errorUnauthorized),
    errorServer = store.getMessage("home.error_server", errorServer),
    errorUnknown = store.getMessage("home.error_unknown", errorUnknown),
    mapWidgetSearchingForJobs = store.getMessage("home.searching_jobs", mapWidgetSearchingForJobs),
    mapWidgetLogoutCta = store.getMessage("logout.cta_logout", mapWidgetLogoutCta),
    mapWidgetLogoutShiftEndsTemplate =
        store.getMessage("logout.shift_ends", mapWidgetLogoutShiftEndsTemplate),
    mapWidgetDismissHelper = store.getMessage("home.map_widget_dismiss", mapWidgetDismissHelper),
    mapWidgetLunchTime = store.getMessage("home.map_widget_lunch_time", mapWidgetLunchTime),
    mapWidgetLunchInTemplate = store.getMessage("home.map_widget_lunch_in", mapWidgetLunchInTemplate),
    lunchTimeLeftLabel = store.getMessage("break.timer_label", lunchTimeLeftLabel),
    lunchStartingInLabel = store.getMessage("home.lunch_starting_in", lunchStartingInLabel),
    lunchEndBreakCta = store.getMessage("break.cta_end_break", lunchEndBreakCta),
    lunchRequestTitle = store.getMessage("home.lunch_request_title", lunchRequestTitle),
    lunchTakeBreakCta = store.getMessage("home.lunch_take_break", lunchTakeBreakCta),
    lunchSkipBreakCta = store.getMessage("home.lunch_skip_break", lunchSkipBreakCta),
    lunchEndConfirmTitle = store.getMessage("break_confirm.title", lunchEndConfirmTitle),
    lunchEndConfirmPrimaryCta = store.getMessage("break_confirm.cta_end_break", lunchEndConfirmPrimaryCta),
    lunchEndConfirmSecondaryCta =
        store.getMessage("break_confirm.cta_go_back", lunchEndConfirmSecondaryCta),
    suspendedTitle = store.getMessage("account_suspended", suspendedTitle),
    suspendedTitleAadhaar = store.getMessage("account_suspended_aadhaar", suspendedTitleAadhaar),
    suspendedComeBackCta = store.getMessage("come_back_to_work", suspendedComeBackCta),
    suspendedRequestSubmittedCta = store.getMessage("request_submitted", suspendedRequestSubmittedCta),
    suspendedUpdateAadhaarCta = store.getMessage("update_aadhaar", suspendedUpdateAadhaarCta),
    suspendedGoToEarningsCta = store.getMessage("go_to_earnings", suspendedGoToEarningsCta),
    callInitiated = store.getMessage("job.contact.call_initiated", callInitiated),
    callNumberUnavailable = store.getMessage("job.contact.call_number_unavailable", callNumberUnavailable),
)
