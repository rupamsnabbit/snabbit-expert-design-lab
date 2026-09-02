package com.snabbit.runner.shared.core.analytics

/**
 * Host-supplied analytics configuration. Passed to
 * `KmpBootstrap.initialize(..., analyticsConfig = ...)`.
 *
 * Blank / missing dev key means **no AppsFlyer provider gets registered**
 * in Koin. The tracker still resolves and serves `track`/`identify`/`reset`
 * as no-ops — every loop has zero providers to iterate. This is the dev /
 * unit-test path; no extra "disabled" flag needed. See LLD §4.2 / §5.6.
 */
data class AnalyticsConfig(
    val appsFlyerDevKey: String? = null,
    val mixpanelProjectToken: String? = null,
    // CleverTap creds live in the manifest (account id/token), so this is a
    // plain on/off the host sets; default false keeps DISABLED a no-op.
    val cleverTapEnabled: Boolean = false,
    val debugLogging: Boolean = false,
    /** Event-routing data for [AnalyticsRouteTable]. Code-baked default
     *  reproduces pre-migration behaviour; hosts may override. */
    val routes: AnalyticsRoutesConfig = AnalyticsRoutesConfig.SEED,
) {
    val isAppsFlyerEnabled: Boolean
        get() = !appsFlyerDevKey.isNullOrBlank()

    val isMixpanelEnabled: Boolean
        get() = !mixpanelProjectToken.isNullOrBlank()

    companion object {
        /** No providers configured. Tracker is a no-op router. */
        val DISABLED = AnalyticsConfig()
    }
}
