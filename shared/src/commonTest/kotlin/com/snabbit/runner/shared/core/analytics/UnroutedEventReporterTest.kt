package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.FakeLogger
import kotlin.test.Test
import kotlin.test.assertEquals

class UnroutedEventReporterTest {

    private fun reporter(): Triple<UnroutedEventReporter, FakeLogger, RecordingCrashReporter> {
        val log = FakeLogger()
        val crash = RecordingCrashReporter()
        return Triple(UnroutedEventReporter(log, crash), log, crash)
    }

    @Test
    fun firstOccurrence_warnsAndReports() {
        val (r, log, crash) = reporter()

        r.onUnrouted("orphan_event")

        assertEquals(1, log.entries.count { it.level == FakeLogger.Level.WARN })
        assertEquals(1, crash.reports.size)
        assertEquals("orphan_event", crash.reports.first().meta["event"])
    }

    @Test
    fun repeatedSameEvent_warnsAndReportsEachTime() {
        val (r, log, crash) = reporter()

        r.onUnrouted("orphan_event")
        r.onUnrouted("orphan_event")
        r.onUnrouted("orphan_event")

        assertEquals(3, log.entries.count { it.level == FakeLogger.Level.WARN })
        assertEquals(3, crash.reports.size)
    }

    @Test
    fun distinctEvents_eachReported() {
        val (r, _, crash) = reporter()

        r.onUnrouted("orphan_a")
        r.onUnrouted("orphan_b")
        r.onUnrouted("orphan_a")

        assertEquals(3, crash.reports.size)
        assertEquals(listOf("orphan_a", "orphan_b", "orphan_a"), crash.reports.map { it.meta["event"] })
    }
}
