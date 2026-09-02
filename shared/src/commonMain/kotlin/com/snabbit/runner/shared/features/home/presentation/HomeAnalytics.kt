package com.snabbit.runner.shared.features.home.presentation

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/**
 * Expert-v2 analytics for the Home surface (PRD M2) and its attendance (M5) +
 * lunch (M6) facets, which all live on [HomeViewModel]. Routed to Mixpanel +
 * CleverTap via `AnalyticsRoutesConfig`.
 *
 * These are NET-NEW spec events. The legacy inline Home events
 * (`home_saathi_button_clicked`, `home_banner_clicked`, `break_confirm_end_button_clicked`,
 * `expert_wants_to_join_back`) are left firing as-is for non-KMP parity — this
 * wrapper fires the new names ALONGSIDE them (additive, no rename).
 */
class HomeAnalytics(private val tracker: AnalyticsTracker) {

    /** Home shown / primary panel resolved. */
    fun screenLoaded(primaryState: String, loadTrigger: String) =
        tracker.track(
            EVENT_LOAD,
            mapOf(PROP_PRIMARY_STATE to primaryState, PROP_LOAD_TRIGGER to loadTrigger),
        )

    /** Top app-bar item tapped (sos / saathi / coins). */
    fun topBarCta(ctaText: String) =
        tracker.track(EVENT_TOP_BAR_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** Primary-panel CTA tapped (login / logout / navigate_hotspot / seva_*). */
    fun cta(ctaText: String) =
        tracker.track(EVENT_CTA, mapOf(PROP_CTA_TEXT to ctaText))

    /** Banner tapped. */
    fun bannerCta(bannerId: String, clickPath: String) =
        tracker.track(
            EVENT_BANNER_CTA,
            mapOf(PROP_CTA_TEXT to CTA_BANNER, PROP_BANNER_ID to bannerId, PROP_BANNER_DEEPLINK to clickPath),
        )

    /** Post-logout / auto-logout mark-attendance sheet shown. */
    fun markAttendanceSheetShown(markingContext: String) =
        tracker.track(EVENT_MARK_LOAD, mapOf(PROP_MARKING_CONTEXT to markingContext))

    /** Provisional attendance marked (home-inline card or post-logout sheet). */
    fun markAttendance(present: Boolean, markingContext: String) =
        tracker.track(
            EVENT_MARK_CTA,
            mapOf(
                PROP_CTA_TEXT to if (present) CTA_MARK_PRESENT else CTA_MARK_ABSENT,
                PROP_ATTENDANCE_MARKED to if (present) STATUS_PRESENT else STATUS_ABSENT,
                PROP_MARKING_CONTEXT to markingContext,
            ),
        )

    /** Absent-confirmation (earning-loss) sheet shown. */
    fun absentConfirmationShown() = tracker.track(EVENT_ABSENT_LOAD)

    /** Change-attendance confirm sheet shown. `change_window` + penalty props
     *  (`earn_amount`, `red_cards_at_risk`) are DEFERRED — need time-of-day + server
     *  penalty data (see LLD). */
    fun changeAttendanceSheetShown(currentStatus: String) =
        tracker.track(EVENT_CHANGE_LOAD, mapOf(PROP_CURRENT_STATUS to currentStatus))

    /** Attendance change confirmed. */
    fun changeAttendance(present: Boolean) =
        tracker.track(
            EVENT_CHANGE_CTA,
            mapOf(
                PROP_CTA_TEXT to if (present) CTA_MARK_PRESENT else CTA_MARK_ABSENT,
                PROP_NEW_STATUS to if (present) STATUS_PRESENT else STATUS_ABSENT,
            ),
        )

    /** Red-card-waiver sheet shown (change-attendance). */
    fun redCardWaiverShown(redCardCount: Int) =
        tracker.track(EVENT_WAIVER_LOAD, mapOf(PROP_RED_CARDS_WAIVED to redCardCount))

    /** Red-card-waiver acknowledged. */
    fun redCardWaiverAck() =
        tracker.track(EVENT_WAIVER_CTA, mapOf(PROP_CTA_TEXT to CTA_WAIVER_ACK))

    /** End-break confirmation tapped. */
    fun endBreakConfirm() =
        tracker.track(EVENT_END_BREAK_CTA, mapOf(PROP_CTA_TEXT to CTA_END_BREAK))

    /** Upcoming-lunch heads-up appeared (server LUNCH_REQUEST/COOLDOWN edge). */
    fun lunchUpcomingNudge(screenContext: String) =
        tracker.track(EVENT_LUNCH_NUDGE, mapOf(PROP_SCREEN_CONTEXT to screenContext))

    /** Home page scrolled far enough to reach the "More From Snabbit" strip. */
    fun homeScrolled(bannerCount: Int, bannerIds: List<String>, firstBannerId: String?) =
        tracker.track(
            EVENT_SCROLLED,
            mapOf(
                PROP_BANNER_COUNT to bannerCount,
                PROP_BANNER_IDS to bannerIds.joinToString(","),
                PROP_FIRST_BANNER_ID to firstBannerId,
            ),
        )

    /** Logout succeeded (manual, from the Home logout CTA / attendance-chained logout). */
    fun logoutSuccess(logoutType: String = LOGOUT_MANUAL) =
        tracker.track(EVENT_LOGOUT_SUCCESS, mapOf(PROP_LOGOUT_TYPE to logoutType))

    /** Mixpanel profile: last-seen home primary state (`$set`; CleverTap no-ops). */
    fun setCurrentHomeState(state: String) =
        tracker.setUserProperties(mapOf(PROP_CURRENT_HOME_STATE to state))

    /** Mixpanel profile: next shift attendance intent (`$set`). */
    fun setNextShiftAttendance(present: Boolean) =
        tracker.setUserProperties(mapOf(PROP_NEXT_SHIFT_ATTENDANCE to if (present) STATUS_PRESENT else STATUS_ABSENT))

    /** No-show penalty observed (home state flipped to no-show while the app was open). */
    fun noShowMarked() = tracker.track(EVENT_NO_SHOW_MARKED)

    /** Mixpanel profile: last no-show timestamp (`$set`). */
    fun setLastNoShowAt(epochMs: Long) =
        tracker.setUserProperties(mapOf(PROP_LAST_NO_SHOW_AT to epochMs))

    private fun AnalyticsTracker.track(name: String) = track(name, emptyMap())

    private companion object {
        const val EVENT_LOAD = "home_screen_load"
        const val EVENT_CTA = "home_screen_cta_click"
        const val EVENT_TOP_BAR_CTA = "top_bar_cta_click"
        const val EVENT_BANNER_CTA = "home_banner_cta_click"
        const val EVENT_MARK_LOAD = "mark_attendance_bs_load"
        const val EVENT_MARK_CTA = "mark_attendance_bs_cta_click"
        const val EVENT_ABSENT_LOAD = "absent_confirmation_bs_load"
        const val EVENT_CHANGE_LOAD = "change_attendance_bs_load"
        const val EVENT_CHANGE_CTA = "change_attendance_bs_cta_click"
        const val EVENT_WAIVER_LOAD = "change_attendance_red_card_waiver_bs_load"
        const val EVENT_WAIVER_CTA = "change_attendance_red_card_waiver_bs_cta_click"
        const val EVENT_END_BREAK_CTA = "end_break_confirmation_bs_cta_click"
        const val EVENT_LUNCH_NUDGE = "lunch_upcoming_nudge_screen_load"
        const val EVENT_SCROLLED = "home_screen_scrolled"
        const val EVENT_LOGOUT_SUCCESS = "logout_success_screen_load"
        const val EVENT_NO_SHOW_MARKED = "no_show_marked"

        const val PROP_PRIMARY_STATE = "home_primary_state"
        const val PROP_LOAD_TRIGGER = "load_trigger"
        const val PROP_CTA_TEXT = "cta_text"
        const val PROP_BANNER_ID = "banner_id"
        const val PROP_BANNER_DEEPLINK = "banner_deeplink"
        const val PROP_MARKING_CONTEXT = "marking_context"
        const val PROP_ATTENDANCE_MARKED = "attendance_marked"
        const val PROP_NEW_STATUS = "new_status"
        const val PROP_RED_CARDS_WAIVED = "red_cards_waived"
        const val PROP_SCREEN_CONTEXT = "screen_context"
        const val PROP_BANNER_COUNT = "banner_count"
        const val PROP_BANNER_IDS = "banner_ids"
        const val PROP_FIRST_BANNER_ID = "first_banner_id"
        const val PROP_LOGOUT_TYPE = "logout_type"
        const val PROP_CURRENT_HOME_STATE = "current_home_state"
        const val PROP_NEXT_SHIFT_ATTENDANCE = "next_shift_attendance"
        const val PROP_CURRENT_STATUS = "current_status"
        const val LOGOUT_MANUAL = "manual"
        const val PROP_LAST_NO_SHOW_AT = "last_no_show_at"

        const val CTA_BANNER = "banner_click"
        const val CTA_MARK_PRESENT = "mark_present"
        const val CTA_MARK_ABSENT = "mark_absent"
        const val CTA_WAIVER_ACK = "i_will_not_repeat_again"
        const val CTA_END_BREAK = "end_break"
        const val STATUS_PRESENT = "present"
        const val STATUS_ABSENT = "absent"
    }
}
