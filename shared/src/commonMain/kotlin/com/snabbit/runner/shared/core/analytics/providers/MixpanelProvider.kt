package com.snabbit.runner.shared.core.analytics.providers

import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.ProviderKeys

/**
 * Mixpanel [AnalyticsProvider]. Platform-agnostic: all SDK contact goes
 * through the [MixpanelApi] seam, so this lives in commonMain and is
 * contract-tested with a fake. The platform Koin module injects the real
 * `AndroidMixpanelApi` (androidMain), which wraps `com.mixpanel.android`.
 *
 * Failure isolation is the tracker's job — every call here is wrapped in
 * `runCatching` by [com.snabbit.runner.shared.core.analytics.AnalyticsTrackerImpl],
 * so this adapter stays a thin forwarder and does not catch internally.
 */
internal class MixpanelProvider(
    private val api: MixpanelApi,
) : AnalyticsProvider {

    override val tag: String = ProviderKeys.MIXPANEL

    override suspend fun start() = api.initialize()

    override fun track(name: String, props: Map<String, Any>) = api.track(name, props)

    /** Null = clear identity. Mixpanel has no "un-identify", so null is a
     * no-op here; logout clears state via [reset]. */
    override fun identify(userId: String?) {
        if (userId != null) api.identify(userId)
    }

    override fun reset() = api.reset()

    override fun setUserProperty(key: String, value: Any?) = api.setUserProperty(key, value)

    override fun setUserProperties(props: Map<String, Any>) = api.setUserProperties(props)
}
