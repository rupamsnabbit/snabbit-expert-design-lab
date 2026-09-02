package com.snabbit.runner.shared.core.analytics

/**
 * Event-keyed analytics router. Given an event name, decides which
 * providers (by [AnalyticsProvider.tag] / [ProviderKeys]) should receive
 * it. Consulted by [AnalyticsTrackerImpl.track] before fan-out.
 *
 * **Union semantics.** An event's destinations are
 * `default ∪ table[event]`:
 * - [default] is the set of providers that receive *every* event unless
 *   stated otherwise — today the "universal sink" (Mixpanel).
 * - [table] holds explicit per-event overlays — e.g. AppsFlyer's
 *   attribution events. An overlay *adds* destinations on top of
 *   [default]; it does not replace it. So an event listed `→ {AppsFlyer}`
 *   still reaches Mixpanel while Mixpanel is in [default].
 *
 * This degrades cleanly to a fully-selective end state: once no provider
 * is a universal sink, [default] is empty and each event is routed solely
 * by its explicit [table] entry, with [onUnrouted] catching any gap.
 *
 * **No silent drops.** If an event resolves to zero destinations (unlisted
 * and [default] empty), [onUnrouted] is invoked so the miss is observable
 * (wired to logging + sampled crash reporting at construction) rather than
 * vanishing — the failure mode the old Dart-side allowlist never guarded.
 *
 * `identify`/`reset`/`setUserProperty` are NOT routed through here; they
 * fan to every provider (see [AnalyticsTracker]).
 */
class AnalyticsRouteTable(
    private val table: Map<String, Set<String>>,
    private val default: Set<String>,
    private val onUnrouted: (String) -> Unit,
) {
    fun destinationsFor(event: String): Set<String> {
        val destinations = default + (table[event] ?: emptySet())
        if (destinations.isEmpty()) onUnrouted(event)
        return destinations
    }
}
