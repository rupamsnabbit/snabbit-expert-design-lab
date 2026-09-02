package com.snabbit.runner.shared.features.shift.core.data

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class ShiftProjectorTest {

    /**
     * Route the never-completing `store.state.collect { ... }` launched in
     * [ShiftProjector.init] through [TestScope.backgroundScope] so `runTest`'s
     * foreground scope can end. Without this, every test fails with
     * `UncompletedCoroutinesError`.
     */
    private fun setup(scope: TestScope): Pair<RunnerStateStore, ShiftProjector> {
        val store = RunnerStateStore(FakeLogger())
        return store to ShiftProjector(store, scope.backgroundScope, FakeLogger())
    }

    @Test fun nullEnvelope_yieldsNullShift() = runTest {
        val (_, rm) = setup(this); runCurrent()
        assertNull(rm.state.value)
    }

    @Test fun unknownWidget_yieldsNullShift() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"RUNNER_NEW_JOB","widget_data":{}}""")
        runCurrent()
        assertNull(rm.state.value)
    }

    @Test fun tomorrowWidget_populatesTomorrowDay() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7am-12pm",
              "earning_loss_amount":800,"is_next_working_day_sunday":false}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(AttendanceStatus.Pending, s.attendance)
        assertNotNull(s.tomorrow)
        assertEquals("Tue, 7 Feb", s.tomorrow!!.dateLabel)
        assertEquals("₹800", s.tomorrow!!.potentialEarnLabel)
        assertNull(s.today)
    }

    @Test fun confirmedWidget_setsPresentToday_withCanChange() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_CONFIRMED","widget_data":{
              "date":"Tue, 7 Feb","change_atn":true}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(AttendanceStatus.Present, s.attendance)
        assertEquals(true, s.canChangeAttendance)
        // CONFIRMED is tomorrow's provisional-present, not a live today shift.
        assertEquals(true, s.isProvisional)
    }

    @Test fun absentWidget_alone_setsAbsentToday() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","change_atn":true,"attendance_type":"ABSENT"}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(AttendanceStatus.Absent, s.attendance)
        assertNull(s.tomorrow)
        // No `type` field → today's absent, not provisional.
        assertEquals(false, s.isProvisional)
    }

    @Test fun absentWidget_typeTomorrow_isProvisional() = runTest {
        // Dart `attendance_absent.dart:124` reads `type == "TOMORROW"` to switch
        // to tomorrow's-attendance copy; the projector must flag it provisional so
        // the change flow drops the today-only FALSE_ATTENDANCE penalty.
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Wed, 8 Feb","change_atn":true,"attendance_type":"ABSENT","type":"TOMORROW"}}
        """.trimIndent())
        runCurrent()
        assertEquals(true, assertNotNull(rm.state.value).isProvisional)
    }

    @Test fun absentWidget_attendanceTypeNoShow_setsNoShowStatus() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","attendance_type":"NO_SHOW","no_show_red_card_count":3}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(AttendanceStatus.NoShow, s.attendance)
        assertEquals(3, s.noShowRedCards)
    }

    @Test fun absentWidget_attendanceTypeFalseAttendance_setsFalseAttendanceStatus() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","attendance_type":"FALSE_ATTENDANCE"}}
        """.trimIndent())
        runCurrent()
        assertEquals(AttendanceStatus.FalseAttendance, rm.state.value!!.attendance)
    }

    @Test fun absentWidget_withFlatTomorrowFields_populatesBoth() = runTest {
        // 318-43671 — BE adds flat `tomorrow_date` + `tomorrow_shift_time` to the
        // absent envelope (mirrors PA_BEFORE_LOGOUT shape).
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_ABSENT","widget_data":{
              "date":"Tue, 7 Feb","attendance_type":"ABSENT",
              "tomorrow_date":"Wed, 8 Feb","tomorrow_shift_time":"7am-12pm"}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(AttendanceStatus.Absent, s.attendance)
        assertEquals("Wed, 8 Feb", s.tomorrow!!.dateLabel)
        // Meridiem uppercased even in the compact `7am-12pm` form (ECPO-833 #11).
        assertEquals("7AM-12PM", s.tomorrow!!.shiftWindowLabel)
    }

    @Test fun waitHotspotWidget_withLogoutWarning_setsReminderAndEndLabel() = runTest {
        // ECPO-819 — BE flips `show_logout_warning_widgets` from shift end − 30 min.
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{
              "show_logout_warning_widgets":true,"shift_end_time":"08:00 pm"}}
        """.trimIndent())
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(true, s.showLogoutReminder)
        assertEquals("08:00 PM", s.shiftEndLabel)
    }

    @Test fun waitHotspotWidget_withoutLogoutWarning_defaultsOff() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}""")
        runCurrent()
        val s = assertNotNull(rm.state.value)
        assertEquals(false, s.showLogoutReminder)
        assertNull(s.shiftEndLabel)
    }

    @Test fun requestRefresh_delegatesToStore() = runTest {
        val (store, rm) = setup(this)
        var calls = 0; store.bind { calls++ }
        rm.requestRefresh()
        assertEquals(1, calls)
    }

    @Test fun hasLoaded_falseBeforeFirstEnvelope() = runTest {
        val (_, rm) = setup(this); runCurrent()
        // Seeded StateFlow default (null store value) must NOT count as loaded.
        assertEquals(false, rm.hasLoaded.value)
    }

    @Test fun hasLoaded_trueAfterFirstEnvelope_evenWhenShiftIsNull() = runTest {
        val (store, rm) = setup(this)
        // An unknown widget maps to a null Shift, but the envelope still arrived —
        // hasLoaded latches true so the first-load shimmer clears.
        store.pushState("""{"widget_name":"RUNNER_NEW_JOB","widget_data":{}}""")
        runCurrent()
        assertNull(rm.state.value)
        assertEquals(true, rm.hasLoaded.value)
    }

    /**
     * Regression: the `.jsonPrimitive` field helpers THROW when a field arrives as an
     * object/array instead of a scalar. The collector had no try/catch, so one
     * wrong-typed field escaped it and killed the collection for the rest of the
     * session — shift state frozen, silently. `RunnerStateStore` guards the envelope;
     * this guards the fields inside it.
     */
    @Test fun wrongTypedField_keepsLastGoodState_andLogs_andKeepsCollecting() = runTest {
        val logger = FakeLogger()
        val store = RunnerStateStore(FakeLogger())
        val rm = ShiftProjector(store, backgroundScope, logger)

        // 1. A good envelope establishes real state.
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{
              "date":"Tue, 7 Feb","shift_time":"7am-12pm",
              "earning_loss_amount":800,"is_next_working_day_sunday":false}}
        """.trimIndent())
        runCurrent()
        val good = assertNotNull(rm.state.value)

        // 2. `date` arrives as an OBJECT — `.jsonPrimitive` throws inside toShift.
        store.pushState("""
            {"widget_name":"RUNNER_ATTENDANCE_TOMORROW","widget_data":{
              "date":{"unexpected":"object"},"shift_time":"7am-12pm",
              "earning_loss_amount":800,"is_next_working_day_sunday":false}}
        """.trimIndent())
        runCurrent()

        // Last good state stands, and the failure is no longer invisible.
        assertEquals(good, rm.state.value)
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })

        // 3. The collector is still alive — a subsequent good envelope still lands.
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}""")
        runCurrent()
        assertEquals(ShiftPhase.SearchingForJobs, rm.phase.value)
    }

    @Test
    fun capitalizeMeridiem_uppercases_am_pm_leaving_the_rest_untouched() {
        // ECPO-833 #11: BE ships lowercase; header wants "08:30 AM - 08:00 PM".
        assertEquals("08:30 AM - 08:00 PM", capitalizeMeridiem("08:30 am - 08:00 pm"))
        // Compact, digit-adjacent form (the `tomorrow_shift_time` shape) — the old
        // leading-`\b` pattern silently missed this; the digit anchor catches it.
        assertEquals("7AM-12PM", capitalizeMeridiem("7am-12pm"))
        // Already-uppercase and no-meridiem inputs pass through unchanged.
        assertEquals("07:00 AM - 12:00 PM", capitalizeMeridiem("07:00 AM - 12:00 PM"))
        assertEquals("10:00 - 18:00", capitalizeMeridiem("10:00 - 18:00"))
        // A standalone `am` after a digit is uppercased; plain words are not
        // (no digit anchor), so `program`/`Sample` stay untouched.
        assertEquals("9 AM Sample", capitalizeMeridiem("9 am Sample"))
        assertEquals("program", capitalizeMeridiem("program"))
    }

    @Test
    fun commaAfterWeekday_inserts_a_comma_only_after_a_leading_weekday() {
        assertEquals("Monday, 20th July", commaAfterWeekday("Monday 20th July"))
        // Already-comma'd and non-weekday labels pass through unchanged.
        assertEquals("Monday, 20th July", commaAfterWeekday("Monday, 20th July"))
        assertEquals("20th July", commaAfterWeekday("20th July"))
        assertEquals("Sunday", commaAfterWeekday("Sunday"))
    }
}
