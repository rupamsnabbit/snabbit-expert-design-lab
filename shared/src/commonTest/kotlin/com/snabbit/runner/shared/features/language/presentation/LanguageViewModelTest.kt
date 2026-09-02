package com.snabbit.runner.shared.features.language.presentation

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.RecordingCrashReporter
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.language.FakeLanguageAnalytics
import com.snabbit.runner.shared.features.language.FakeLanguageDataSource
import com.snabbit.runner.shared.features.language.FakeProfileGateway
import com.snabbit.runner.shared.features.language.LanguageAnalytics
import com.snabbit.runner.shared.features.language.LanguageDestination
import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.ProfileGateway
import com.snabbit.runner.shared.features.language.domain.usecase.SetLanguageUseCase
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
 * D1 ViewModel test: `viewModelScope` runs on the injected Main dispatcher. An
 * [UnconfinedTestDispatcher] makes the coroutines the VM launches (load on init,
 * confirm) run eagerly to completion against the non-suspending fakes — so
 * assertions can read state directly, no scheduler advancing needed.
 *
 * Navigation is a real [NavigationController] (a plain state holder); with no host
 * attached, `back()` at the root empties [NavigationController.backStack] — the
 * unit-test "returned to Flutter" signal.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class LanguageViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val nav = NavigationController(
        deeplinkResolver = DeeplinkResolver(emptyList()),
        logger = FakeLogger(),
        crashReporter = RecordingCrashReporter(),
    )

    @BeforeTest fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterTest fun tearDown() = Dispatchers.resetMain()

    /** The same [dataSource] instance backs both load and the use-case's persist. */
    private fun viewModel(
        dataSource: LanguageDataSource = FakeLanguageDataSource(),
        profileGateway: ProfileGateway = FakeProfileGateway(),
        analytics: LanguageAnalytics = FakeLanguageAnalytics(),
        strings: LanguageStrings = LanguageStrings(),
        currentLanguage: String? = null,
    ): LanguageViewModel = LanguageViewModel(
        dataSource = dataSource,
        setLanguage = SetLanguageUseCase(dataSource, profileGateway),
        analytics = analytics,
        nav = nav,
        strings = strings,
        currentLanguage = currentLanguage,
    )

    @Test
    fun screenViewed_firesOnInit() = runTest {
        val analytics = FakeLanguageAnalytics()
        viewModel(analytics = analytics)
        assertEquals(1, analytics.screenViewedCount)
    }

    @Test
    fun load_populatesLanguagesAndCurrentSelection() = runTest {
        val vm = viewModel(currentLanguage = "hi")

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertEquals(3, state.languages.size)
        assertEquals("hi", state.selectedCode)
        assertNull(state.errorMessage)
    }

    @Test
    fun load_failure_setsErrorAndLeavesListEmpty() = runTest {
        val vm = viewModel(
            dataSource = FakeLanguageDataSource(error = RuntimeException("network")),
        )

        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertTrue(state.languages.isEmpty())
        assertEquals("Couldn't load languages", state.errorMessage)
    }

    @Test
    fun onLanguageSelected_updatesStateAndFiresAnalytics() = runTest {
        val analytics = FakeLanguageAnalytics()
        val vm = viewModel(analytics = analytics)

        vm.onIntent(LanguageUiIntent.Select("kn"))

        assertEquals("kn", vm.uiState.value.selectedCode)
        assertEquals(listOf("kn"), analytics.selected)
    }

    @Test
    fun onConfirm_success_persists_appliesLocally_firesAnalytics_andFlagsSuccess() = runTest {
        val dataSource = FakeLanguageDataSource()
        val profile = FakeProfileGateway()
        val analytics = FakeLanguageAnalytics()
        val vm = viewModel(
            dataSource = dataSource,
            profileGateway = profile,
            analytics = analytics,
        )

        vm.onIntent(LanguageUiIntent.Select("hi"))
        vm.onIntent(LanguageUiIntent.Confirm)

        assertEquals(listOf("hi"), dataSource.setLanguageCalls)
        assertEquals(listOf("hi"), profile.applyLanguageCalls)
        assertEquals(listOf("hi"), analytics.confirmed)
        assertFalse(vm.uiState.value.isSaving)
        assertTrue(vm.uiState.value.saveSucceeded)
    }

    @Test
    fun onSaveAcknowledged_popsNavBackToFlutter() = runTest {
        nav.navigate(LanguageDestination())      // the screen is on the native stack
        val vm = viewModel(currentLanguage = "en")

        vm.onIntent(LanguageUiIntent.Confirm)
        vm.onIntent(LanguageUiIntent.SaveAcknowledged)

        assertTrue(nav.backStack.isEmpty())      // back() at the root returned to Flutter
    }

    @Test
    fun onNavigateUp_popsNavBackToFlutter() = runTest {
        nav.navigate(LanguageDestination())
        val vm = viewModel()

        vm.onIntent(LanguageUiIntent.NavigateUp)

        assertTrue(nav.backStack.isEmpty())
    }

    @Test
    fun dismiss_isOneShot_fastDoubleBackDoesNotOverPop() = runTest {
        // A screen beneath (e.g. the shell), then the language screen on top.
        nav.navigate(LanguageDestination())
        nav.navigate(LanguageDestination())
        val vm = viewModel()

        vm.onIntent(LanguageUiIntent.NavigateUp)
        vm.onIntent(LanguageUiIntent.NavigateUp) // fast second tap — must no-op

        // Only the top entry popped; the entry beneath survives (without the guard
        // the 2nd back() would hit the root and clear the whole stack).
        assertEquals(1, nav.backStack.size)
    }

    @Test
    fun onConfirm_persistFailure_setsError_doesNotApplyLocally() = runTest {
        val dataSource = FakeLanguageDataSource(
            setLanguageError = RuntimeException("save failed"),
        )
        val profile = FakeProfileGateway()
        val analytics = FakeLanguageAnalytics()
        val vm = viewModel(
            dataSource = dataSource,
            profileGateway = profile,
            analytics = analytics,
            currentLanguage = "en",
        )

        vm.onIntent(LanguageUiIntent.Confirm)

        val state = vm.uiState.value
        assertEquals("Saving language failed", state.errorMessage)
        assertFalse(state.isSaving)
        assertTrue(analytics.confirmed.isEmpty())
        assertTrue(profile.applyLanguageCalls.isEmpty())
    }

    @Test
    fun onConfirm_applyLanguageFailure_stillSucceeds() = runTest {
        // Server-side persist already succeeded; a Flutter-bridge failure on
        // applyLanguage must not surface as a save error or block dismiss.
        val dataSource = FakeLanguageDataSource()
        val profile = FakeProfileGateway(
            applyLanguageError = RuntimeException("bridge timeout"),
        )
        val analytics = FakeLanguageAnalytics()
        val vm = viewModel(
            dataSource = dataSource,
            profileGateway = profile,
            analytics = analytics,
        )

        vm.onIntent(LanguageUiIntent.Select("hi"))
        vm.onIntent(LanguageUiIntent.Confirm)

        val state = vm.uiState.value
        assertEquals(listOf("hi"), dataSource.setLanguageCalls)
        assertEquals(listOf("hi"), analytics.confirmed)
        assertFalse(state.isSaving)
        assertTrue(state.saveSucceeded)
        assertNull(state.errorMessage)
    }
}
