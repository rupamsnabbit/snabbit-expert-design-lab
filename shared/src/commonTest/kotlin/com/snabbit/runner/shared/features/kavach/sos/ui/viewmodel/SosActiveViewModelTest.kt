package com.snabbit.runner.shared.features.kavach.sos.ui.viewmodel

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.RecordingCrashReporter
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import com.snabbit.runner.shared.features.kavach.sos.ui.contracts.SosActiveIntent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SosActiveViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val shield = FakeShieldController()
    private val sosApi = FakeSosApi()
    private val analytics = FakeAnalyticsTracker()
    private val coordinator = SosCoordinator(shield, sosApi, FakeRemoteConfigGateway(), FakeAppLifecycle(initial = true), FakeCurrentStateGateway(), FakeAnalyticsTracker(), testAppDispatchers(dispatcher))
    private val nav = NavigationController(
        deeplinkResolver = DeeplinkResolver(emptyList()),
        logger = FakeLogger(),
        crashReporter = RecordingCrashReporter(),
    )

    private fun viewModel() = SosActiveViewModel(nav, coordinator, analytics)

    @BeforeTest fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterTest fun tearDown() = Dispatchers.resetMain()

    @Test
    fun callSosTeam_dialsTheTeam() = runTest(dispatcher) {
        viewModel().onIntent(SosActiveIntent.CallSosTeam)
        assertEquals(1, sosApi.callSosTeamCalls)
    }

    @Test
    fun callSosTeam_apiRejects_surfacesError() = runTest(dispatcher) {
        // The dead-button fix: callSosTeam() returning false (blank phone / API reject) must surface a
        // visible error, not a silent no-op.
        sosApi.callResult = false
        val vm = viewModel()
        vm.onIntent(SosActiveIntent.CallSosTeam)
        assertEquals(AppErrorType.OTHER_ERROR, vm.uiState.value.error)
    }

    @Test
    fun markSafe_deescalatesAndPopsBack() = runTest(dispatcher) {
        coordinator.raiseManual()
        coordinator.confirm()          // ACTIVE
        nav.navigate(SosActive)        // simulate having navigated to this screen
        viewModel().onIntent(SosActiveIntent.MarkSafe)
        assertTrue(shield.calls.contains("deescalateSoS"))
        assertTrue(nav.backStack.isEmpty())
    }

    @Test
    fun resolvesToIdle_withoutObservingActive_stillPops() = runTest(dispatcher) {
        // Screen was navigated to, but the SOS resolved (IDLE) before this VM's cold collector observed
        // ACTIVE (the pre-subscribe conflation race). observeResolve pops on ANY IDLE, not the edge —
        // so the "Help is on the way" screen isn't stranded. (Would fail under the old last==ACTIVE gate.)
        nav.navigate(SosActive)
        viewModel()                    // coordinator is IDLE → first emission IDLE → pop
        assertTrue(nav.backStack.isEmpty())
    }
}
