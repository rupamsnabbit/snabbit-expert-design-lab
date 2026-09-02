package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/** Recording no-op [AnalyticsTracker] for camera tests — captures tracked events. */
internal class FakeAnalyticsTracker : AnalyticsTracker {
    val events = mutableListOf<Pair<String, Map<String, Any?>>>()

    override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) {
        events.add(name to props)
    }

    override fun identify(userId: String?) { /* no-op */ }

    override fun reset() { /* no-op */ }

    // Profile writes added to AnalyticsTracker by the expert-v2 merge — no-op here.
    override fun setUserProperty(key: String, value: Any?) { /* no-op */ }

    override fun onUserLogin(profile: Map<String, Any?>) { /* no-op */ }

    override fun setUserProperties(props: Map<String, Any?>) { /* no-op */ }
}
