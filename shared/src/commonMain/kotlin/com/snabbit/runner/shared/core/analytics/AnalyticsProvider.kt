package com.snabbit.runner.shared.core.analytics

/**
 * Vendor SPI. One implementation per analytics provider (AppsFlyer,
 * Mixpanel — future, etc.). Implementations are registered in the
 * platform Koin module
 * ([com.snabbit.runner.shared.core.analytics.di.analyticsModule] + the
 * platform-specific factory) and discovered via
 * `getAll<AnalyticsProvider>()`.
 *
 * Failure isolation: callers (the tracker) wrap every call site in
 * `runCatching`. Providers may throw from any method; the tracker logs
 * and reports to the crash reporter.
 *
 * See LLD §4.1.
 */
interface AnalyticsProvider {

    /**
     * Short stable label for logs + crash-report metadata, e.g.
     * `"AppsFlyer"`. Used wherever the tracker needs to attribute a
     * failure or log line to a specific provider.
     */
    val tag: String

    /**
     * Called once at bootstrap from
     * [com.snabbit.runner.shared.core.KmpBootstrap.initialize] via
     * [AnalyticsTrackerImpl.bootstrap]. Vendor-specific (e.g. AppsFlyer:
     * `init` + `start`). Throws — caller catches, disables this provider,
     * logs.
     *
     * **Pre-start tolerance.** Implementations MUST tolerate
     * [track]/[identify]/[reset] being invoked before [start] completes —
     * the tracker does not gate calls on bootstrap completion (KMP bootstrap
     * is fire-and-forget on `Dispatchers.Main`, and Dart callers can fire
     * the first event in the same frame). Either buffer internally
     * (AppsFlyer's SDK does this) or no-op gracefully until [start] returns.
     */
    suspend fun start()

    /**
     * Vendor-specific event log. Props are pre-sanitised by
     * [PropertyValue.sanitize] — null values are stripped, integral
     * types widened to [Long]. The non-null value type is enforced by
     * the parameter signature so vendor adapters can call SDK overloads
     * that require `Map<String, Any>` without an unchecked cast.
     */
    fun track(name: String, props: Map<String, Any>)

    /** Null = clear identity. */
    fun identify(userId: String?)

    /** Reset device-scope state. */
    fun reset()

    /**
     * Set a persistent user property (Mixpanel `people.set`). Default
     * no-op so providers with no user-property concept (e.g. AppsFlyer)
     * inherit it and are unaffected. Value is nullable — vendor adapters
     * decide how to handle null. Not routed through [AnalyticsRouteTable];
     * the tracker fans it to every provider, same as [identify]/[reset].
     */
    fun setUserProperty(key: String, value: Any?) {}

    /**
     * Set/switch the user profile (CleverTap `onUserLogin`). Default no-op
     * so providers without the concept (AppsFlyer, Mixpanel) ignore it.
     */
    fun onUserLogin(profile: Map<String, Any?>) {}

    /**
     * Batch variant of [setUserProperty]. Default no-op for the same
     * reason. Props are pre-sanitised. Vendor adapters that have a native
     * batch primitive (Mixpanel `people.set(JSONObject)`) should override
     * to emit a single payload instead of N single-key calls.
     */
    fun setUserProperties(props: Map<String, Any>) {}
}
