package com.snabbit.runner.shared.features.kavach.shared.domain
import com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldLayerRestore
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase

import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeModelAssetResolver
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import com.snabbit.runner.shared.features.kavach.FakeShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.snabbit.runner.shared.features.kavach.sos.data.remote.ActiveSosState
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosLiveStore
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosPushStore
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class SafetyForegroundReconcilerTest {

    private val shield = FakeShieldController()
    private val sosApi = FakeSosApi()
    private val rc = FakeRemoteConfigGateway()
    private val pushStore = SosPushStore(InMemoryEncryptedStore())
    private val sosLiveStore = SosLiveStore(InMemoryEncryptedStore())

    private fun TestScope.build(lifecycle: FakeAppLifecycle): SosCoordinator {
        val dispatchers = testAppDispatchers(UnconfinedTestDispatcher(testScheduler))
        val currentState = FakeCurrentStateGateway()   // no active job → layer restore no-ops
        // Same SosLiveStore instance as the reconciler — the coordinator writes/clears the marker,
        // the reconciler reads it. Prod shares one Koin single; the test must mirror that.
        val coordinator = SosCoordinator(
            shield, sosApi, rc, lifecycle, currentState, FakeAnalyticsTracker(), dispatchers,
            sosLiveStore = sosLiveStore,
        )
        val manualStore = ShieldManualMonitoringStore(InMemoryEncryptedStore())
        val restore = ShieldLayerRestore(shield, currentState, FakeShieldProfileGateway(), manualStore, rc, FakeModelAssetResolver(), ShieldRcGates(rc), FakeAnalyticsTracker(), ShieldInitLock(), ShieldMlLoadGuard(InMemoryPreferenceStorage()) { "test" }, jobIdCache = JobIdCache())
        SafetyForegroundReconciler(lifecycle, coordinator, pushStore, sosLiveStore, restore, CrashReporter { _, _ -> }, dispatchers)
        return coordinator
    }

    @Test
    fun foreground_triggersReconcile_drivingPhaseFromBackend() = runTest {
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "pending", sosId = 5, phoneNumber = "9")
        sosLiveStore.markLive()   // a raise happened before the kill — the reason to reconcile
        val lifecycle = FakeAppLifecycle(initial = false)
        val coordinator = build(lifecycle)

        lifecycle.foregroundFlow.value = true
        runCurrent()

        assertEquals(SosPhase.ACTIVE, coordinator.state.value.phase)
        assertEquals(5, coordinator.state.value.sosId)
    }

    @Test
    fun background_doesNotReconcile() = runTest {
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "pending", sosId = 5, phoneNumber = "9")
        sosLiveStore.markLive()   // reason present, so this asserts the LIFECYCLE gate, not the reason gate
        val lifecycle = FakeAppLifecycle(initial = false)
        val coordinator = build(lifecycle)

        runCurrent()   // stays background — no foreground emission

        assertEquals(SosPhase.IDLE, coordinator.state.value.phase)
    }

    @Test
    fun foreground_drainsPendingPush_appliedAfterReconcile() = runTest {
        // Backend has an initiated SOS; a "deny" push arrived while backgrounded.
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "initiated", sosId = 7, phoneNumber = "1")
        pushStore.persist("deny", 7)
        val lifecycle = FakeAppLifecycle(initial = false)
        val coordinator = build(lifecycle)

        lifecycle.foregroundFlow.value = true
        runCurrent()

        // reconcile → ALERT(7); drained deny applied → IDLE.
        assertEquals(SosPhase.IDLE, coordinator.state.value.phase)
    }

    @Test
    fun launchIntoForeground_reconcilesOnce() = runTest {
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "initiated", sosId = 7, phoneNumber = "1")
        sosLiveStore.markLive()   // killed mid-SOS → the marker is what makes launch reconcile at all
        val lifecycle = FakeAppLifecycle(initial = true)   // already foreground at construction
        val coordinator = build(lifecycle)

        runCurrent()

        assertEquals(SosPhase.ALERT, coordinator.state.value.phase)
        assertEquals(7, coordinator.state.value.sosId)
    }

    @Test
    fun launchWithNoPendingPushAndNoLiveSos_neverCallsActive() = runTest {
        // The reported bug: a plain launch fired GET /sos/active, which 401s while logged out and
        // trips the global unauthorized observer → forced logout. With no reason to reconcile the
        // call must not go out at all.
        sosApi.activeResult = ActiveSosState(hasActiveSos = true, status = "pending", sosId = 5, phoneNumber = "9")
        val lifecycle = FakeAppLifecycle(initial = true)
        val coordinator = build(lifecycle)

        runCurrent()

        assertEquals(0, sosApi.activeCalls)
        assertEquals(SosPhase.IDLE, coordinator.state.value.phase)
    }

    @Test
    fun resolvedSos_clearsMarker_soNextLaunchIsSilent() = runTest {
        // Self-heal: backend says nothing is active → drop the marker, else every future launch
        // would keep reconciling on a stale flag.
        sosLiveStore.markLive()
        sosApi.activeResult = ActiveSosState(hasActiveSos = false, status = null, sosId = null, phoneNumber = null)
        val lifecycle = FakeAppLifecycle(initial = true)
        build(lifecycle)

        runCurrent()

        assertEquals(false, sosLiveStore.isLive())
    }

    @Test
    fun foreground_reconcileFails_retainsPushForRetry() = runTest {
        // reconcile() throws → the guarded flow skips applyPush + clear(), so the pending push MUST survive
        // (peek didn't delete) for the next foreground to retry. Regressing to delete-before-apply (the old
        // drain semantics) would silently lose the SOS action here — this is the ack-after-apply guard.
        pushStore.persist("deny", 7)
        sosApi.activeThrows = true
        val lifecycle = FakeAppLifecycle(initial = false)
        build(lifecycle)

        lifecycle.foregroundFlow.value = true
        runCurrent()

        assertEquals("deny", pushStore.peek()?.action)   // retained (not cleared before apply)
    }
}
