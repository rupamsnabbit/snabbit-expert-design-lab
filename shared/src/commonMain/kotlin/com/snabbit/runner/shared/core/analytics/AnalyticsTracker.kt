package com.snabbit.runner.shared.core.analytics

/**
 * Public analytics surface — pure fan-out. Every `track` reaches every
 * registered provider; `identify` and `reset` do the same.
 *
 * Event filtering happens **upstream on the Dart side** in
 * `lib/services/analytics/analytics_routes.dart`. Non-allowlisted
 * events never cross the MethodChannel into this surface, so the
 * tracker doesn't carry a route table. Making the allowlist Dart-side
 * means routing changes ship via Shorebird Code Push instead of a Play
 * Store release.
 *
 * `setUserProperty`, `flush`, and `traits` are deliberately absent in v1
 * (AppsFlyer supports none of them).
 *
 * Provider lifecycle (init/start) is intentionally **not** on this
 * contract. It lives on the SPI as [AnalyticsProvider.start] and is driven
 * exactly once by `KmpBootstrap` via the impl-only `bootstrap()`. Kept off
 * the public surface because: `start()` is `suspend` while this interface
 * is synchronous fire-and-forget (the Dart MethodChannel bridge), and
 * providers must already tolerate `track`/`identify`/`reset` before
 * `start()` completes (see [AnalyticsProvider]'s pre-start contract) — so
 * there's no "initialize first" precondition for callers to satisfy.
 */
interface AnalyticsTracker {

    /**
     * Fire an event to every registered provider.
     *
     * @param name Event name. Already filtered by the Dart-side
     *             `analyticsRoutes` allowlist before reaching here.
     * @param props Property bag. Sanitised by [PropertyValue.sanitize] —
     *              null values dropped, Int widened to Long, strings
     *              truncated at 1024 chars.
     */
    /**
     * @param targets when null, destinations come from the route table
     *   (app events). When set (webview, whose names are web-defined and
     *   not in the catalog), routes directly to those provider keys.
     */
    fun track(name: String, props: Map<String, Any?> = emptyMap(), targets: Set<String>? = null)

    /**
     * Register cross-event super-properties, merged into every [track]
     * payload before routing (call-site props win on key conflict). Later
     * calls win on conflict with earlier ones.
     *
     * Lives here (not only Dart-side) so **KMP/CMP-originated** events —
     * which call [track] directly and never cross the Dart merge — also
     * carry them. Applies to whichever providers the route table selects
     * for a given event, Mixpanel and CleverTap alike.
     *
     * Default no-op so test doubles and any tracker without a super-prop
     * store don't have to implement it; [AnalyticsTrackerImpl] overrides.
     */
    fun registerSuperProperties(props: Map<String, Any?>) = Unit

    /**
     * Drop all registered super-properties. Call on forced logout (403) so
     * one user's `runner_id` / `cluster_id` / `region_id` can't ride onto
     * the next (or logged-out) session's events. Default no-op; see
     * [registerSuperProperties].
     */
    fun clearSuperProperties() = Unit

    /**
     * Associate the device with a backend user. Null clears identity.
     * Fans to **all** registered providers — identity is not filtered
     * (every provider needs to know who the user is). For AppsFlyer
     * this calls `setCustomerUserId` + `anonymizeUser(true/false)`.
     */
    fun identify(userId: String?)

    /**
     * Clear device-scope identity. Call on logout. Fans to all
     * registered providers. AppsFlyer: `setCustomerUserId(null)` +
     * `anonymizeUser(true)`.
     */
    fun reset()

    /**
     * Set a persistent user property on every registered provider
     * (Mixpanel `people.set`; a no-op for providers without the concept,
     * e.g. AppsFlyer). **Unrouted** — like [identify]/[reset], profile
     * data is not filtered through the route table; every provider
     * receives it.
     */
    fun setUserProperty(key: String, value: Any?)

    /**
     * Set/switch the user profile (CleverTap `onUserLogin`). Unrouted —
     * fans to every provider; no-op for those without the concept.
     */
    fun onUserLogin(profile: Map<String, Any?>)

    /**
     * Batch variant of [setUserProperty]. One sanitisation pass + one
     * provider iteration; on Mixpanel a single `people.set(JSONObject)`
     * payload. Preferred for profile writes that touch multiple keys
     * (e.g. login) so the MethodChannel does one crossing instead of N.
     * Same unrouted fan-out semantics.
     */
    fun setUserProperties(props: Map<String, Any?>)
}
