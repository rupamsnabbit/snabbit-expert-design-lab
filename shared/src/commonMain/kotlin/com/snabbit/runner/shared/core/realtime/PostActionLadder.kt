package com.snabbit.runner.shared.core.realtime

/**
 * Remote Config for the post-action retry ladder (feature #4).
 *
 * The ladder is the sequence of waits BETWEEN post-action `current_state` fetches
 * after the first deadline miss — the recovery path when MQTT was connected but
 * never published the transition. Until this existed it was the one piece of the
 * post-action machinery that was NOT tunable: the deadline, the poll interval and
 * the connect timeout beside it are all RC-driven, so during an incident the
 * ladder's ~35 s tail could only be reshaped by shipping a build. Its own KDoc in
 * [EngineTuning] said as much.
 *
 * **Authored as a string, not a JSON array**, deliberately: the gateway's
 * `getStringList` decodes strictly, so a natural `[3,5,10,15]` would fail to
 * decode (numbers are not strings) and silently fall back — an operator would have
 * to know to write `["3","5","10","15"]`. The tolerant parse here accepts
 * `[3,5,10,15]`, `3,5,10,15`, and stray whitespace alike, matching the
 * bracket/CSV convention already used for `expert_job_audio_*_excluded_durations`.
 *
 * Members are namespaced on this object rather than left as top-level declarations:
 * `core.realtime` is a busy package, and `MAX_RUNGS` at top level says nothing about
 * what it bounds. Mirrors how `NetworkTuning` keeps its keys and clamps together.
 */
object PostActionLadder {

    const val KEY_SECS: String = "expert_post_action_retry_ladder_secs"

    /**
     * The shipped ladder, in ms — what a blank or unusable RC value resolves back to.
     * [EngineTuning.postActionRetryDelaysMs] defaults to this same list rather than
     * repeating it, so the two cannot drift.
     */
    val DEFAULT_MS: List<Long> = listOf(3_000, 5_000, 10_000, 15_000)

    /** Per-rung floor. Below ~1 s the fetch races the backend's own transition and burns a rung. */
    const val MIN_RUNG_SECS: Int = 1

    /** Per-rung ceiling. A single rung longer than this leaves the runner on a spinner too long. */
    const val MAX_RUNG_SECS: Int = 120

    /**
     * Rung-count cap. Each rung is a `current_state` fetch on an uncached endpoint, so
     * an over-long ladder is a load multiplier as well as a slow recovery.
     */
    const val MAX_RUNGS: Int = 6

    /**
     * Parses [authored] into a ladder of millisecond waits.
     *
     * Fail-safe by construction: a blank value, an unparseable one, or one whose rungs
     * are all invalid falls back to [DEFAULT_MS]. Individually malformed entries are
     * dropped rather than failing the whole ladder, and the result is clamped per rung
     * and truncated to [MAX_RUNGS].
     *
     * An empty ladder is NOT representable — that would mean "one fetch, then give
     * up", which is a behaviour change disguised as a tuning value. Zero it and you get
     * the shipped ladder back, consistent with the other knobs' revert semantics.
     *
     * [onAdjust] receives one human-readable line per correction applied, so the caller
     * can log what an operator's value actually became. Silent clamping is the failure
     * mode this whole knob exists to avoid: someone changing a value during an incident
     * and seeing no effect, with no signal as to why.
     */
    fun parseMs(authored: String, onAdjust: (String) -> Unit = {}): List<Long> {
        val parsed = authored.trim().trim('[', ']')
            .split(',')
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        val numeric = parsed.mapNotNull { it.toIntOrNull() }
        if (numeric.size != parsed.size) {
            onAdjust("ladder: dropped ${parsed.size - numeric.size} unparseable rung(s) in \"$authored\"")
        }

        val positive = numeric.filter { it > 0 }
        if (positive.isEmpty()) {
            if (authored.isNotBlank()) onAdjust("ladder: \"$authored\" yielded no usable rungs; using $DEFAULT_MS")
            return DEFAULT_MS
        }

        val clamped = positive.map { secs ->
            val bounded = secs.coerceIn(MIN_RUNG_SECS, MAX_RUNG_SECS)
            if (bounded != secs) onAdjust("ladder: rung ${secs}s clamped to ${bounded}s")
            bounded * 1_000L
        }

        if (clamped.size > MAX_RUNGS) {
            onAdjust("ladder: ${clamped.size} rungs truncated to $MAX_RUNGS")
        }
        return clamped.take(MAX_RUNGS)
    }
}
