package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlin.concurrent.Volatile

/**
 * Fan-out [AnalyticsTracker]. `track` is routed per-event via
 * [AnalyticsRouteTable] — each event reaches only its destination
 * providers. `identify`/`reset`/`setUserProperty` are **unrouted**: they
 * fan to every registered provider (identity/profile is never filtered).
 *
 * Routing lives here (not upstream on the Dart side) so multiple selective
 * providers can each receive a different event subset from a single
 * structured table. See [AnalyticsRouteTable] for the union semantics and
 * the no-silent-drop guarantee.
 *
 * Iterates [providers] in the order Koin's `getAll<AnalyticsProvider>()`
 * returns them, which mirrors Koin module-declaration order — stable
 * across runs.
 *
 * Failure isolation: every `provider.X` call is wrapped; failures are
 * logged + reported, never rethrown (LLD §10).
 */
internal class AnalyticsTrackerImpl(
    private val providers: List<AnalyticsProvider>,
    private val routes: AnalyticsRouteTable,
    private val debugLogging: Boolean,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
) : AnalyticsTracker {

    /**
     * Fire each provider's `start()` once. Caller (KmpBootstrap) launches
     * this on a fire-and-forget coroutine — Application.onCreate does not
     * wait for completion.
     *
     * Uses raw try/catch (not `runCatching`) because the body is
     * `suspend` — `runCatching` would swallow [kotlinx.coroutines.CancellationException]
     * and break coroutine cancellation semantics.
     */
    suspend fun bootstrap() {
        for (provider in providers) {
            try {
                provider.start()
                if (debugLogging) logger.d(TAG, "${provider.tag} provider started")
            } catch (t: Throwable) {
                logger.e(TAG, "${provider.tag} provider start failed", t)
                crashReporter.report(t, mapOf("op" to "providerStart", "provider" to provider.tag))
            }
        }
    }

    /**
     * Copy-on-write so [track] (any thread/dispatcher) reads a stable
     * snapshot without a lock; writes ([registerSuperProperties] /
     * [clearSuperProperties]) are rare (launch / login / logout).
     */
    @Volatile
    private var superProps: Map<String, Any?> = emptyMap()

    override fun registerSuperProperties(props: Map<String, Any?>) {
        if (props.isNotEmpty()) superProps = superProps + props // later write wins on key
    }

    override fun clearSuperProperties() {
        superProps = emptyMap()
    }

    override fun track(name: String, props: Map<String, Any?>, targets: Set<String>?) {
        // Merge registered super-props first; call-site props win on conflict.
        val merged = if (superProps.isEmpty()) props else superProps + props
        val sanitized = PropertyValue.sanitize(merged, logger)
        if (debugLogging) logger.d(TAG, "track name='$name' keys=${sanitized.keys}")
        val destinations = targets ?: routes.destinationsFor(name)
        // Explicit targets bypass the route table, so a typo or stale rename
        // from a Dart caller would otherwise silently match no provider and
        // drop the event. Surface it once — `onUnrouted` only covers
        // catalog misses, not unknown-target misses.
        if (targets != null) {
            val unknown = destinations - providers.map { it.tag }.toSet()
            if (unknown.isNotEmpty()) {
                logger.w(TAG, "Unknown explicit targets for '$name': $unknown")
                crashReporter.report(
                    IllegalStateException("Unknown analytics targets: $unknown"),
                    mapOf("op" to "track", "name" to name, "unknown" to unknown.toString()),
                )
            }
        }
        for (provider in providers) {
            if (provider.tag !in destinations) continue
            runCatching { provider.track(name, sanitized) }
                .onFailure { reportFailure(provider, "track", name, it) }
        }
    }

    override fun identify(userId: String?) {
        for (provider in providers) {
            runCatching { provider.identify(userId) }
                .onFailure { reportFailure(provider, "identify", userId ?: "<null>", it) }
        }
    }

    override fun reset() {
        for (provider in providers) {
            runCatching { provider.reset() }
                .onFailure { reportFailure(provider, "reset", "", it) }
        }
    }

    override fun setUserProperty(key: String, value: Any?) {
        for (provider in providers) {
            runCatching { provider.setUserProperty(key, value) }
                .onFailure { reportFailure(provider, "setUserProperty", key, it) }
        }
    }

    override fun onUserLogin(profile: Map<String, Any?>) {
        for (provider in providers) {
            runCatching { provider.onUserLogin(profile) }
                .onFailure { reportFailure(provider, "onUserLogin", "", it) }
        }
    }

    override fun setUserProperties(props: Map<String, Any?>) {
        val sanitized = PropertyValue.sanitize(props, logger)
        if (sanitized.isEmpty()) return
        if (debugLogging) logger.d(TAG, "setUserProperties keys=${sanitized.keys}")
        for (provider in providers) {
            runCatching { provider.setUserProperties(sanitized) }
                .onFailure { reportFailure(provider, "setUserProperties", sanitized.keys.toString(), it) }
        }
    }

    private fun reportFailure(provider: AnalyticsProvider, op: String, name: String, t: Throwable) {
        logger.e(TAG, "${provider.tag}.$op failed for '$name'", t)
        crashReporter.report(t, mapOf("provider" to provider.tag, "op" to op, "name" to name))
    }

    private companion object {
        const val TAG = "AnalyticsTracker"
    }
}
