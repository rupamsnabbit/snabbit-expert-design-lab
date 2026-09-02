package com.snabbit.runner.shared.features.kavach.shared.data

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.core.storage.StoreManager

/** Why a SOS/shield call was not issued — drives the analytics reason and the caller's toast. */
enum class PreflightBlock { NO_TOKEN, OFFLINE }

/**
 * Pre-flight for the SOS + shield APIs: don't send a request that cannot succeed.
 *
 * Two blocks, for two different reasons:
 *  - **No token** — every one of these endpoints is runner-scoped, so with no token the call can
 *    only 401, and a 401 trips the global unauthorized observer, which force-logs-out and wipes the
 *    runner's stored token. Skipping is strictly better than sending.
 *  - **Offline** — the request cannot reach the server; failing fast lets the caller say so.
 *
 * Only [ConnectivityStatus.Offline] blocks. [ConnectivityStatus.BadConnection] is allowed through:
 * runners work in poor-signal places, and a slow connection still completes often enough that
 * refusing to try would lose real SOS registrations and clip uploads.
 *
 * Uses [StoreManager.awaitToken], not [StoreManager.tokenSnapshot]: on a cold start a caller can
 * outrace hydration, and a snapshot would read null for a runner who IS logged in.
 *
 * [networkMonitor] is nullable — it has no iOS Koin binding today, and an absent monitor must not
 * block calls (fail-open on connectivity, fail-closed on auth).
 */
class ApiPreflight(
    private val storeManager: StoreManager,
    private val analytics: AnalyticsTracker,
    private val networkMonitor: NetworkMonitor? = null,
) {
    /** `null` = clear to send. Non-null = do not send, and why. */
    suspend fun check(op: String): PreflightBlock? {
        if (storeManager.awaitToken().isNullOrBlank()) return block(op, PreflightBlock.NO_TOKEN)
        if (networkMonitor?.status?.value == ConnectivityStatus.Offline) {
            return block(op, PreflightBlock.OFFLINE)
        }
        return null
    }

    /** Convenience for callers that only need go/no-go. */
    suspend fun allows(op: String): Boolean = check(op) == null

    private fun block(op: String, reason: PreflightBlock): PreflightBlock {
        analytics.track(SKIPPED_EVENT, mapOf("op" to op, "reason" to reason.name.lowercase()))
        return reason
    }

    private companion object {
        const val SKIPPED_EVENT = "expert_shield_api_skipped"
    }
}
