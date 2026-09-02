package com.snabbit.runner.shared.core.analytics

/**
 * Stable provider identifiers shared by [AnalyticsProvider.tag] and the
 * [AnalyticsRouteTable]. Centralised so a route table key can never drift
 * from the tag a provider actually reports — a mismatch would otherwise
 * silently misroute (the event would fall through to the route table's
 * `default` set with no error; see [AnalyticsRouteTable]).
 *
 * Values intentionally match the existing provider display tags, so crash
 * report metadata and log lines are unchanged by the routing migration.
 */
object ProviderKeys {
    const val APPSFLYER = "AppsFlyer"
    const val MIXPANEL = "Mixpanel"
    const val CLEVERTAP = "CleverTap"

    /** Every valid provider key. Route-table validation checks references
     *  against this so a typo (which union routing would otherwise swallow)
     *  is flagged. A key that is valid but currently unregistered (e.g.
     *  Mixpanel with no token) is NOT a typo — it just means those routes
     *  are no-ops until the provider is enabled. */
    val ALL: Set<String> = setOf(APPSFLYER, MIXPANEL, CLEVERTAP)
}
