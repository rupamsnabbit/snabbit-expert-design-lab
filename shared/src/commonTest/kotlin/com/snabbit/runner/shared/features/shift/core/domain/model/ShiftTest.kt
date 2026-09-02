package com.snabbit.runner.shared.features.shift.core.domain.model

import kotlin.test.Test
import kotlin.test.assertEquals

class ShiftTest {
    private val day = ShiftDay("Tue, 7 Feb", "7am-12pm", "₹800", false)

    @Test fun effectiveAttendance_prefersOptimistic() {
        val s = Shift(AttendanceStatus.Absent, AttendanceStatus.Present, day, null, false, 0)
        assertEquals(AttendanceStatus.Present, s.effectiveAttendance)
    }

    @Test fun effectiveAttendance_fallsBackToServer() {
        val s = Shift(AttendanceStatus.Absent, null, day, null, true, 0)
        assertEquals(AttendanceStatus.Absent, s.effectiveAttendance)
    }

    @Test fun attendanceStatus_hasExactlyFiveStates() {
        assertEquals(5, AttendanceStatus.entries.size)
    }
}
