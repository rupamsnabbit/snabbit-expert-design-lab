package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger

/**
 * Handles analytics events that resolved to zero destinations (unlisted in
 * the route table and no `default` provider). Supplies the `onUnrouted`
 * callback to [AnalyticsRouteTable].
 *
 * Every occurrence is logged at WARN and reported to the crash reporter so
 * a missing route surfaces immediately. The crash reporter is the safety
 * net for spam — if a hot unrouted event becomes noisy, rate-limit there.
 */
internal class UnroutedEventReporter(
    private val logger: Logger,
    private val crashReporter: CrashReporter,
) {
    fun onUnrouted(event: String) {
        logger.w(TAG, "Unrouted analytics event (no destination): '$event'")
        crashReporter.report(
            IllegalStateException("Unrouted analytics event: '$event'"),
            mapOf("op" to "routeAnalytics", "event" to event),
        )
    }

    private companion object {
        const val TAG = "AnalyticsRouter"
    }
}
