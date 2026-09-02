package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.core.localization.LocalizationStore

/**
 * Server-driven i18n labels for the delayed check-in penalty UI (the same
 * shape as `JobStrings`). Defaults are the English fallbacks from the Dart
 * parity sources (`job_support_bottom_sheet.dart`, `JobStrings`); the host
 * resolves each key through the language gateway and passes the result in.
 */
data class DelayedCheckinStrings(
    /** i18n key `call_support_partner` — disposition sheet title. */
    val callSupportTitle: String = "Call Support Partner",
    /** i18n key `select_option_below` — disposition sheet subtitle. */
    val callSupportSubtitle: String = "Select an option below and place call",
    /** i18n key `submit` — disposition sheet CTA. */
    val submit: String = "Submit",
    /** i18n key `getting_late_capital` — footer caption (same key as `JobStrings.runningLate`). */
    val runningLate: String = "RUNNING LATE",
    /** i18n key `check_in` — footer primary CTA (opens the check-in sheet, FR-10). */
    val checkIn: String = "Check In",
    /** i18n key `help` — footer secondary CTA before support escalates. */
    val help: String = "Help",
    /** i18n key `call_partner_support` — footer secondary CTA once escalated (opens the disposition sheet). */
    val callPartnerSupport: String = "Call Partner Support",
    /** i18n key `call_back_soon` — green toast after a callback-mode (Ameyo) submit (FR-13). */
    val callbackToast: String = "You will receive a call back soon",
    /** i18n key `support_details_not_found` — error toast when `job_support` config is missing/empty (FR-11) or the ids are invalid. */
    val supportDetailsNotFound: String = "Support details not found",
    /** i18n key `helpline_unavailable` — error toast when dial mode has no helpline number (FR-13). */
    val helplineUnavailable: String = "Helpline number not available",
    /** i18n key `something_went_wrong` — error toast on a failed disposition submit (sheet stays up). */
    val submitFailed: String = "Something went wrong. Please try again.",
    /** i18n key `red_card_received` — counter pill, singular ("1 Red Card Received", design casing). */
    val redCardReceived: String = "Red Card Received",
    /** i18n key `red_cards_received` — counter pill, plural ("2 Red Cards Received", design casing). */
    val redCardsReceived: String = "Red Cards Received",
)

/**
 * Overlays the server-driven i18n map onto these [DelayedCheckinStrings]; absent keys fall
 * back to the English defaults. Keys follow the PM localization catalog (dotted); several
 * are shared with Job (check_in.cta, check_in.status_running_late, common.help).
 */
fun DelayedCheckinStrings.localized(store: LocalizationStore): DelayedCheckinStrings = copy(
    callSupportTitle = store.getMessage("call_support.title", callSupportTitle),
    callSupportSubtitle = store.getMessage("call_support.subtitle", callSupportSubtitle),
    submit = store.getMessage("call_support.cta_submit", submit),
    runningLate = store.getMessage("check_in.status_running_late", runningLate),
    checkIn = store.getMessage("check_in.cta", checkIn),
    help = store.getMessage("common.help", help),
    callPartnerSupport =
        store.getMessage("delayed_check_in.cta_call_partner_support", callPartnerSupport),
    callbackToast = store.getMessage("delayed_check_in.toast_callback", callbackToast),
    supportDetailsNotFound =
        store.getMessage("delayed_check_in.toast_support_details_not_found", supportDetailsNotFound),
    helplineUnavailable =
        store.getMessage("delayed_check_in.toast_helpline_unavailable", helplineUnavailable),
    submitFailed = store.getMessage("delayed_check_in.toast_submit_failed", submitFailed),
    redCardReceived = store.getMessage("delayed_check_in.red_card_received", redCardReceived),
    redCardsReceived =
        store.getMessage("delayed_check_in.red_cards_received_suffix", redCardsReceived),
)
