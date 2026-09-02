package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
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
 * [ProfileViewModel] now reads the bridge-fed [RunnerProfileStore] (Dart pushes
 * `runners/me`; KMP does not fetch natively) instead of a repository. Tests seed the
 * store via [storeFrom]: the first response is the "launch push", and a fake reverse
 * bridge advances to the next response on each `requestRefresh` (Load retry / Refresh) —
 * mirroring the old FIFO fake so the assertions read the same.
 *
 * `viewModelScope` runs on Dispatchers.Main.immediate, so tests install an
 * [UnconfinedTestDispatcher] as Main — the store collector launched in `init` then runs
 * eagerly, letting assertions read `uiState.value` directly.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ProfileViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @BeforeTest
    fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterTest
    fun tearDown() = Dispatchers.resetMain()

    /**
     * A [RunnerProfileStore] seeded to the first [responses] entry (Dart's launch push),
     * with a fake reverse-refresh bridge that advances to the next entry on each
     * [RunnerProfileStore.requestRefresh]. `Ok` → `setProfile`, `Err` → `pushProfileError`.
     */
    private fun storeFrom(vararg responses: Result<RunnerProfile, RunnerActionError>): RunnerProfileStore {
        val queue = ArrayDeque(responses.toList())
        val store = RunnerProfileStore(FakeLogger())
        fun push(r: Result<RunnerProfile, RunnerActionError>) {
            when (r) {
                is Result.Ok -> store.setProfile(r.value)
                is Result.Err -> store.pushProfileError("test_error")
            }
        }
        queue.removeFirstOrNull()?.let { push(it) }
        store.bind { queue.removeFirstOrNull()?.let { push(it) } }
        return store
    }

    private fun viewModel(
        store: RunnerProfileStore,
        remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
        runnerStateStore: RunnerStateStore? = null,
        // Last, so the existing call sites can keep passing it as a trailing lambda.
        onEvent: (String, Map<String, Any?>) -> Unit = { _, _ -> },
    ): ProfileViewModel =
        ProfileViewModel(
            profileStore = store,
            strings = ProfileStrings(),
            trackEvent = onEvent,
            remoteConfig = remoteConfig,
            runnerStateStore = runnerStateStore,
        )

    @Test
    fun load_success_populatesProfile() = runTest(dispatcher) {
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile(name = "Reema Saju"))))

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertEquals("Reema Saju", state.profile?.name)
        assertNull(state.errorMessage)
    }

    @Test
    fun load_failure_setsErrorAndNoProfile() = runTest(dispatcher) {
        val vm = viewModel(storeFrom(Result.Err(RunnerActionError.Server)))

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertNull(state.profile)
        assertEquals(ProfileStrings().errorMessage, state.errorMessage)
    }

    @Test
    fun retry_afterError_loadsProfileAndClearsError() = runTest(dispatcher) {
        val vm = viewModel(
            storeFrom(
                Result.Err(RunnerActionError.NoConnection),
                Result.Ok(sampleRunnerProfile(name = "Reema Saju")),
            ),
        )
        assertEquals(ProfileStrings().errorMessage, vm.uiState.value.errorMessage)

        vm.onIntent(ProfileUiIntent.Load)

        val state = vm.uiState.value
        assertEquals("Reema Saju", state.profile?.name)
        assertNull(state.errorMessage)
    }

    @Test
    fun refresh_failure_keepsExistingProfile() = runTest(dispatcher) {
        val vm = viewModel(
            storeFrom(
                Result.Ok(sampleRunnerProfile(name = "Reema Saju")),
                Result.Err(RunnerActionError.Server),
            ),
        )
        assertEquals("Reema Saju", vm.uiState.value.profile?.name)

        vm.onIntent(ProfileUiIntent.Refresh)

        val state = vm.uiState.value
        assertFalse(state.isRefreshing)
        // Refresh failure must not wipe the loaded profile (the error push no-ops on Content).
        assertEquals("Reema Saju", state.profile?.name)
    }

    @Test
    fun load_success_firesSidebarLoadEventOnce() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        viewModel(storeFrom(Result.Ok(sampleRunnerProfile(name = "Reema Saju")))) { name, props ->
            events.add(name to props)
        }

        // Both the legacy sidebar-load and the expert-v2 profile_screen_load fire once.
        assertEquals(listOf("profile_section_sidebar_load", "profile_screen_load"), events.map { it.first })
        val sidebar = events.first { it.first == "profile_section_sidebar_load" }
        assertTrue(sidebar.second.containsKey("list_visible"))
    }

    @Test
    fun secondLoad_doesNotRefireSidebarLoad() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val vm = viewModel(
            storeFrom(
                Result.Ok(sampleRunnerProfile()),
                Result.Ok(sampleRunnerProfile()),
            ),
        ) { name, props -> events.add(name to props) }
        assertEquals(1, events.count { it.first == "profile_section_sidebar_load" })

        vm.onIntent(ProfileUiIntent.Load)

        // Fire-once guard: the load events log a single time per VM instance.
        assertEquals(1, events.count { it.first == "profile_section_sidebar_load" })
        assertEquals(1, events.count { it.first == "profile_screen_load" })
    }

    @Test
    fun load_failure_doesNotFireSidebarLoad() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        viewModel(storeFrom(Result.Err(RunnerActionError.Server))) { name, props ->
            events.add(name to props)
        }

        // The load event is parity for a *loaded* sidebar — never on an error.
        assertTrue(events.isEmpty())
    }

    @Test
    fun load_defaultRemoteConfig_showsEarnings_hidesReferralsV2() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        // Default gateway returns each caller default → showEarnings true, referralsV2 false.
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile()))) { name, props ->
            events.add(name to props)
        }

        assertTrue(vm.uiState.value.showEarnings)
        assertFalse(vm.uiState.value.referralsV2Enabled)
        @Suppress("UNCHECKED_CAST")
        val listVisible = events.first { it.first == "profile_section_sidebar_load" }
            .second["list_visible"] as List<String>
        assertTrue(listVisible.contains("earnings"))
    }

    @Test
    fun load_appliesRemoteConfigGates() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val rc = RemoteConfigGateway { key, _ ->
            when (key) {
                "expert_show_earnings" -> false
                "expert_is_referrals_v2_enabled" -> true
                else -> false
            }
        }
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile())), remoteConfig = rc) { name, props ->
            events.add(name to props)
        }

        val state = vm.uiState.value
        assertFalse(state.showEarnings)
        assertTrue(state.referralsV2Enabled)
        // list_visible mirrors the gate: no "earnings" entry when it's hidden.
        @Suppress("UNCHECKED_CAST")
        val listVisible = events.first { it.first == "profile_section_sidebar_load" }
            .second["list_visible"] as List<String>
        assertFalse(listVisible.contains("earnings"))
    }

    @Test
    fun menuItemTapped_firesProfileScreenCtaClick() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile()))) { name, props ->
            events.add(name to props)
        }
        vm.onIntent(ProfileUiIntent.MenuItemTapped(cta = "language", section = "account"))
        val cta = events.last { it.first == "profile_screen_cta_click" }
        assertEquals("language", cta.second["cta_text"])
        assertEquals("account", cta.second["section"])
    }

    @Test
    fun nudgeTapped_firesSpotlightCtaClick() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile()))) { name, props ->
            events.add(name to props)
        }
        vm.onIntent(ProfileUiIntent.NudgeTapped("pan"))
        assertEquals("pan", events.last { it.first == "spotlight_nudge_screen_cta_click" }.second["nudge_id"])
    }

    /**
     * The Emergency-logout tile gate: on-shift widget_names only, live as the shift moves.
     * Covers both branches of the allowlist check plus the no-store (tests/previews) default.
     */
    @Test
    fun canEmergencyLogout_trueOnlyForOnShiftWidgetNames() = runTest(dispatcher) {
        val runnerState = RunnerStateStore(FakeLogger())
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile())), runnerStateStore = runnerState)

        // Nothing pushed yet → hidden.
        assertFalse(vm.uiState.value.canEmergencyLogout)

        runnerState.pushState("""{"widget_name":"RUNNER_ATTENDANCE_TODAY","widget_data":{}}""")
        assertFalse(vm.uiState.value.canEmergencyLogout)

        runnerState.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}""")
        assertTrue(vm.uiState.value.canEmergencyLogout)

        // Picked up a job mid-shift → hidden again.
        runnerState.pushState("""{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{}}""")
        assertFalse(vm.uiState.value.canEmergencyLogout)

        runnerState.pushState("""{"widget_name":"RUNNER_LOGOUT","widget_data":{}}""")
        assertTrue(vm.uiState.value.canEmergencyLogout)
    }

    @Test
    fun canEmergencyLogout_falseWhenNoRunnerStateStore() = runTest(dispatcher) {
        val vm = viewModel(storeFrom(Result.Ok(sampleRunnerProfile())))
        assertFalse(vm.uiState.value.canEmergencyLogout)
    }
}
