package com.snabbit.runner.shared.features.profile

/** A Flutter route + its string args, resolved by [ProfileRouteDecider]. */
data class FlutterRoute(
    val route: String,
    val args: Map<String, String> = emptyMap(),
)

/**
 * The single source of truth for "which Flutter page do Monthly-earnings and Refer &
 * earn open, given the runner's rate-card / Remote-Config state". Pure + iOS-safe so
 * it's shared by BOTH the Profile menu tiles ([com.snabbit.runner.shared.features.profile.ui.buildProfileSections])
 * and the bottom-nav Earnings / Refer tabs — the two surfaces stay in lockstep
 * (drawer parity) instead of duplicating the gating.
 */
object ProfileRouteDecider {

    /** RC flag: gates the Monthly-earnings **tile's visibility** (the route is gated by `isRateCardV2Effective`). Default true. */
    const val RC_SHOW_EARNINGS = "expert_show_earnings"

    /** RC flag: Refer & earn → referrals webview (v2) vs native ReferralsHome. Default false. */
    const val RC_REFERRALS_V2 = "expert_is_referrals_v2_enabled"

    /**
     * Monthly earnings: v2 rate-card runners → the monthly-summary webview; everyone
     * else → the native PayoutHome (drawer parity).
     */
    fun monthlyEarnings(isRateCardV2Effective: Boolean): FlutterRoute =
        if (isRateCardV2Effective) {
            FlutterRoute(
                ProfileFlutterRoutes.APP_WEB_VIEW,
                mapOf(
                    "webviewPath" to ProfileFlutterRoutes.WEBVIEW_MONTHLY_SUMMARY,
                    "title" to "Earnings",
                ),
            )
        } else {
            FlutterRoute(ProfileFlutterRoutes.PAYOUT_HOME)
        }

    /**
     * Refer & earn: RC v2 → the referrals webview (with `entryPoint` attribution, e.g.
     * `"profile_menu"` from the tile or `"refer_tab"` from the bottom-nav tab) vs the
     * native ReferralsHome (drawer parity).
     */
    fun referAndEarn(referralsV2Enabled: Boolean, entryPoint: String): FlutterRoute =
        if (referralsV2Enabled) {
            FlutterRoute(
                ProfileFlutterRoutes.APP_WEB_VIEW,
                mapOf(
                    "webviewPath" to ProfileFlutterRoutes.WEBVIEW_REFERRALS_HOME,
                    "title" to "Refer & earn",
                    "entryPoint" to entryPoint,
                ),
            )
        } else {
            FlutterRoute(ProfileFlutterRoutes.REFERRAL_HOME)
        }
}
