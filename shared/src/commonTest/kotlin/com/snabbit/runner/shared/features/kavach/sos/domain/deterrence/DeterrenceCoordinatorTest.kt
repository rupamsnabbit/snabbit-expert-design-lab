package com.snabbit.runner.shared.features.kavach.sos.domain.deterrence
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator

import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeDeterrenceAudioPlayer
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DeterrenceCoordinatorTest {

    private val shield = FakeShieldController()
    private val sosApi = FakeSosApi()
    private val rc = FakeRemoteConfigGateway()
    private val analytics = FakeAnalyticsTracker()
    private val audio = FakeDeterrenceAudioPlayer()

    // Real SosCoordinator + the coordinator under test, sharing the virtual-time scheduler.
    private fun TestScope.wire(): SosCoordinator {
        val d = StandardTestDispatcher(testScheduler)
        val sos = SosCoordinator(shield, sosApi, rc, FakeAppLifecycle(initial = true), FakeCurrentStateGateway(), FakeAnalyticsTracker(), testAppDispatchers(d))
        DeterrenceCoordinator(sos, audio, rc, analytics, testAppDispatchers(d))
        return sos
    }

    private suspend fun SosCoordinator.goActive() {
        raiseManual()   // → ALERT
        confirm()       // → ACTIVE (cancels the alert timer)
    }

    @Test
    fun activePhase_playsAfterDefaultDelay_withSosProps() = runTest {
        val sos = wire()
        sos.goActive()
        runCurrent()                       // coordinator sees ACTIVE → schedule() (default 3s)
        advanceTimeBy(3_000); runCurrent()

        assertEquals(1, audio.playCount)
        val e = analytics.last("expert_shield_deterrence_played")
        assertTrue(e != null)
        assertEquals(1, e.props["sos_id"])          // FakeSosApi.initiateResult
        assertEquals("manual", e.props["source"])   // manual raise
    }

    @Test
    fun leaveActiveBeforeDelay_doesNotPlay_andStops() = runTest {
        val sos = wire()
        sos.goActive()
        runCurrent()
        advanceTimeBy(2_000)               // before the 3s fire
        sos.deescalate(); runCurrent()     // → IDLE → cancel()
        advanceTimeBy(2_000); runCurrent() // past the original fire time

        assertEquals(0, audio.playCount)
        assertTrue(audio.stopCount >= 1)
    }

    @Test
    fun rcDelayIsHonoured() = runTest {
        rc.ints["expert_shield_sos_deterrence_delay_secs"] = 5
        val sos = wire()
        sos.goActive()
        runCurrent()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(0, audio.playCount)   // not yet — RC delay is 5s
        advanceTimeBy(2_000); runCurrent()
        assertEquals(1, audio.playCount)
    }

    @Test
    fun reenterActive_reschedulesForTheNewSession() = runTest {
        val sos = wire()
        sos.goActive()
        runCurrent()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(1, audio.playCount)

        sos.deescalate(); runCurrent()     // → IDLE
        sos.goActive()                     // new SOS
        runCurrent()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(2, audio.playCount)
    }
}
