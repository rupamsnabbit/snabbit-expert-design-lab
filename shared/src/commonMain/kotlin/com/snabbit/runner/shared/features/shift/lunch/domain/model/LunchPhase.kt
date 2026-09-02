package com.snabbit.runner.shared.features.shift.lunch.domain.model

/**
 * The runner's in-shift break lifecycle, decoded from the `LUNCH_*` widget
 * envelopes by [com.snabbit.runner.shared.features.shift.lunch.data.LunchProjector].
 *
 * All instants are resolved to **absolute epoch-millis at decode time** (parse
 * the ISO `start_time` / `cooldown_start_time`, add the `*_duration` minutes).
 * That keeps the presentation ticker pure `now()` arithmetic — deterministic
 * under an injected clock in tests, and robust across app restarts / re-polls
 * where the server timestamps sit in the past.
 *
 * Lifecycle → envelope mapping (Flutter `widgets_util.dart`):
 *  - [Request]  ← `LUNCH_REQUEST`   — runner is asked to take a break.
 *  - [Cooldown] ← `LUNCH_COOLDOWN`  — break accepted, counting down to start.
 *  - [OnBreak]  ← `LUNCH`           — break active (with its own pre-start
 *                                     cooldown sub-window, then the live timer).
 */
sealed interface LunchPhase {

    /** `LUNCH_REQUEST` — no timing payload; UI shows take-break / decline. */
    data object Request : LunchPhase

    /**
     * `LUNCH_COOLDOWN` — break is scheduled; the runner waits out the cooldown
     * before it starts.
     *
     * @param cooldownEndMs when the cooldown ends (break becomes active).
     * @param breakStartMs  scheduled break start.
     * @param breakEndMs    scheduled break end (`breakStartMs + breakTotalSec`).
     * @param breakTotalSec total break length in seconds (for the static ring).
     */
    data class Cooldown(
        val cooldownEndMs: Long,
        val breakStartMs: Long,
        val breakEndMs: Long,
        val breakTotalSec: Int,
    ) : LunchPhase

    /**
     * `LUNCH` — active break. Before [cooldownEndMs] the card shows the
     * "Break starts in …" sub-state, counting down [cooldownStartMs] →
     * [cooldownEndMs]; after it, the live countdown ring counts down
     * [breakTotalSec] (the break-only length — cooldown is a separate,
     * already-elapsed window by then). Ring color is a fraction-of-remaining
     * band computed in `HomeViewModel.breakColorFor` (<30% red, <50% amber,
     * else green) — [greenStateSec]/[amberStateSec]/[redStateSec] are parsed
     * from the envelope but no longer drive the band.
     *
     * @param cooldownStartMs when the pre-start cooldown began, or `null` when
     *   the envelope omitted `cooldown_start_time` (already-live break with no
     *   reported cooldown window — [cooldownEndMs] then falls back to
     *   [breakStartMs] and the starting-soon sub-state never triggers).
     */
    data class OnBreak(
        val cooldownEndMs: Long,
        val cooldownStartMs: Long?,
        val breakStartMs: Long,
        val breakEndMs: Long,
        val breakTotalSec: Int,
        val greenStateSec: Int,
        val amberStateSec: Int,
        val redStateSec: Int,
    ) : LunchPhase
}
