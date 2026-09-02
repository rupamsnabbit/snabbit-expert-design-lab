package com.snabbit.runner.shared.features.kavach.sos.domain

import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.features.kavach.sos.data.remote.ActiveSosState
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosLiveStore
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SosCoordinatorTest {

    private val shield = FakeShieldController()
    private val sosApi = FakeSosApi()
    private val rc = FakeRemoteConfigGateway()
    private val lifecycle = FakeAppLifecycle(initial = true)   // foregrounded by default
    private val currentState = FakeCurrentStateGateway()
    private val analytics = FakeAnalyticsTracker()

    private val sosLiveStore = SosLiveStore(InMemoryEncryptedStore())

    private fun coordinator(dispatcher: CoroutineDispatcher = UnconfinedTestDispatcher()) =
        SosCoordinator(
            shield, sosApi, rc, lifecycle, currentState, analytics, testAppDispatchers(dispatcher),
            sosLiveStore = sosLiveStore,
        )

    // ── S1: adopt backend `pending` only on a genuine transition into ACTIVE ──

    @Test
    fun reconcilePending_repeated_firesSyncConfirmedOnce() = runTest {
        val c = coordinator()
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "pending", sosId = 5, phoneNumber = "9")
        c.reconcile()
        c.reconcile()   // a second foreground pass while the SOS is still ACTIVE
        c.reconcile()
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        // Unguarded this fired on every reconcile, inflating the event and hiding real confirms.
        assertEquals(1, analytics.tracked.count { it.name == "expert_shield_sos_sync_confirmed" })
    }

    // ── S2: a resolve the backend never received must not clear the recovery marker ──

    @Test
    fun deny_notDelivered_retainsLiveMarker() = runTest {
        val c = coordinator()
        c.raiseManual(jobId = 7)
        sosApi.resolveDelivered = false        // network blip — backend still holds the SOS open
        c.deny()
        assertEquals(SosPhase.IDLE, c.state.value.phase)   // UI not stranded
        assertTrue(sosLiveStore.isLive())                  // but recovery is still possible
        assertTrue(analytics.names().contains("expert_shield_sos_deny_api_failed"))
    }

    @Test
    fun deny_delivered_clearsLiveMarker() = runTest {
        val c = coordinator()
        c.raiseManual(jobId = 7)
        c.deny()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertEquals(false, sosLiveStore.isLive())
        assertTrue(analytics.names().contains("expert_shield_sos_denied"))
    }

    @Test
    fun confirm_notDelivered_advancesToActive_butFlagsApiFailed() = runTest {
        // A confirm the backend never got must still show the active screen (a runner who said "I'm in
        // danger" isn't stranded), but be flagged as api_failed rather than a clean confirm.
        val c = coordinator()
        c.raiseManual(jobId = 7)               // ALERT
        sosApi.resolveDelivered = false
        c.confirm()
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertTrue(analytics.names().contains("expert_shield_sos_confirm_api_failed"))
    }

    @Test
    fun reconcileDenied_resetsToIdle_andClearsMarker() = runTest {
        val c = coordinator()
        sosLiveStore.markLive()
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "denied", sosId = 9, phoneNumber = null)
        c.reconcile()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertEquals(false, sosLiveStore.isLive())
        assertTrue(analytics.names().contains("expert_shield_sos_sync_denied"))
    }

    @Test
    fun callSosTeam_noActivePhone_fallsBackToRcNumber() = runTest {
        // No active SOS phone → dial the RC fallback (E4), not a blank number.
        val c = coordinator()
        rc.strings["expert_shield_sos_fallback_phone"] = "18001234"
        c.callSosTeam()
        assertEquals("18001234", sosApi.lastCallPhone)
    }

    @Test
    fun raiseManual_triggersPlugin_andShowsAlert() = runTest {
        val c = coordinator()
        c.raiseManual(jobId = 7)
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        assertTrue(shield.calls.contains("triggerManualSoS"))
        assertEquals(1, sosApi.initiateCalls)
    }

    @Test
    fun raise_backendInitiateFails_stillShowsAlert_andFlagsFailedRegistration() = runTest {
        val c = coordinator()
        sosApi.initiateResult = null   // backend initiate failed (best-effort seam returns null)
        c.raiseManual(jobId = 7)
        // Best-effort: the emergency sheet still shows through a network blip (#222861) …
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        assertEquals(null, c.state.value.sosId)
        // … but a failed registration is flagged distinctly, not a misleading 'initiated' with null id.
        assertTrue(analytics.last("expert_shield_sos_initiated") == null)
        assertTrue(analytics.last("expert_shield_sos_initiate_failed") != null)
    }

    @Test
    fun raiseDetected_doesNotReTriggerThePlugin() = runTest {
        val c = coordinator()
        c.raiseDetected(source = "ml", triggerType = "ml")
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        assertEquals(false, shield.calls.contains("triggerManualSoS"))
        assertEquals(1, sosApi.initiateCalls)
    }

    @Test
    fun raise_isReentrancyGuarded() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.raiseManual()
        assertEquals(1, sosApi.initiateCalls)
    }

    @Test
    fun confirm_goesActive() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.confirm()
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertTrue(shield.calls.contains("confirmSoS"))
    }

    // ── NotificationAction (plugin already ran the handler → sync state, no re-invoke) ──

    @Test
    fun notificationConfirm_syncsActive_withoutReinvokingPlugin() = runTest {
        val c = coordinator()
        c.raiseManual()   // ALERT; shield.calls already has triggerManualSoS
        c.handleNotificationAction("confirm")
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertEquals(false, shield.calls.contains("confirmSoS"))  // plugin already confirmed
        assertEquals(1, sosApi.resolveCalls)                      // backend still notified
    }

    @Test
    fun notificationConfirm_afterKill_reconcilesThenResolves() = runTest {
        val c = coordinator()
        // Killed revival: the coordinator cold-starts fresh IDLE, but the backend has a live SOS.
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "initiated", sosId = 42, phoneNumber = "999")
        c.handleNotificationAction("confirm")
        // phase==IDLE + a resume action → reconcile() rehydrates to ALERT, then confirm → ACTIVE + backend resolve (§4).
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertEquals(42, c.state.value.sosId)
        assertTrue(sosApi.resolveCalls >= 1)
    }

    @Test
    fun notificationDeny_syncsIdle_withoutReinvokingPlugin() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.handleNotificationAction("deny")
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertEquals(false, shield.calls.contains("denySoS"))
    }

    @Test
    fun notificationEndSos_fromActive_syncsIdle_withoutReinvokingPlugin() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.confirm()   // ACTIVE
        c.handleNotificationAction("end_sos")
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertEquals(false, shield.calls.contains("deescalateSoS"))
    }

    @Test
    fun notificationSosButton_raisesTheAlert() = runTest {
        val c = coordinator()
        c.handleNotificationAction("sosButton")
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        assertEquals(false, shield.calls.contains("triggerManualSoS"))
        assertEquals(1, sosApi.initiateCalls)
    }

    @Test
    fun notificationEscalate_dials() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.confirm()
        c.handleNotificationAction("escalate")
        assertEquals(1, sosApi.callSosTeamCalls)
    }

    // ── /sos/active reconcile (E3) ──

    @Test
    fun reconcile_initiated_showsAlert() = runTest {
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "initiated", sosId = 5, phoneNumber = "111")
        val c = coordinator()
        c.reconcile()
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        assertEquals(5, c.state.value.sosId)
    }

    @Test
    fun reconcile_pending_goesActive() = runTest {
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "pending", sosId = 5, phoneNumber = "222")
        val c = coordinator()
        c.reconcile()
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertEquals("222", c.state.value.phoneNumber)
    }

    @Test
    fun reconcile_noActiveSos_resetsFromActive() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.confirm()   // ACTIVE
        sosApi.activeResult = ActiveSosState(hasActiveSos = false, status = null, sosId = null, phoneNumber = null)
        c.reconcile()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
    }

    @Test
    fun reconcile_nullResult_leavesStateUnchanged() = runTest {
        val c = coordinator()
        c.raiseManual()               // ALERT
        sosApi.activeResult = null    // E3 failed / no data
        c.reconcile()
        assertEquals(SosPhase.ALERT, c.state.value.phase)
    }

    @Test
    fun deny_resetsToIdle() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.deny()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertTrue(shield.calls.contains("denySoS"))
    }

    @Test
    fun deescalate_fromActive_resetsToIdle() = runTest {
        val c = coordinator()
        c.raiseManual()
        c.confirm()
        c.deescalate()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertTrue(shield.calls.contains("deescalateSoS"))
    }

    @Test
    fun callSosTeam_dialsWithTheActiveSosPhone() = runTest {
        sosApi.resolveResult = "888"
        val c = coordinator()
        c.raiseManual()
        c.confirm()   // phone = 888 (from resolve)
        c.callSosTeam()
        assertEquals("888", sosApi.lastCallPhone)
    }

    @Test
    fun autoDenyTimer_deniesAfterTheAlertTimeout() = runTest {
        val c = coordinator(StandardTestDispatcher(testScheduler))
        c.raiseManual()
        assertEquals(SosPhase.ALERT, c.state.value.phase)
        advanceTimeBy(21_000)
        runCurrent()
        assertEquals(SosPhase.IDLE, c.state.value.phase)
        assertTrue(shield.calls.contains("denySoS"))
    }

    @Test
    fun autoDenyTimer_skippedWhenBackgrounded_leavesAlertForResumePrompt() = runTest {
        lifecycle.foregroundFlow.value = false   // app backgrounded during the alert
        val c = coordinator(StandardTestDispatcher(testScheduler))
        c.raiseManual()
        advanceTimeBy(21_000)
        runCurrent()
        assertEquals(SosPhase.ALERT, c.state.value.phase)         // NOT silently denied
        assertTrue(!shield.calls.contains("denySoS"))
    }

    @Test
    fun raiseManual_attachesActiveJobIdFromCurrentState() = runTest {
        currentState.jobId = 650
        val c = coordinator()
        c.raiseManual()                                            // no explicit jobId
        assertEquals(650, sosApi.lastInitiateJobId)                // sourced from the gateway
    }

    @Test
    fun analytics_fireAcrossTheSosLifecycle() = runTest {
        val c = coordinator()
        c.raiseManual()   // → initiated
        c.confirm()       // → confirmed
        c.deescalate()    // → deescalated
        val names = analytics.names()
        assertTrue(names.contains("expert_shield_sos_initiated"))
        assertTrue(names.contains("expert_shield_sos_confirmed"))
        assertTrue(names.contains("expert_shield_sos_deescalated"))
        assertEquals(1, analytics.last("expert_shield_sos_confirmed")?.props?.get("sos_id"))
        assertEquals("manual", analytics.last("expert_shield_sos_initiated")?.props?.get("source"))
    }

    @Test
    fun applyPush_confirm_fromAlert_goesActive_withoutReinvokingPlugin() = runTest {
        val c = coordinator()
        c.raiseManual()                       // ALERT, sosId=1 (FakeSosApi.initiateResult)
        c.applyPush("confirm", 1)
        assertEquals(SosPhase.ACTIVE, c.state.value.phase)
        assertEquals(false, shield.calls.contains("confirmSoS"))   // plugin already acted
        assertTrue(analytics.names().contains("expert_shield_sos_push_drained"))
    }

    @Test
    fun applyPush_staleSosId_ignored() = runTest {
        val c = coordinator()
        c.raiseManual()                       // sosId=1
        c.applyPush("confirm", 999)           // different sos → stale
        assertEquals(SosPhase.ALERT, c.state.value.phase)
    }
}
