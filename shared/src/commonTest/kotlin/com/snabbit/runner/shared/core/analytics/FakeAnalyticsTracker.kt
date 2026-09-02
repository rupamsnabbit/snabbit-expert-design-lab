package com.snabbit.runner.shared.core.analytics

/**
 * Shared recording [AnalyticsTracker] test double — the `FakeLogger` sibling.
 * Records every [track] call; the identity/user-property surface is a no-op.
 * One copy so an [AnalyticsTracker] signature change breaks a single file.
 */
class FakeAnalyticsTracker : AnalyticsTracker {
    data class Event(val name: String, val props: Map<String, Any?>)

    private val _events = mutableListOf<Event>()

    /** Every tracked event, in order. */
    val events: List<Event> get() = _events.toList()

    /** Just the event names, in order — the common assertion surface. */
    val trackedNames: List<String> get() = _events.map { it.name }

    private val _userProperties = mutableMapOf<String, Any?>()

    /** User properties set via [setUserProperty] / [setUserProperties] (last value wins). */
    val userProperties: Map<String, Any?> get() = _userProperties.toMap()

    override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) {
        _events += Event(name, props)
    }

    override fun identify(userId: String?) = Unit
    override fun reset() = Unit
    override fun setUserProperty(key: String, value: Any?) { _userProperties[key] = value }
    override fun onUserLogin(profile: Map<String, Any?>) = Unit
    override fun setUserProperties(props: Map<String, Any?>) { _userProperties.putAll(props) }
}
