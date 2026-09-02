package com.snabbit.runner.shared.features.autoot.data

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.autoot.FakeAutoOtRepository
import com.snabbit.runner.shared.features.autoot.domain.AutoOtTrigger
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.model.OtType
import com.snabbit.runner.shared.features.autoot.domain.model.ShiftDetails
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

@OptIn(ExperimentalCoroutinesApi::class)
class AutoOtCoordinatorTest {

    private fun setup(
        scope: TestScope,
        appConfig: AppConfigStore = AppConfigStore(FakeLogger()),
        remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, _ -> true }, // feature ON by default
    ): Triple<RunnerStateStore, FakeAutoOtRepository, AutoOtCoordinator> {
        val store = RunnerStateStore(FakeLogger())
        val repo = FakeAutoOtRepository()
        return Triple(store, repo, AutoOtCoordinator(store, repo, appConfig, remoteConfig, scope.backgroundScope))
    }

    /** An `auto_ot` object nested in a (by default non-blocked) widget envelope. */
    private fun offerEnvelope(requestId: Int, otType: String = "END_OT", widgetName: String = "RUNNER_WAIT_HOTSPOT") = """
        {"widget_name":"$widgetName","widget_data":{"auto_ot":{
          "request_id":$requestId,"ot_type":"$otType",
          "regular_shift":{"start_time":"2026-02-07T08:00:00+05:30","end_time":"2026-02-07T17:00:00+05:30","ming":600.0},
          "ot_shift":{"start_time":"2026-02-07T08:00:00+05:30","end_time":"2026-02-07T19:00:00+05:30","ming":750.0,"duration":2.0},
          "expiry_duration":5}}}
    """.trimIndent()

    @Test fun nullEnvelope_isNone() = runTest {
        val (_, _, c) = setup(this); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun endOtAutoOt_emitsOffer() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        val offer = assertIs<AutoOtTrigger.Offer>(c.trigger.value)
        assertEquals(1, offer.details.requestId)
        assertEquals(OtType.EndOt, offer.details.otType)
    }

    @Test fun sameRequestId_dedupes_newRequestId_reEmits() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        assertEquals(1, assertIs<AutoOtTrigger.Offer>(c.trigger.value).details.requestId)

        store.pushState(offerEnvelope(requestId = 2)); runCurrent()
        assertEquals(2, assertIs<AutoOtTrigger.Offer>(c.trigger.value).details.requestId)
    }

    @Test fun blockedWidget_whileOfferActive_preempts() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        store.pushState("""{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{}}"""); runCurrent()
        assertEquals(AutoOtTrigger.Preempt, c.trigger.value)
    }

    @Test fun autoOtRemoved_afterEndOt_clearsToNone() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}"""); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun autoOtWithoutShifts_doesNotEmitOffer() = runTest {
        val (store, _, c) = setup(this)
        // request id present but no regular_shift / ot_shift → Flutter guard: don't show.
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{"auto_ot":{"request_id":1,"ot_type":"END_OT"}}}""")
        runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun emptyAutoOtObject_staysNone() = runTest {
        val (store, _, c) = setup(this)
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{"auto_ot":{}}}"""); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun malformedAutoOt_doesNotCrash_staysNone() = runTest {
        val (store, _, c) = setup(this)
        // auto_ot present but not an object (a string) → ignored, no crash.
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{"auto_ot":"oops"}}"""); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun startOt_viaAttendance_emitsOffer_andSurvivesEnvelopeWithoutAutoOt() = runTest {
        val (store, repo, c) = setup(this)
        repo.startOtResult = Result.Ok(
            AutoOtDetails(
                requestId = 99,
                otType = OtType.StartOt,
                regularShift = ShiftDetails("2026-02-07T08:00:00+05:30", "2026-02-07T17:00:00+05:30", 600.0, null),
                otShift = ShiftDetails("2026-02-07T08:00:00+05:30", "2026-02-07T19:00:00+05:30", 750.0, 2),
                expiryDurationMinutes = 10,
                status = null,
            ),
        )

        c.onAttendanceMarked(); runCurrent()
        assertEquals(99, assertIs<AutoOtTrigger.Offer>(c.trigger.value).details.requestId)

        // A subsequent current-state envelope WITHOUT auto_ot must NOT clear a START_OT offer.
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}"""); runCurrent()
        assertEquals(99, assertIs<AutoOtTrigger.Offer>(c.trigger.value).details.requestId)
    }

    @Test fun onCancelled_whenOfferActive_emitsCancelled() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        c.onCancelled(); runCurrent() // onCancelled now hops onto the coordinator scope
        assertEquals(AutoOtTrigger.Cancelled, c.trigger.value)
    }

    @Test fun onCancelled_whenNoActiveOffer_isNoOp() = runTest {
        val (_, _, c) = setup(this); runCurrent()
        c.onCancelled(); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    @Test fun onPostAction_armsStorePostActionWithLabel() = runTest {
        val (store, _, c) = setup(this)
        var received: String? = null; store.bindPostAction { received = it }
        c.onPostAction("auto_ot_accept")
        assertEquals("auto_ot_accept", received)
    }

    // A consumed offer must not replay: onOfferConsumed resets the trigger to None, but the request
    // id is kept so the stream's dedupe still suppresses the same offer (fixes the stale-START_OT
    // re-show on VM recreation).
    @Test fun onOfferConsumed_resetsTriggerToNone_butKeepsDedupe() = runTest {
        val (store, _, c) = setup(this)
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        assertIs<AutoOtTrigger.Offer>(c.trigger.value)

        c.onOfferConsumed()
        assertEquals(AutoOtTrigger.None, c.trigger.value)

        // Re-pushing the same offer must NOT re-surface it.
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    // The live block-list comes from app_config; a widget absent from it does NOT suppress the
    // offer even if it's in the baked fallback (prod dropped POST_ACCEPT / IN_PROGRESS).
    @Test fun blockedWidgets_useAppConfig_overBakedDefault() = runTest {
        val appConfig = AppConfigStore(FakeLogger())
        appConfig.pushConfig("""{"blocked_auto_ot_widgets":["RUNNER_JOB_CHECK_IN","RUNNER_NEW_JOB","RUNNER_SUSPENDED"]}""")
        val (store, _, c) = setup(this, appConfig)
        // POST_ACCEPT is in BLOCKED_WIDGETS but not in the app_config list → offer still surfaces.
        store.pushState(offerEnvelope(requestId = 1, widgetName = "RUNNER_JOB_POST_ACCEPT")); runCurrent()
        assertIs<AutoOtTrigger.Offer>(c.trigger.value)
    }

    // With no app_config pushed, fall back to the baked default (POST_ACCEPT suppresses).
    @Test fun blockedWidgets_fallBackToBakedDefault_whenNoAppConfig() = runTest {
        val (store, _, c) = setup(this) // empty AppConfigStore
        store.pushState(offerEnvelope(requestId = 1, widgetName = "RUNNER_JOB_POST_ACCEPT")); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    // Kill-switch: expert_enable_auto_ot = false → no offer surfaces from the stream.
    @Test fun featureDisabled_suppressesOffers() = runTest {
        val (store, _, c) = setup(this, remoteConfig = RemoteConfigGateway { _, _ -> false })
        store.pushState(offerEnvelope(requestId = 1)); runCurrent()
        assertEquals(AutoOtTrigger.None, c.trigger.value)
    }

    // Kill-switch: disabled → the START_OT probe is skipped entirely.
    @Test fun featureDisabled_onAttendanceMarked_skipsStartOtProbe() = runTest {
        val (_, repo, c) = setup(this, remoteConfig = RemoteConfigGateway { _, _ -> false })
        c.onAttendanceMarked(); runCurrent()
        assertEquals(0, repo.startOtCalls)
    }
}
