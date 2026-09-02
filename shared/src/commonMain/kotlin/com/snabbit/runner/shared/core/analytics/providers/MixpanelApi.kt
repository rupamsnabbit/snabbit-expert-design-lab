package com.snabbit.runner.shared.core.analytics.providers

/**
 * Thin seam over the native Mixpanel SDK so [MixpanelProvider] is
 * unit-testable without the SDK on the test classpath. The real
 * implementation (`AndroidMixpanelApi`, androidMain) wraps
 * `com.mixpanel.android` and is supplied by the platform Koin module;
 * tests use [com.snabbit.runner.shared.core.analytics.providers.FakeMixpanelApi].
 *
 * Methods mirror the subset of the SDK the runner app uses. [initialize]
 * corresponds to `Mixpanel.getInstance(ctx, token)`; the SDK buffers
 * track/identify calls made before it returns, satisfying the
 * pre-start tolerance contract on [com.snabbit.runner.shared.core.analytics.AnalyticsProvider.start].
 */
internal interface MixpanelApi {
    fun initialize()
    fun track(name: String, props: Map<String, Any>)
    fun identify(distinctId: String)
    fun reset()
    fun setUserProperty(key: String, value: Any?)

    /**
     * Batch variant of [setUserProperty] — maps to `people.set(JSONObject)`
     * on the native SDK, a single `$set` payload. Preferred entry point for
     * profile writes that touch >1 key (e.g. `MixpanelSetup.setUserProfile`)
     * so the MethodChannel does one crossing instead of N.
     */
    fun setUserProperties(props: Map<String, Any>)
}
