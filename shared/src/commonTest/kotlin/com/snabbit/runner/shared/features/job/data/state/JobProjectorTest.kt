package com.snabbit.runner.shared.features.job.data.state

import com.snabbit.runner.shared.features.job.IN_PROGRESS_JSON
import com.snabbit.runner.shared.features.job.NEW_JOB_JSON
import com.snabbit.runner.shared.features.job.POST_CHECKOUT_JSON
import com.snabbit.runner.shared.features.job.domain.model.DEFAULT_ACCEPT_TIMER_SEC
import com.snabbit.runner.shared.features.job.domain.model.JobState
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.job.envelope
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Coverage for [toJob] — routing by widget_name + tolerant new-job parsing into raw domain [JobState]. */
class JobProjectorTest {

    @Test
    fun unknownWidget_isNull() {
        assertNull(envelope("RUNNER_LOGOUT", "{}").toJob())
    }

    @Test
    fun newJob_parsesModelFields() {
        val job = envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON).toJob()
        assertIs<JobState.New>(job)
        val m = job.model
        assertEquals(739, m.jobId)
        assertTrue(m.isDeniable)
        assertFalse(m.isLastHourJob)
        assertEquals(120, m.timerDurationSec)
        assertEquals(30, m.denyRate)
        assertEquals(50, m.lossAmount)
        assertEquals("102, tower 2, Regent Hill", m.address)
        assertEquals(JobCategory.Expert, m.category)

        val payout = m.payout
        assertEquals(150, payout?.totalEarning)
        assertEquals(5, payout?.checkInAmount)
        assertEquals("2026-06-27T19:45:00+05:30", payout?.checkInTimeIso)
        assertEquals(3, payout?.lines?.size)
        assertEquals("Work (1 hour)", payout?.lines?.get(0)?.labelDefault)
        assertEquals(120, payout?.lines?.get(0)?.amount)
        assertEquals("1 hour", payout?.lines?.get(1)?.pillText)
    }

    @Test
    fun newJob_tolerates_stringNumbers() {
        val json = """
            {"job_id":"739","timer_duration":"90",
             "payout_info":{"total_earning":"150","breakdown":[{"title":{"key":"work"},"amount":"120"}]}}
        """.trimIndent()
        val job = envelope(JobWidgetName.NEW_JOB, json).toJob()
        assertIs<JobState.New>(job)
        assertEquals(739, job.model.jobId)
        assertEquals(90, job.model.timerDurationSec)
        assertEquals(150, job.model.payout?.totalEarning)
        assertEquals(120, job.model.payout?.lines?.single()?.amount)
    }

    @Test
    fun newJob_missingFields_useDefaults() {
        val job = envelope(JobWidgetName.NEW_JOB, "{}").toJob()
        assertIs<JobState.New>(job)
        assertNull(job.model.jobId)
        assertFalse(job.model.isDeniable)
        assertEquals(DEFAULT_ACCEPT_TIMER_SEC, job.model.timerDurationSec)
        assertNull(job.model.payout)
    }

    @Test
    fun newJob_nullWidgetData_useDefaults() {
        val job = RunnerState(widgetName = JobWidgetName.NEW_JOB, widgetData = null).toJob()
        assertIs<JobState.New>(job)
        assertEquals(DEFAULT_ACCEPT_TIMER_SEC, job.model.timerDurationSec)
    }

    @Test
    fun newJob_cookCategory_fromServiceType() {
        val job = envelope(JobWidgetName.NEW_JOB, """{"service_type":"COOK"}""").toJob()
        assertIs<JobState.New>(job)
        assertEquals(JobCategory.Cook, job.model.category)
    }

    @Test
    fun postAccept_and_checkIn_mapAwaitingCheckIn() {
        assertEquals(
            JobState.AwaitingCheckIn(jobId = 12),
            envelope(JobWidgetName.POST_ACCEPT, """{"job_id":12}""").toJob(),
        )
        assertEquals(
            JobState.AwaitingCheckIn(jobId = 34),
            envelope(JobWidgetName.CHECK_IN, """{"job_id":34}""").toJob(),
        )
    }

    @Test
    fun awaitingCheckIn_parsesAddressAndGeoAddress() {
        // ECPO-860 #7: the check-in nav card shows the FULL address = address + geo_address, so the
        // projector must carry geo_address through (it was previously dropped, "trimming" the address).
        val job = envelope(
            JobWidgetName.CHECK_IN,
            """{"job_id":7,"address":"102, tower 2","geo_address":"Purva Fountain Sq"}""",
        ).toJob()
        assertIs<JobState.AwaitingCheckIn>(job)
        assertEquals("102, tower 2", job.address)
        assertEquals("Purva Fountain Sq", job.geoAddress)
    }

    @Test
    fun inProgress_mapsInProgress() {
        assertEquals(
            JobState.InProgress(jobId = 99),
            envelope(JobWidgetName.IN_PROGRESS, """{"job_id":99}""").toJob(),
        )
    }

    @Test
    fun inProgress_parsesRawScreenFields() {
        val job = envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON).toJob()
        assertIs<JobState.InProgress>(job)
        assertEquals(739, job.jobId)
        assertEquals("Radhika S", job.customerName)
        assertEquals("9876543210", job.customerPhone)
        assertEquals("2026-06-27T10:00:00+05:30", job.startTimeIso)
        assertEquals("2026-06-27T11:00:00+05:30", job.endTimeIso)
        assertEquals(60, job.durationMinutes)
        assertEquals(5, job.checkoutBeforeMins)
        assertEquals(600, job.autoCheckoutSeconds)
        assertTrue(job.nextJobReady)
        assertTrue(job.showCheckoutOtp)
        assertFalse(job.cashToBeCollected)
        // Preferences sort by key (oil_level before spice_level); `title` becomes the label.
        assertEquals(listOf("oil_level", "spice_level"), job.preferences.map { it.key })
        assertEquals("Oil level", job.preferences[0].label)
        assertEquals("Medium", job.preferences[0].value)
    }

    @Test
    fun postCheckout_mapsCompleted() {
        assertEquals(
            JobState.Completed(jobId = 7),
            envelope(JobWidgetName.POST_CHECKOUT, """{"job_id":7}""").toJob(),
        )
    }

    @Test
    fun postCheckout_parsesCustomerAndPayout() {
        val job = envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON).toJob()
        assertIs<JobState.Completed>(job)
        assertEquals(739, job.jobId)
        assertEquals(42, job.customerId)
        assertEquals("Radhika S", job.customerName)
        assertEquals("HAL Old Airport Rd, Marathahalli, Bengaluru", job.customerAddress)
        assertEquals(150, job.payout?.totalEarning)
        assertEquals(5, job.payout?.checkInAmount)
    }
}
