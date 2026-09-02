package com.snabbit.runner.shared.features.shift.presentation.emergencylogout

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/**
 * Analytics for the emergency-logout sheet — expert-v2 dictionary (PRD M4.8–4.9).
 * Thin wrapper over [AnalyticsTracker]; names are the expert-v2 spec names (net-new
 * KMP events, routed to Mixpanel + CleverTap via `AnalyticsRoutesConfig`).
 *
 * NOTE: `emergency_logout_waiver_bs_cta_click` is intentionally NOT here — the
 * waiver sheet is acknowledged in the host overlay (`PostActionOverlayHost`), not
 * this VM, so it lands when that surface is instrumented. `_waiver_bs_load` fires
 * here at the point the VM hands a waived outcome to the host.
 */
class EmergencyLogoutAnalytics(private val tracker: AnalyticsTracker) {

    /** Sheet body rendered (availability loaded). */
    fun sheetLoaded(amountAtRisk: Int?, periodLeaveAvailable: Int) =
        tracker.track(
            EVENT_LOAD,
            mapOf(PROP_AMOUNT_AT_RISK to amountAtRisk, PROP_PERIOD_LEAVE_AVAILABLE to periodLeaveAvailable),
        )

    /** "Logout" CTA (passes canConfirm). */
    fun ctaLogout(periodLeaveSelected: Boolean) =
        tracker.track(
            EVENT_CTA,
            mapOf(PROP_CTA_TEXT to CTA_LOGOUT, PROP_PERIOD_LEAVE_SELECTED to periodLeaveSelected),
        )

    /** Period-leave checkbox toggled. */
    fun ctaTogglePeriodLeave(selected: Boolean) =
        tracker.track(
            EVENT_CTA,
            mapOf(PROP_CTA_TEXT to CTA_TOGGLE, PROP_PERIOD_LEAVE_SELECTED to selected),
        )

    /** "Go back" / scrim / back press. */
    fun ctaGoBack() =
        tracker.track(EVENT_CTA, mapOf(PROP_CTA_TEXT to CTA_GO_BACK))

    /** Logout confirmed (POST returned OK). */
    fun confirmed(waiverType: String, redCardsApplied: Int, amountLost: Int?) =
        tracker.track(
            EVENT_CONFIRMED,
            mapOf(
                PROP_WAIVER_TYPE to waiverType,
                PROP_RED_CARDS_APPLIED to redCardsApplied,
                PROP_AMOUNT_LOST to amountLost,
            ),
        )

    /** One-time red-card waiver sheet shown for this emergency logout. */
    fun waiverShown(redCardsWaived: Int) =
        tracker.track(
            EVENT_WAIVER_LOAD,
            mapOf(PROP_RED_CARDS_WAIVED to redCardsWaived, PROP_WAIVER_TYPE to WAIVER_AUTO),
        )

    /** Emergency-logout waiver acknowledged (rendered + acked in the host overlay). */
    fun waiverAcknowledged() =
        tracker.track(EVENT_WAIVER_CTA, mapOf(PROP_CTA_TEXT to CTA_WAIVER_ACK))

    private companion object {
        const val EVENT_LOAD = "emergency_logout_bs_load"
        const val EVENT_CTA = "emergency_logout_bs_cta_click"
        const val EVENT_CONFIRMED = "emergency_logout_confirmed"
        const val EVENT_WAIVER_LOAD = "emergency_logout_waiver_bs_load"
        const val EVENT_WAIVER_CTA = "emergency_logout_waiver_bs_cta_click"

        const val PROP_AMOUNT_AT_RISK = "amount_at_risk"
        const val PROP_PERIOD_LEAVE_AVAILABLE = "period_leave_available"
        const val PROP_CTA_TEXT = "cta_text"
        const val PROP_PERIOD_LEAVE_SELECTED = "period_leave_selected"
        const val PROP_WAIVER_TYPE = "waiver_type"
        const val PROP_RED_CARDS_APPLIED = "red_cards_applied"
        const val PROP_AMOUNT_LOST = "amount_lost"
        const val PROP_RED_CARDS_WAIVED = "red_cards_waived"

        const val CTA_LOGOUT = "logout"
        const val CTA_TOGGLE = "toggle_period_leave"
        const val CTA_GO_BACK = "go_back"
        const val CTA_WAIVER_ACK = "i_will_not_repeat_again"
        const val WAIVER_AUTO = "auto"
    }
}
