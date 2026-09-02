package com.snabbit.runner.shared.features.profile

/**
 * Names of the existing Flutter routes the Profile tiles open (must match the
 * `appRoutes` map in `lib/main.dart` — the keep-host bridge resolves the widget
 * via `appRoutes[route]`). Tiles hand off through [ProfileUiIntent.OpenFlutterRoute];
 * the `:app` registration performs the keep-host round trip so the user returns to
 * the Profile tab.
 *
 * Not listed (intentionally not wired in this cut):
 *  - Language — a native nav destination (`LanguageDestination`), not a Flutter route.
 *  - Emergency logout — an in-place overlay in HomeRoot (Pallav's flow).
 *  - Loan / PAN — PARKED.
 *
 * Webviews (Seva/Merch/rate-card/earnings-v2) open the generic [APP_WEB_VIEW]
 * route with either a full `url` (Seva/Merch — from runners/me) or a `webviewPath`
 * that `AppWebViewPage` resolves via `buildWebviewUrl(...)` (rate-card / earnings-v2).
 */
object ProfileFlutterRoutes {
    const val PAYOUT_HOME = "/payout-home"
    const val TRANSACTION_HISTORY = "/transaction-history"
    const val EARLY_PAYOUTS = "/early-payouts"
    const val REFERRAL_HOME = "/referral-home"
    const val INSURANCE_SUPPORT = "/insurance-support"
    const val LONG_LEAVE = "/long-leave"
    const val AADHAAR_REVERIFICATION = "/aadhaar-reverification"
    const val ADD_BANK_OR_UPI = "/add_bank_or_upi_details"

    /** Header tap → the runner's identity card (`IdentityCard.routeName` — no leading slash). */
    const val IDENTITY_CARD = "identity-card"

    /** "Improve Ratings" CTA → the Performance page (`Performance.routeName`). */
    const val PERFORMANCE = "/performance"

    /** Debug Menu (`DebugMenu.routeName`) — only registered in `appRoutes` in debug builds. */
    const val DEBUG_MENU = "/debug_menu"

    /** Generic Flutter webview page — args: `url` OR `webviewPath` (+ `title`, `fetchLocation`). */
    const val APP_WEB_VIEW = "/app-web-view"

    // Webview paths — resolved to full URLs Flutter-side via buildWebviewUrl(...).
    const val WEBVIEW_MONTHLY_SUMMARY = "v1/payouts/monthly-summary"
    const val WEBVIEW_RATE_CARD = "v1/payouts/rate-card-education"

    /** Vishwaas rate-card webview — opened by the header Vishwaas banner tap. */
    const val WEBVIEW_VISHWAAS_RATE_CARD = "v1/payouts/vishwaas-rate-card"

    /**
     * Referrals v2 webview (drawer parity — opened only when RC
     * `expert_is_referrals_v2_enabled` is on; else the native [REFERRAL_HOME]).
     * Pair with the `entryPoint` webview arg (`"profile_menu"`) so Flutter appends
     * `entry_point=profile_menu` to the URL, matching the drawer's attribution.
     */
    const val WEBVIEW_REFERRALS_HOME = "v1/referrals/home"

    /**
     * Tiering insurance webviews — when `isTieringEnabled`, the generic "Insurance" tile
     * splits into two Profile menu items (Accident + Health), each opening its own webview
     * via [APP_WEB_VIEW] `webviewPath` (drawer parity — `drawer_menu.dart`).
     */
    const val WEBVIEW_INSURANCE_ACCIDENT = "v1/insurance/accident"
    const val WEBVIEW_INSURANCE_HEALTH = "v1/insurance/health"

    /**
     * Tiering webviews that REPLACE a native destination when `isTieringEnabled` (drawer parity):
     *  - Early Payout: the native [EARLY_PAYOUTS] screen → this webview.
     *  - Loan: the native loan sheet → this webview.
     */
    const val WEBVIEW_EARLY_PAYOUT = "v1/early-payout"
    const val WEBVIEW_LOAN = "v1/loan"

    const val WEBVIEW_NOTIFICATION_CENTRE = "v1/notification-centre"
}
