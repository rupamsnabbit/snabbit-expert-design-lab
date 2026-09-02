package com.snabbit.runner.shared.features.job.delayedcheckin.domain.model

import kotlin.jvm.JvmInline

/**
 * Remaining seconds on the delayed check-in countdown, formatted for display.
 *
 * Wraps a non-negative second count — [ReachByTicker][com.snabbit.runner.shared.features.job.delayedcheckin.presentation.ReachByTicker]
 * clamps at zero before emitting, and [display] clamps again defensively so
 * a stray negative value (e.g. a hand-built instance in a test) never
 * renders as `"-01:00"`.
 */
@JvmInline
value class ReachBy(val remainingSeconds: Int) {

    /**
     * `mm:ss` countdown display, e.g. `272` seconds -> `"04:32"`. Parks at
     * `"00:00"` once expired — never goes negative. Common Kotlin has no
     * `String.format`, so the minute/second components are hand zero-padded.
     */
    fun display(): String {
        val clamped = remainingSeconds.coerceAtLeast(0)
        val minutes = clamped / SECONDS_PER_MINUTE
        val seconds = clamped % SECONDS_PER_MINUTE
        return "${minutes.pad()}:${seconds.pad()}"
    }

    private fun Int.pad(): String = toString().padStart(2, '0')

    private companion object {
        const val SECONDS_PER_MINUTE = 60
    }
}
