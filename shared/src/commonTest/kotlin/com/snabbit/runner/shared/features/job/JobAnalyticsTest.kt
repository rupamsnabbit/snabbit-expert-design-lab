package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.blocklist.data.remote.FakeBlockListRepository
import com.snabbit.runner.shared.features.job.data.NoLocationProvider
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.job.presentation.JobUiIntent
import com.snabbit.runner.shared.features.job.presentation.JobViewModel
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInUiIntent
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInViewModel
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiIntent
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingViewModel
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutUiIntent
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutViewModel
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Unit tests for [JobAnalytics] (event names + attribute shapes) and the ViewModel wiring that emits
 * through it. The wrapper is tested directly with the recording [FakeAnalyticsTracker]; the VMs are
 * constructed with a fake-backed [JobAnalytics] to assert the right event fires per intent.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class JobAnalyticsTest {

    // JobViewModel runs its UI stream (incl. the stage-load collector) on viewModelScope → needs Main.
    @BeforeTest
    fun setUpMain() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @AfterTest
    fun tearDownMain() = Dispatchers.resetMain()

    // ── JobAnalytics wrapper ────────────────────────────────────────────────────

    @Test
    fun acceptanceScreenLoad_emitsNameAndAttributes() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).acceptanceScreenLoad(
            displayMode = "full_screen",
            jobType = "standard",
            denyAvailable = true,
            earnTotal = 150,
            earningsLineItems = listOf("work", "ot"),
            checkInByTime = "7:45 PM",
            acceptCountdownSeconds = 90,
            penaltyNudgeVisible = false,
        )
        val e = fake.events.single()
        assertEquals("job_acceptance_screen_load", e.name)
        assertEquals("full_screen", e.props["display_mode"])
        assertEquals("standard", e.props["job_type"])
        assertEquals(true, e.props["deny_available"])
        assertEquals(150, e.props["earn_total"])
        assertEquals("work,ot", e.props["earnings_line_items"]) // list → comma-joined string
        assertEquals(90, e.props["accept_countdown"])
    }

    @Test
    fun acceptanceCtaClick_carriesCtaAndJobType() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).acceptanceScreenCtaClick(ctaText = "accept_job", jobType = "long_distance")
        val e = fake.events.single()
        assertEquals("job_acceptance_screen_cta_click", e.name)
        assertEquals("accept_job", e.props["cta_text"])
        assertEquals("long_distance", e.props["job_type"])
    }

    @Test
    fun checkInOtpCtaClick_carriesVerificationStatus() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).checkInOtpCtaClick("start_job", "success")
        val e = fake.events.single()
        assertEquals("check_in_otp_bs_cta_click", e.name)
        assertEquals("start_job", e.props["cta_text"])
        assertEquals("success", e.props["otp_verification_status"])
    }

    @Test
    fun tasksDoneCtaClick_joinsSelectionAndCounts() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).tasksDoneCtaClick("submit", listOf("mopping", "dishwashing", "fridge"))
        val e = fake.events.single()
        assertEquals("tasks_done_bs_cta_click", e.name)
        assertEquals("submit", e.props["cta_text"])
        assertEquals("mopping,dishwashing,fridge", e.props["tasks_selected"])
        assertEquals(3, e.props["tasks_selected_count"])
    }

    @Test
    fun emptyList_dropsToNull_soSanitizerOmitsTheKey() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).tasksDoneLoad(emptyList())
        val e = fake.events.single()
        assertEquals("tasks_done_bs_load", e.name)
        assertNull(e.props["tasks_shown"])
    }

    @Test
    fun completedCtaClick_rateCustomer_carriesRating() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).completedScreenCtaClick(ctaText = "rate_customer", rating = "bad")
        val e = fake.events.single()
        assertEquals("job_completed_screen_cta_click", e.name)
        assertEquals("rate_customer", e.props["cta_text"])
        assertEquals("bad", e.props["rating"])
        assertNull(e.props["return_type"])
    }

    @Test
    fun topPanelCtaClick_carriesScreenName() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).topPanelCtaClick("sos", JobAnalytics.SCREEN_CHECK_IN)
        val e = fake.events.single()
        assertEquals("top_panel_cta_click", e.name)
        assertEquals("sos", e.props["cta_text"])
        assertEquals("check_in", e.props["screen_name"])
    }

    @Test
    fun errorScreenLoad_carriesContextAndFlags() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).errorScreenLoad(
            errorType = "job_action_failed",
            errorFormat = "toast",
            errorContext = "job_acceptance",
            isNetworkError = false,
            retryAvailable = false,
            contactSupportAvailable = false,
        )
        val e = fake.events.single()
        assertEquals("error_screen_load", e.name)
        assertEquals("job_action_failed", e.props["error_type"])
        assertEquals("toast", e.props["error_format"])
        assertEquals("job_acceptance", e.props["error_context"])
        assertEquals(false, e.props["is_network_error"])
    }

    @Test
    fun wrapperHoldsNoDedup_repeatLoadsBothFire() {
        // De-dup lives per-host in JobViewModel, not this shared single, so two identical calls both fire.
        val fake = FakeAnalyticsTracker()
        val analytics = JobAnalytics(fake)
        analytics.completedScreenLoad(earnTotal = 150, earningsLineItems = listOf("work"))
        analytics.completedScreenLoad(earnTotal = 150, earningsLineItems = listOf("work"))
        assertEquals(listOf("job_completed_screen_load", "job_completed_screen_load"), fake.trackedNames)
    }

    // ── ViewModel wiring ─────────────────────────────────────────────────────────

    @Test
    fun checkIn_open_emitsScreenCtaThenOtpLoad() = runTest {
        val fake = FakeAnalyticsTracker()
        checkInVm(fake, """{"job_id":739}""").onIntent(CheckInUiIntent.Open)
        assertEquals(listOf("check_in_screen_cta_click", "check_in_otp_bs_load"), fake.trackedNames)
    }

    @Test
    fun checkIn_startJobSuccess_emitsOtpCtaSuccessThenJobStartedLoad() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = checkInVm(fake, """{"job_id":739}""")
        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()
        val cta = fake.events.last { it.name == "check_in_otp_bs_cta_click" }
        assertEquals("start_job", cta.props["cta_text"])
        assertEquals("success", cta.props["otp_verification_status"])
        assertTrue("job_started_bs_load" in fake.trackedNames)
    }

    @Test
    fun checkout_openNoCampaign_emitsCompleteJobCtaThenOtpLoad() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = CheckoutViewModel(
            actions = FakeJobActionRepository(),
            source = FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON)),
            scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )
        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))
        assertEquals(listOf("job_in_progress_screen_cta_click", "checkout_otp_bs_load"), fake.trackedNames)
    }

    @Test
    fun rating_select_emitsRateCustomerCtaWithRatingLabel() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = CustomerRatingViewModel(
            jobId = 55,
            actions = FakeJobActionRepository(),
            location = NoLocationProvider,
            source = FakeRunnerStateSource(),
            appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )
        vm.onIntent(CustomerRatingUiIntent.SelectRating(1))
        val e = fake.events.single()
        assertEquals("job_completed_screen_cta_click", e.name)
        assertEquals("rate_customer", e.props["cta_text"])
        assertEquals("bad", e.props["rating"])
    }

    @Test
    fun jobViewModel_acceptanceLoad_firesOncePerStageEntry() = runTest {
        val fake = FakeAnalyticsTracker()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON))
        jobVm(fake, source)
        advanceUntilIdle()
        // A repeated identical NEW_JOB envelope must NOT re-fire the load (per-VM stage de-dup).
        source.emit(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON))
        advanceUntilIdle()
        assertEquals(1, fake.trackedNames.count { it == "job_acceptance_screen_load" })
    }

    @Test
    fun jobViewModel_tapSos_emitsTopPanelCtaWithScreenName() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = jobVm(fake, FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON)))
        advanceUntilIdle()
        vm.onIntent(JobUiIntent.TapSos)
        val e = fake.events.last { it.name == "top_panel_cta_click" }
        assertEquals("sos", e.props["cta_text"])
        assertEquals("job_acceptance", e.props["screen_name"])
    }

    @Test
    fun jobViewModel_openBlockFlow_emitsCompletedCtaAndBlockConfirmationLoad() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = jobVm(fake, FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        advanceUntilIdle()
        vm.onIntent(JobUiIntent.OpenBlockFlow)
        val cta = fake.events.first { it.name == "job_completed_screen_cta_click" }
        assertEquals("block_customer", cta.props["cta_text"])
        assertTrue("block_confirmation_bs_load" in fake.trackedNames)
    }

    // ── Round 2: derived / composable-driven events ──────────────────────────────

    @Test
    fun jobNotAccepted_deDupsPerOfferAcrossHosts_butRefiresOnReoffer() {
        // JobAnalytics is a shared single across the two new-job hosts, so both may report the same
        // expiry — only the first fires. A genuine re-offer (new notification) fires again.
        val fake = FakeAnalyticsTracker()
        val analytics = JobAnalytics(fake)
        analytics.jobNotAccepted(offerKey = "739:offer-1", penaltyAmount = 50)
        analytics.jobNotAccepted(offerKey = "739:offer-1", penaltyAmount = 50) // same offer → suppressed
        val e = fake.events.single()
        assertEquals("job_not_accepted", e.name)
        assertEquals(50, e.props["penalty_amount"])

        analytics.jobNotAccepted(offerKey = "739:offer-2", penaltyAmount = 50) // re-offer → fires again
        assertEquals(2, fake.events.count { it.name == "job_not_accepted" })
    }

    @Test
    fun autoCheckout_carriesAfterMinutes() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).autoCheckout(autoCheckoutAfterMinutes = 10)
        val e = fake.events.single()
        assertEquals("auto_checkout", e.name)
        assertEquals(10, e.props["auto_checkout_after_minutes"])
    }

    @Test
    fun audioPlayed_carriesScreenAndPlayCount() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).audioPlayed(screenName = JobAnalytics.SCREEN_CHECK_IN, playCountOnScreen = 2)
        val e = fake.events.single()
        assertEquals("audio_played", e.name)
        assertEquals("check_in", e.props["screen_name"])
        assertEquals(2, e.props["play_count_on_screen"])
    }

    @Test
    fun jobBackPressed_carriesScreenName() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).jobBackPressed(screenName = JobAnalytics.SCREEN_IN_PROGRESS)
        val e = fake.events.single()
        assertEquals("job_back_pressed", e.name)
        assertEquals("job_in_progress", e.props["screen_name"])
    }

    @Test
    fun errorScreenCtaClick_carriesRetryAttempt() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).errorScreenCtaClick(ctaText = "try_again", errorType = "check_in_failed", retryAttempt = 2)
        val e = fake.events.single()
        assertEquals("error_screen_cta_click", e.name)
        assertEquals("try_again", e.props["cta_text"])
        assertEquals(2, e.props["retry_attempt"])
    }

    @Test
    fun setBlockedCustomers_writesUserProperty() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).setBlockedCustomers(3)
        assertTrue(fake.events.isEmpty()) // a profile write, not a tracked event
        assertEquals(3, fake.userProperties["blocked_customers"])
    }

    @Test
    fun jobViewModel_backPressed_emitsJobBackPressed() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = jobVm(fake, FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON)))
        advanceUntilIdle()
        vm.onIntent(JobUiIntent.BackPressed)
        val e = fake.events.last { it.name == "job_back_pressed" }
        assertEquals("job_in_progress", e.props["screen_name"])
    }

    @Test
    fun jobViewModel_autoCheckout_firesOnInProgressToCompletedWithoutManualCheckout() = runTest {
        val fake = FakeAnalyticsTracker()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON))
        jobVm(fake, source)
        advanceUntilIdle()
        source.emit(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON))
        advanceUntilIdle()
        val e = fake.events.last { it.name == "auto_checkout" }
        assertEquals(10, e.props["auto_checkout_after_minutes"]) // 600s / 60
    }

    @Test
    fun jobViewModel_autoCheckout_suppressedByManualCheckout() = runTest {
        val fake = FakeAnalyticsTracker()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON))
        val vm = jobVm(fake, source)
        advanceUntilIdle()
        // Runner manually checks out (End Job) → the transition to Completed must NOT read as auto-checkout.
        val checkout = vm.createCheckoutViewModel()
        checkout.onIntent(CheckoutUiIntent.EndJob("123"))
        advanceUntilIdle()
        source.emit(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON))
        advanceUntilIdle()
        assertFalse("auto_checkout" in fake.trackedNames)
    }

    @Test
    fun jobViewModel_customerBlocked_pushesBlockedCustomersCount() = runTest {
        // After a block, the profile's blocked_customers is set to the current count from the block list.
        val fake = FakeAnalyticsTracker()
        val vm = jobVm(fake, FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        advanceUntilIdle()
        vm.onIntent(JobUiIntent.CustomerBlocked)
        advanceUntilIdle()
        assertEquals(3, fake.userProperties["blocked_customers"]) // FakeBlockListRepository.sampleBlockedCustomers
    }

    private fun TestScope.checkInVm(fake: FakeAnalyticsTracker, widgetJson: String): CheckInViewModel =
        CheckInViewModel(
            actions = FakeJobActionRepository(),
            source = FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, widgetJson)),
            scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )

    // ── Old-flow parity — outcomes / dismiss / unblock ──────────────────────────────

    @Test
    fun acceptJobButtonClicked_carriesLegacyAction() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).acceptJobButtonClicked()
        val e = fake.events.single()
        assertEquals("accept_job_button_clicked", e.name)
        assertEquals("accept job button click", e.props["action"])
    }

    @Test
    fun ratingCustomerUnblockCta_carriesUnblockedCustomerId() {
        val fake = FakeAnalyticsTracker()
        JobAnalytics(fake).ratingCustomerUnblockCta(unblockedCustomerId = 42)
        val e = fake.events.single()
        assertEquals("rating_customer_unblock_cta", e.name)
        assertEquals(42, e.props["unblocked_customer_id"])
    }

    @Test
    fun jobViewModel_acceptAndDeny_emitLegacyOutcomeEvents() = runTest {
        val accepted = FakeAnalyticsTracker()
        val acceptVm = jobVm(accepted, FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON)))
        advanceUntilIdle()
        acceptVm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()
        assertTrue("accept_job_button_clicked" in accepted.trackedNames)

        val denied = FakeAnalyticsTracker()
        val denyVm = jobVm(denied, FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON)))
        advanceUntilIdle()
        denyVm.onIntent(JobUiIntent.Deny)
        advanceUntilIdle()
        assertTrue("deny_job_button_clicked" in denied.trackedNames)
    }

    @Test
    fun jobViewModel_unblock_emitsRatingCustomerUnblockCta() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = jobVm(fake, FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        advanceUntilIdle()
        vm.onIntent(JobUiIntent.UnblockCustomer)
        advanceUntilIdle()
        val e = fake.events.last { it.name == "rating_customer_unblock_cta" }
        assertEquals(42, e.props["unblocked_customer_id"])
    }

    @Test
    fun rating_submitSuccess_emitsRunnerRatedTheCustomer() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = CustomerRatingViewModel(
            jobId = 55,
            actions = FakeJobActionRepository(),
            location = NoLocationProvider,
            source = FakeRunnerStateSource(),
            appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )
        vm.onIntent(CustomerRatingUiIntent.SelectRating(3))
        vm.onIntent(CustomerRatingUiIntent.Submit)
        advanceUntilIdle()
        assertTrue("runner_rated_the_customer" in fake.trackedNames)
    }

    @Test
    fun checkIn_dismiss_emitsCheckInOtpModalDismissed() = runTest {
        val fake = FakeAnalyticsTracker()
        val vm = CheckInViewModel(
            actions = FakeJobActionRepository(),
            source = FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}""")),
            scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )
        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.Dismiss)
        assertTrue("check_in_otp_modal_dismissed" in fake.trackedNames)
    }

    private fun TestScope.jobVm(fake: FakeAnalyticsTracker, source: FakeRunnerStateSource): JobViewModel =
        JobViewModel(
            source = source,
            actions = FakeJobActionRepository(),
            location = FakeLocationProvider(),
            clock = FakeJobClock(),
            blockListDataSource = FakeBlockListRepository(),
            preferenceStorage = InMemoryPreferenceStorage(),
            appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(fake),
        )
}
