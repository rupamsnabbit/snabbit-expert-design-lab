package com.snabbit.runner.shared.features.gamification.presentation

import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ResolveNudgeLabelTest {

    @Test
    fun legacyLiteral_returnsText() {
        val label = NudgeLabel.literal("Just do it")
        assertEquals("Just do it", ResolveNudgeLabel.resolve(label))
    }

    @Test
    fun defaultText_substitutesParams() {
        val label = NudgeLabel(
            key = "nudge_early_login_avoid_no_show",
            params = mapOf("time" to "04:00 pm"),
            defaultText = "Login by {{time}} to avoid No Show",
        )
        assertEquals("Login by 04:00 pm to avoid No Show", ResolveNudgeLabel.resolve(label))
    }

    @Test
    fun noDefaultText_usesEnglishFallback_keepsBoldMarkers() {
        val label = NudgeLabel(key = "nudge_long_distance_bonus")
        assertEquals("**Accept long distance job** to earn", ResolveNudgeLabel.resolve(label))
    }

    @Test
    fun falseAttendance_withRedCards_substitutes() {
        val label = NudgeLabel(
            key = "nudge_false_attendance_penalty",
            params = mapOf("redCards" to "3"),
        )
        assertEquals("**False attendance** — **3** red cards penalty", ResolveNudgeLabel.resolve(label))
    }

    @Test
    fun falseAttendance_missingRedCards_usesSafeFallback() {
        val label = NudgeLabel(key = "nudge_false_attendance_penalty")
        assertEquals(
            "**False attendance** — red card penalty may apply",
            ResolveNudgeLabel.resolve(label),
        )
    }

    @Test
    fun unknownKey_withoutDefault_isEmpty() {
        assertTrue(ResolveNudgeLabel.resolve(NudgeLabel(key = "nudge_brand_new")).isEmpty())
    }
}
