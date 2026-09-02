package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * App-wide network behaviour for **every** `:shared` HTTP call — timeouts, the
 * retry policy, and the 401-burst debounce (§2.1, §3.6, §5).
 *
 * Before this existed each of these was a compile-time constant, which meant the
 * only way to change how the whole KMP surface behaves on a bad network — during
 * an outage, a slow-gateway incident, or for a flaky-network cohort — was a store
 * release. The Dart side has had a Remote-Config lever for its own current-state
 * call since `current_state_http_timeout_seconds`; this is the equivalent for
 * KMP, and it covers the whole client rather than one endpoint.
 *
 * Read through the **native** [RemoteConfigGateway] (Android: Firebase RC via the
 * official SDK; iOS: the host-provided provider, else defaults) — NOT the Pigeon
 * mirror in `core/remoteconfig`. That means no Dart-side key list has to be kept
 * in sync: these are live Firebase values on both platforms.
 */
data class NetworkTuning(
    val connectTimeoutMs: Long = DEFAULT_CONNECT_TIMEOUT_MS,
    val receiveTimeoutMs: Long = DEFAULT_RECEIVE_TIMEOUT_MS,
    /** Retry attempts AFTER the initial one. 0 disables retrying entirely. */
    val maxRetries: Int = DEFAULT_MAX_RETRIES,
    val retryBaseDelayMs: Long = DEFAULT_RETRY_BASE_DELAY_MS,
    val retryMaxDelayMs: Long = DEFAULT_RETRY_MAX_DELAY_MS,
    /** Window in which a 401 burst collapses to a single logout dispatch. */
    val unauthorizedDebounceMs: Long = DEFAULT_UNAUTHORIZED_DEBOUNCE_MS,
) {
    companion object {
        /**
         * **30 s, not the 60 s these replaced** — a deliberate behaviour change.
         * Dart already budgets 30 s for the same current-state endpoint
         * (`current_state_http_timeout_seconds`), so KMP running at 60 s meant one
         * call had two budgets depending on which client issued it. 30 s is now
         * the shipped floor for both; widen via RC if a slow-network cohort needs
         * it, rather than shipping the slower default to everyone.
         *
         * **These are per-phase budgets, not a total for the call.** One `execute()`
         * can spend the connect budget TWICE — once on the config gate, once on the
         * token gate — before a socket opens, and then Ktor applies the receive budget
         * to each retried attempt. At the shipped values the worst case for a retried
         * GET is roughly `30 + 30 + 3 x 30 + backoff` — about 150 s, not 30 s. That is
         * an improvement on the 60 s constants (~300 s), but do not read either key as
         * a wall-clock ceiling on a request.
         */
        const val DEFAULT_CONNECT_TIMEOUT_MS: Long = 30_000
        const val DEFAULT_RECEIVE_TIMEOUT_MS: Long = 30_000

        /** Unchanged from the constants they replace — see [buildKtorClient] (§5). */
        const val DEFAULT_MAX_RETRIES: Int = 2
        const val DEFAULT_RETRY_BASE_DELAY_MS: Long = 500
        const val DEFAULT_RETRY_MAX_DELAY_MS: Long = 5_000

        /** Unchanged from the constant it replaces (§3.6). */
        const val DEFAULT_UNAUTHORIZED_DEBOUNCE_MS: Long = 2_000

        /**
         * Timeout keys are in **seconds** — matching `expert_mqtt_connect_timeout_seconds`
         * and `current_state_http_timeout_seconds`, the network-timeout keys an operator
         * already tunes. Sub-second knobs stay in **ms** (as `expert_job_location_timeout_ms`
         * does), because expressing 500 ms in seconds is worse than the inconsistency.
         *
         * Deliberately `kmp`-scoped: the Dart `dio` client keeps its own separate
         * configuration (`http_service.dart`), so an un-scoped `expert_network_*` key
         * would imply a reach these do not have.
         */
        const val KEY_CONNECT_TIMEOUT_SECS: String = "expert_kmp_network_connect_timeout_secs"
        const val KEY_RECEIVE_TIMEOUT_SECS: String = "expert_kmp_network_receive_timeout_secs"
        const val KEY_MAX_RETRIES: String = "expert_kmp_network_max_retries"
        const val KEY_RETRY_BASE_DELAY_MS: String = "expert_kmp_network_retry_base_delay_ms"
        const val KEY_RETRY_MAX_DELAY_MS: String = "expert_kmp_network_retry_max_delay_ms"
        const val KEY_UNAUTHORIZED_DEBOUNCE_MS: String = "expert_kmp_network_401_debounce_ms"

        /**
         * Clamps. The timeout floor matters more than it looks: [SnabbitHttpClientImpl]
         * spends the *connect* budget on its two cold-start gates (awaiting the
         * Dart-pushed `NetworkConfig`, then token hydration) before a socket is ever
         * opened. A too-small push would therefore not just fail slow requests faster —
         * it would start failing cold-start requests that would otherwise have
         * succeeded, on every KMP surface at once. The ceiling bounds the opposite
         * mistake: a value that parks a runner behind a non-dismissible spinner.
         */
        const val MIN_CONNECT_TIMEOUT_MS: Long = 5_000
        const val MAX_CONNECT_TIMEOUT_MS: Long = 120_000
        const val MIN_RECEIVE_TIMEOUT_MS: Long = 5_000
        const val MAX_RECEIVE_TIMEOUT_MS: Long = 180_000

        /**
         * Retry ceiling. Also the value installed as Ktor's own `maxRetries` — the
         * plugin reads that once at install time, so the live per-request limit is
         * enforced inside `retryIf`/`retryOnExceptionIf` against this ceiling. Raising
         * [MAX_MAX_RETRIES] therefore requires no other change; the RC value is what
         * actually governs.
         */
        const val MAX_MAX_RETRIES: Int = 5

        const val MIN_RETRY_BASE_DELAY_MS: Long = 100
        const val MAX_RETRY_BASE_DELAY_MS: Long = 5_000
        const val MIN_RETRY_MAX_DELAY_MS: Long = 500
        const val MAX_RETRY_MAX_DELAY_MS: Long = 30_000

        const val MIN_UNAUTHORIZED_DEBOUNCE_MS: Long = 500
        const val MAX_UNAUTHORIZED_DEBOUNCE_MS: Long = 30_000
    }
}

/**
 * Resolves the current [NetworkTuning] from Remote Config.
 *
 * Two revert conventions, because the knobs differ in what "zero" means:
 *
 *  - **Durations** (timeouts, delays, debounce): non-positive means "unset" and
 *    restores the shipped default rather than clamping up to the floor — the same
 *    convention `runner_http.dart` uses for `current_state_http_timeout_seconds`,
 *    so zeroing a key gets the shipped behaviour back on both sides.
 *  - **[NetworkTuning.maxRetries]**: `0` is a *meaningful* value — "stop retrying",
 *    which is the whole reason this knob exists during an outage. So only a
 *    **negative** value reverts to the default.
 */
suspend fun networkTuning(
    rc: RemoteConfigGateway,
    onAdjust: (String) -> Unit = {},
): NetworkTuning = NetworkTuning(
    connectTimeoutMs = rc.resolveDurationMs(
        key = NetworkTuning.KEY_CONNECT_TIMEOUT_SECS,
        onAdjust = onAdjust,
        defaultMs = NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS,
        minMs = NetworkTuning.MIN_CONNECT_TIMEOUT_MS,
        maxMs = NetworkTuning.MAX_CONNECT_TIMEOUT_MS,
        unit = DurationUnit.Seconds,
    ),
    receiveTimeoutMs = rc.resolveDurationMs(
        key = NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS,
        onAdjust = onAdjust,
        defaultMs = NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS,
        minMs = NetworkTuning.MIN_RECEIVE_TIMEOUT_MS,
        maxMs = NetworkTuning.MAX_RECEIVE_TIMEOUT_MS,
        unit = DurationUnit.Seconds,
    ),
    maxRetries = rc.resolveRetryCount(onAdjust),
    retryBaseDelayMs = rc.resolveDurationMs(
        key = NetworkTuning.KEY_RETRY_BASE_DELAY_MS,
        onAdjust = onAdjust,
        defaultMs = NetworkTuning.DEFAULT_RETRY_BASE_DELAY_MS,
        minMs = NetworkTuning.MIN_RETRY_BASE_DELAY_MS,
        maxMs = NetworkTuning.MAX_RETRY_BASE_DELAY_MS,
        unit = DurationUnit.Millis,
    ),
    retryMaxDelayMs = rc.resolveDurationMs(
        key = NetworkTuning.KEY_RETRY_MAX_DELAY_MS,
        onAdjust = onAdjust,
        defaultMs = NetworkTuning.DEFAULT_RETRY_MAX_DELAY_MS,
        minMs = NetworkTuning.MIN_RETRY_MAX_DELAY_MS,
        maxMs = NetworkTuning.MAX_RETRY_MAX_DELAY_MS,
        unit = DurationUnit.Millis,
    ),
    unauthorizedDebounceMs = rc.resolveDurationMs(
        key = NetworkTuning.KEY_UNAUTHORIZED_DEBOUNCE_MS,
        onAdjust = onAdjust,
        defaultMs = NetworkTuning.DEFAULT_UNAUTHORIZED_DEBOUNCE_MS,
        minMs = NetworkTuning.MIN_UNAUTHORIZED_DEBOUNCE_MS,
        maxMs = NetworkTuning.MAX_UNAUTHORIZED_DEBOUNCE_MS,
        unit = DurationUnit.Millis,
    ),
)

/** What unit the RC value for a duration key is authored in. */
internal enum class DurationUnit(val toMillis: Long) {
    Seconds(1_000),
    Millis(1),
}

// Reads one duration key and returns a clamped millisecond budget. `getInt` is
// already default-safe (an unset key, a malformed value, or a dead SDK all resolve
// to the default we pass), so the only extra guards needed are the non-positive
// revert sentinel and the band.
private suspend fun RemoteConfigGateway.resolveDurationMs(
    key: String,
    defaultMs: Long,
    minMs: Long,
    maxMs: Long,
    unit: DurationUnit,
    onAdjust: (String) -> Unit,
): Long {
    val authoredDefault = (defaultMs / unit.toMillis).toInt()
    val authored = getInt(key, authoredDefault)
    if (authored == authoredDefault) return defaultMs
    if (authored <= 0) {
        onAdjust("$key=$authored is non-positive; reverting to the shipped ${defaultMs}ms")
        return defaultMs
    }
    val requested = authored * unit.toMillis
    val bounded = requested.coerceIn(minMs, maxMs)
    if (bounded != requested) {
        onAdjust("$key=$authored (${requested}ms) is outside [$minMs, $maxMs]ms; clamped to ${bounded}ms")
    }
    return bounded
}

// Separate from the duration path because 0 is a MEANINGFUL value here ("stop
// retrying"), so only a negative reverts.
private suspend fun RemoteConfigGateway.resolveRetryCount(onAdjust: (String) -> Unit): Int {
    val key = NetworkTuning.KEY_MAX_RETRIES
    val authored = getInt(key, NetworkTuning.DEFAULT_MAX_RETRIES)
    if (authored == NetworkTuning.DEFAULT_MAX_RETRIES) return authored
    if (authored < 0) {
        onAdjust("$key=$authored is negative; reverting to the shipped ${NetworkTuning.DEFAULT_MAX_RETRIES}")
        return NetworkTuning.DEFAULT_MAX_RETRIES
    }
    val bounded = authored.coerceAtMost(NetworkTuning.MAX_MAX_RETRIES)
    if (bounded != authored) {
        onAdjust("$key=$authored exceeds the ceiling; clamped to $bounded")
    }
    return bounded
}

/**
 * Holds the current [NetworkTuning] for the process.
 *
 * Mirrors [NetworkConfigStore]: a single Koin-owned instance, written off the hot
 * path and read on it. The read ([snapshot]) is deliberately **not** suspending —
 * [RemoteConfigGateway.getInt] hops to IO and touches SharedPreferences, which is
 * fine once at launch but not once per HTTP call (or once per retry attempt).
 *
 * Never gates a request: the store is constructed with the shipped defaults already
 * in place, so a request issued before (or instead of) the first [refresh] uses them
 * rather than waiting.
 */
class NetworkTuningStore(private val logger: Logger? = null) {
    private val _tuning = MutableStateFlow(NetworkTuning())

    /** Observable form — for diagnostics/debug surfaces; callers on the hot path read [snapshot]. */
    val tuning: StateFlow<NetworkTuning> = _tuning.asStateFlow()

    /** Non-suspending hot-path read. Always returns a usable configuration. */
    fun snapshot(): NetworkTuning = _tuning.value

    /**
     * Re-reads RC and republishes. Called from `KmpBootstrap` after
     * `fetchAndActivate()`, so the first read of the process already sees the freshly
     * activated values. Safe to call again (e.g. on a future RC-changed signal) —
     * in-flight requests keep the timeouts they resolved at start, while the retry
     * policy is read per attempt and so picks up a refresh mid-request.
     */
    suspend fun refresh(rc: RemoteConfigGateway) {
        // Every correction is reported, never applied silently. An operator changing a
        // value mid-incident and seeing no effect — because it clamped, or reverted, or
        // was unparseable — has no other way to find out. This is the same standard the
        // tunables doc applies when arguing a knob needs a feedback loop to be worth
        // shipping; it has to hold for these knobs too.
        _tuning.value = networkTuning(rc) { adjustment -> logger?.w(TAG, adjustment) }
    }

    private companion object {
        const val TAG = "NetworkTuning"
    }
}
