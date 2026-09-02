package com.snabbit.runner.shared.ui.components

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Pins [countdownWashSteps] — the redraw budget for the urgent countdown wash.
 *
 * The wash used to re-target an 1100 ms tween every time `urgentFillProgress` changed, and it
 * changes once a second, so the animator never settled and invalidated the draw phase on every
 * frame. On-device that measured 2,668 frames / 60 s (~44 fps) and 43% of one core on the
 * delayed-check-in footer. The fix spends one redraw per device pixel the fill actually moves,
 * which is what these cases guard: long windows go quiet, short windows stay smooth, and the
 * budget is always bounded on both ends.
 */
private const val FOOTER_WIDTH_PX = 1080f

class CountdownWashStepsTest {

    @Test
    fun five_minute_window_steps_about_once_per_pixel() {
        // A 300 s check-in window advances 1/300 of the bar per second ≈ 3.6 px on a 1080 px
        // footer — a handful of redraws a second, not a frame-rate animation.
        val steps = countdownWashSteps(1f / 300f, FOOTER_WIDTH_PX)
        assertEquals(4, steps)
    }

    @Test
    fun thirty_second_window_stays_smooth() {
        // A 30 s accept window moves ~36 px/s: here the motion IS perceptible per frame, so the
        // budget rises to match. Same code path, no special-casing.
        val steps = countdownWashSteps(1f / 30f, FOOTER_WIDTH_PX)
        assertEquals(36, steps)
    }

    @Test
    fun sub_pixel_movement_still_redraws_once() {
        // An hour-long window moves far less than a pixel per tick; the bar must still advance
        // eventually rather than being rounded away to zero steps (which would freeze it).
        val steps = countdownWashSteps(1f / 3600f, FOOTER_WIDTH_PX)
        assertEquals(1, steps)
    }

    @Test
    fun large_jump_is_capped_at_the_frame_budget() {
        // A jump across the whole bar (e.g. first paint mid-window) must not schedule 1080
        // redraws: the cap keeps the step interval at or above ~17 ms, i.e. one frame at 60 Hz.
        val steps = countdownWashSteps(1f, FOOTER_WIDTH_PX)
        assertEquals(64, steps)
        assertTrue(1100L / steps >= 16L, "step interval must not outpace a 60 Hz frame")
    }

    @Test
    fun zero_width_is_never_a_zero_or_negative_step_count() {
        // Defensive: a zero/unknown width must not produce 0 steps and divide-by-zero the
        // step interval. (The node also short-circuits before the first draw.)
        assertEquals(1, countdownWashSteps(0.5f, 0f))
        assertEquals(1, countdownWashSteps(0f, FOOTER_WIDTH_PX))
    }
}
