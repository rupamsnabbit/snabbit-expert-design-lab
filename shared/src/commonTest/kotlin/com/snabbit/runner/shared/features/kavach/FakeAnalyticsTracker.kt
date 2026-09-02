package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/** Records every track() call for assertions. */
class FakeAnalyticsTracker : AnalyticsTracker {
    data class Tracked(val name: String, val props: Map<String, Any?>)

    val tracked = mutableListOf<Tracked>()
    fun names() = tracked.map { it.name }
    fun last(name: String) = tracked.lastOrNull { it.name == name }

    override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) {
        tracked += Tracked(name, props)
    }

    override fun identify(userId: String?) {}
    override fun reset() {}
    override fun setUserProperty(key: String, value: Any?) {}
    override fun onUserLogin(profile: Map<String, Any?>) {}
    override fun setUserProperties(props: Map<String, Any?>) {}
}
