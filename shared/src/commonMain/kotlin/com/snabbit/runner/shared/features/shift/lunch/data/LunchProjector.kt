package com.snabbit.runner.shared.features.shift.lunch.data

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.shift.lunch.domain.model.LunchPhase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Typed read model the Home VM consumes for the break lifecycle. Decodes the
 * three `LUNCH_*` widget envelopes into a [LunchPhase]; every other widget emits
 * `null` (the home is not in a break). Sibling of `home/data/ShiftProjector`
 * (whose `toPhase` leaves `LUNCH_*` at `PreShift` — this model owns them).
 *
 * All instants are resolved to **absolute epoch-millis here**, so the VM ticker
 * is pure `now()` arithmetic. A malformed envelope (missing/garbage timestamps)
 * is logged and collapses to `null` — stale-but-valid beats a crash, matching
 * `RunnerStateStore`'s philosophy.
 *
 * Concrete class, no interface — matches `ShiftProjector` / `coreModule`.
 */
class LunchProjector(
    private val store: RunnerStateStore,
    scope: CoroutineScope,
    private val logger: Logger,
) {
    private val _phase = MutableStateFlow<LunchPhase?>(null)

    /** Latest decoded break phase, or `null` when the runner is not on a break. */
    val phase: StateFlow<LunchPhase?> = _phase.asStateFlow()

    init {
        scope.launch {
            store.state.collect { _phase.value = toPhase(it) }
        }
    }

    /** Ask Dart to re-fetch `current_state` (e.g. after an accept/deny/end). */
    fun requestRefresh() = store.requestRefresh()

    private fun toPhase(e: RunnerState?): LunchPhase? {
        val name = e?.widgetName ?: return null
        return when (name) {
            LUNCH_REQUEST -> LunchPhase.Request
            LUNCH_COOLDOWN -> e.widgetData?.let { toCooldown(it) }
            LUNCH_ACTIVE -> e.widgetData?.let { toOnBreak(it) }
            else -> null
        }
    }

    private fun toCooldown(d: JsonObject): LunchPhase? {
        val breakStartMs = d.isoMillis("start_time") ?: return logNull("LUNCH_COOLDOWN", "start_time")
        val cooldownEndMs = d.cooldownEndMs() ?: return logNull("LUNCH_COOLDOWN", "cooldown_start_time")
        val breakTotalSec = d.minutes("duration") * SECONDS_PER_MIN
        return LunchPhase.Cooldown(
            cooldownEndMs = cooldownEndMs,
            breakStartMs = breakStartMs,
            breakEndMs = breakStartMs + breakTotalSec * MILLIS_PER_SEC,
            breakTotalSec = breakTotalSec,
        )
    }

    private fun toOnBreak(d: JsonObject): LunchPhase? {
        val breakStartMs = d.isoMillis("start_time") ?: return logNull("LUNCH", "start_time")
        val breakTotalSec = d.minutes("duration") * SECONDS_PER_MIN
        // No explicit cooldown on the active envelope → the break is already
        // live, so the cooldown window collapses to the break start.
        val cooldownEndMs = d.cooldownEndMs() ?: breakStartMs
        return LunchPhase.OnBreak(
            cooldownEndMs = cooldownEndMs,
            cooldownStartMs = d.isoMillis("cooldown_start_time"),
            breakStartMs = breakStartMs,
            breakEndMs = breakStartMs + breakTotalSec * MILLIS_PER_SEC,
            breakTotalSec = breakTotalSec,
            greenStateSec = d.minutes("green_state_duration") * SECONDS_PER_MIN,
            amberStateSec = d.minutes("amber_state_duration") * SECONDS_PER_MIN,
            redStateSec = d.minutes("red_state_duration") * SECONDS_PER_MIN,
        )
    }

    /** `cooldown_start_time + cooldown_duration` as epoch-millis, or null when absent. */
    private fun JsonObject.cooldownEndMs(): Long? {
        val startMs = isoMillis("cooldown_start_time") ?: return null
        return startMs + minutes("cooldown_duration") * SECONDS_PER_MIN * MILLIS_PER_SEC
    }

    private fun logNull(widget: String, field: String): LunchPhase? {
        logger.w(TAG, "$widget envelope missing/invalid `$field`; dropping break phase")
        return null
    }

    /** Parse an ISO-8601 datetime to epoch-millis. Accepts `Z`/offset (e.g.
     *  `2026-06-29T10:00:00Z`) AND naive timestamps without zone (e.g.
     *  `2026-06-29T21:39:00.472071` — what maestro-core actually sends). Naive
     *  values are resolved against the device's current timezone, matching
     *  Dart's `DateTime.parse` so the Flutter and CMP homes agree. Null on
     *  garbage. */
    @OptIn(kotlin.time.ExperimentalTime::class)
    private fun JsonObject.isoMillis(key: String): Long? {
        val raw = this[key]?.takeIf { it !is JsonNull }?.jsonPrimitive?.content ?: return null
        return try {
            Instant.parse(raw).toEpochMilliseconds()
        } catch (_: IllegalArgumentException) {
            try {
                LocalDateTime.parse(raw)
                    .toInstant(TimeZone.currentSystemDefault())
                    .toEpochMilliseconds()
            } catch (_: IllegalArgumentException) {
                logger.w(TAG, "unparseable ISO time for `$key`: $raw")
                null
            }
        }
    }

    /**
     * Integer minutes field, 0 when absent/non-numeric.
     *
     * Parsed via `toDoubleOrNull` — NOT `intOrNull`, which rejects the decimals
     * this backend actually sends (`duration: 30.0`), silently yielding 0 and
     * collapsing every break band to a NaN ring. Same reason `ShiftProjector`
     * has its own `doubleOrNull`. A present-but-unparseable value is logged
     * rather than falling to 0 in silence.
     */
    private fun JsonObject.minutes(key: String): Int {
        val raw = this[key]?.takeIf { it !is JsonNull }?.jsonPrimitive?.content ?: return 0
        return raw.toDoubleOrNull()?.toInt()
            ?: run {
                logger.w(TAG, "unparseable minutes for `$key`: $raw; defaulting to 0")
                0
            }
    }

    private companion object {
        const val TAG = "LunchProjector"
        const val LUNCH_REQUEST = "LUNCH_REQUEST"
        const val LUNCH_COOLDOWN = "LUNCH_COOLDOWN"
        const val LUNCH_ACTIVE = "LUNCH"
        const val SECONDS_PER_MIN = 60
        const val MILLIS_PER_SEC = 1_000L
    }
}
