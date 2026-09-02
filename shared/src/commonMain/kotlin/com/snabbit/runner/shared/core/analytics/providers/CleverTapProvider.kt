package com.snabbit.runner.shared.core.analytics.providers

import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.ProviderKeys

/**
 * CleverTap [AnalyticsProvider]. Thin forwarder over [CleverTapApi];
 * failure isolation is the tracker's job. CleverTap identity is
 * `onUserLogin` (profile switch), not `identify`.
 */
internal class CleverTapProvider(
    private val api: CleverTapApi,
) : AnalyticsProvider {
    override val tag = ProviderKeys.CLEVERTAP
    override suspend fun start() {} // SDK auto-inits from manifest meta-data
    override fun track(name: String, props: Map<String, Any>) = api.recordEvent(name, props)
    override fun identify(userId: String?) {}
    override fun reset() {}
    override fun onUserLogin(profile: Map<String, Any?>) = api.onUserLogin(profile)
}
