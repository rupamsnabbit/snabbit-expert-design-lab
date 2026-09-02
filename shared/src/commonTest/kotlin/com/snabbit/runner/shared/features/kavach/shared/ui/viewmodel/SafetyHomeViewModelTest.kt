package com.snabbit.runner.shared.features.kavach.shared.ui.viewmodel

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.RecordingCrashReporter
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeSafetyDataSource
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyCondition
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionGate
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeIntent
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetySheet
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.ProtectionState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SafetyHomeViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val dataSource = FakeSafetyDataSource()
    private val nav = NavigationController(
        deeplinkResolver = DeeplinkResolver(emptyList()),
        logger = FakeLogger(),
        crashReporter = RecordingCrashReporter(),
    )

    private val shield = FakeShieldController()
    private val sosApi = FakeSosApi()
    private val analytics = FakeAnalyticsTracker()
    private val permissionManager = FakePermissionManager(defaultStatus = PermissionStatus.GRANTED)
    private val permissionGate = KavachPermissionGate(permissionManager)
    private val lifecycle = FakeAppLifecycle(initial = true)
    private val sosCoordinator = SosCoordinator(shield, sosApi, FakeRemoteConfigGateway(), FakeAppLifecycle(initial = true), FakeCurrentStateGateway(), FakeAnalyticsTracker(), testAppDispatchers(dispatcher))

    private fun viewModel() = SafetyHomeViewModel(nav, dataSource, sosCoordinator, permissionGate, lifecycle, analytics)

    @BeforeTest fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterTest fun tearDown() = Dispatchers.resetMain()

    @Test
    fun confirmConsent_whenPermissionDenied_blocksActivation() = runTest {
        permissionManager.defaultStatus = PermissionStatus.DENIED
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertEquals(0, dataSource.activateCalls)                                  // engine never started
        assertEquals(KavachPermissionResult.Denied, vm.uiState.value.permissionResult)   // dialog surfaced
    }

    @Test
    fun retryPermission_reRequests_clearsDialogAndActivates() = runTest {
        permissionManager.defaultStatus = PermissionStatus.DENIED
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertEquals(KavachPermissionResult.Denied, vm.uiState.value.permissionResult)
        // Grant, then "Try again" → dialog clears and the engine starts.
        permissionManager.defaultStatus = PermissionStatus.GRANTED
        vm.onIntent(SafetyHomeIntent.RetryPermission)
        assertNull(vm.uiState.value.permissionResult)
        assertEquals(1, dataSource.activateCalls)
        assertEquals(ProtectionState.ACTIVE, vm.uiState.value.protectionState)
    }

    @Test
    fun onResume_whenPermissionNowGranted_dismissesDialog() = runTest {
        permissionManager.defaultStatus = PermissionStatus.DENIED
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertEquals(KavachPermissionResult.Denied, vm.uiState.value.permissionResult)
        // Runner goes to Settings (background) and returns having granted → dialog auto-dismisses.
        lifecycle.foregroundFlow.value = false
        permissionManager.defaultStatus = PermissionStatus.GRANTED
        lifecycle.foregroundFlow.value = true
        assertNull(vm.uiState.value.permissionResult)
    }

    @Test
    fun onResume_whenStillDenied_keepsDialog() = runTest {
        permissionManager.defaultStatus = PermissionStatus.DENIED
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        // Returns without granting → dialog stays.
        lifecycle.foregroundFlow.value = false
        lifecycle.foregroundFlow.value = true
        assertEquals(KavachPermissionResult.Denied, vm.uiState.value.permissionResult)
    }

    @Test
    fun openAppSettings_opensSettingsAndClearsDialog() = runTest {
        permissionManager.defaultStatus = PermissionStatus.DENIED_ALWAYS
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertEquals(KavachPermissionResult.NeedsSettings, vm.uiState.value.permissionResult)
        val before = permissionManager.openSettingsCalls   // gate already auto-opened once
        vm.onIntent(SafetyHomeIntent.OpenAppSettings)
        assertNull(vm.uiState.value.permissionResult)
        assertTrue(permissionManager.openSettingsCalls > before)
    }

    @Test
    fun initialState_isIdle() = runTest(dispatcher) {
        assertEquals(ProtectionState.IDLE, viewModel().uiState.value.protectionState)
    }

    @Test
    fun activate_showsKeepPhoneSheet_whenCountNotExhausted() = runTest(dispatcher) {
        val vm = viewModel()   // FakeSafetyDataSource.activationSheetShouldShow defaults true
        vm.onIntent(SafetyHomeIntent.Activate)
        assertEquals(SafetySheet.KEEP_PHONE, vm.uiState.value.sheet)
        assertEquals(1, dataSource.markActivationShownCalls)
        assertEquals(0, dataSource.activateCalls)   // sheet first — engine waits for the CTA
    }

    @Test
    fun activate_countExhausted_activatesDirectly() = runTest(dispatcher) {
        dataSource.activationSheetShouldShow = false   // RC cap reached → skip the info sheet
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.Activate)
        assertNull(vm.uiState.value.sheet)
        assertEquals(1, dataSource.activateCalls)
    }

    @Test
    fun confirmKeepPhone_activates() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.Activate)           // → KEEP_PHONE sheet
        vm.onIntent(SafetyHomeIntent.ConfirmKeepPhone)   // CTA "Got it" → start engine
        assertEquals(1, dataSource.activateCalls)
        assertEquals(ProtectionState.ACTIVE, vm.uiState.value.protectionState)
    }

    @Test
    fun confirmConsent_activatesAndClearsSheet() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertEquals(1, dataSource.activateCalls)
        assertEquals(ProtectionState.ACTIVE, vm.uiState.value.protectionState)
        assertNull(vm.uiState.value.sheet)
    }

    @Test
    fun confirmConsent_failure_setsErrorAndStaysIdle() = runTest(dispatcher) {
        dataSource.throwOnActivate = true
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.ConfirmConsent)
        assertNotNull(vm.uiState.value.error)
        assertEquals(ProtectionState.IDLE, vm.uiState.value.protectionState)
    }

    @Test
    fun openSos_raisesAlert() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.OpenSos)
        assertTrue(vm.uiState.value.sosAlertVisible)
        assertTrue(shield.calls.contains("triggerManualSoS"))
    }

    @Test
    fun openSos_whileSosAlreadyLive_flagsInProgress_andDoesNotReRaise() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.OpenSos)          // raise #1 → ALERT
        assertTrue(vm.uiState.value.sosAlertVisible)
        val callsAfterFirst = shield.calls.count { it == "triggerManualSoS" }
        vm.onIntent(SafetyHomeIntent.OpenSos)          // tap again while live
        assertTrue(vm.uiState.value.sosInProgress)     // R4: flagged, not silent
        assertEquals(callsAfterFirst, shield.calls.count { it == "triggerManualSoS" })   // no re-raise
        vm.onIntent(SafetyHomeIntent.SosInProgressShown)
        assertEquals(false, vm.uiState.value.sosInProgress)
    }

    @Test
    fun confirmSos_confirms() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.OpenSos)
        vm.onIntent(SafetyHomeIntent.ConfirmSos)
        assertTrue(shield.calls.contains("confirmSoS"))
        // Nav to SosActive is now owned by the app-scoped AppSosHost, not this VM.
    }

    @Test
    fun denySos_hidesAlert() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.OpenSos)
        vm.onIntent(SafetyHomeIntent.DenySos)
        assertTrue(shield.calls.contains("denySoS"))
        assertEquals(false, vm.uiState.value.sosAlertVisible)
    }

    @Test
    fun dismissSheet_clearsSheet() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onIntent(SafetyHomeIntent.Activate)
        vm.onIntent(SafetyHomeIntent.DismissSheet)
        assertNull(vm.uiState.value.sheet)
    }

    @Test
    fun batteryLowCondition_showsSheet() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.conditionState.value = SafetyCondition.BATTERY_LOW
        assertEquals(SafetySheet.BATTERY_LOW, vm.uiState.value.sheet)
    }

    @Test
    fun noStorageCondition_setsPill() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.conditionState.value = SafetyCondition.NO_STORAGE
        assertTrue(vm.uiState.value.noStorage)
    }

    @Test
    fun noStorageCondition_emitsStorageWarningOnce() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.conditionState.value = SafetyCondition.NO_STORAGE
        assertEquals(1, analytics.names().count { it == "expert_shield_storage_warning" })
    }

    // ── induced-fix coverage: info_dismiss latch + banner visible/hidden transitions ──

    @Test
    fun dismissInfoSheet_firesInfoDismiss() = runTest(dispatcher) {
        val vm = viewModel()                            // activationSheetShouldShow defaults true
        vm.onIntent(SafetyHomeIntent.Activate)          // info sheet (KEEP_PHONE) shown + latch set
        assertEquals(SafetySheet.KEEP_PHONE, vm.uiState.value.sheet)
        vm.onIntent(SafetyHomeIntent.DismissSheet)
        assertTrue(analytics.names().contains("expert_shield_info_dismiss"))
    }

    @Test
    fun dismissConditionSheet_doesNotFireInfoDismiss() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.conditionState.value = SafetyCondition.BATTERY_LOW   // condition sheet, not the info sheet
        assertEquals(SafetySheet.BATTERY_LOW, vm.uiState.value.sheet)
        vm.onIntent(SafetyHomeIntent.DismissSheet)
        assertTrue(!analytics.names().contains("expert_shield_info_dismiss"))
    }

    @Test
    fun monitoringEdges_fireBannerVisibleThenHidden() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.shieldStateFlow.value = SafetyState.MONITORING   // card appears (monitoring false→true)
        assertTrue(analytics.names().contains("expert_shield_banner_visible"))
        dataSource.shieldStateFlow.value = SafetyState.IDLE         // card removed (true→false)
        assertTrue(analytics.names().contains("expert_shield_banner_hidden"))
    }

    @Test
    fun pluginRecordingState_mirrorsToActive() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.recordingStateFlow.value = RecordingState.RECORDING
        assertTrue(vm.uiState.value.recording)
        assertEquals(ProtectionState.ACTIVE, vm.uiState.value.protectionState)
    }

    @Test
    fun pluginSosState_mirrorsToSosMode() = runTest(dispatcher) {
        val vm = viewModel()
        dataSource.shieldStateFlow.value = SafetyState.SOS_PENDING
        assertTrue(vm.uiState.value.sosMode)
    }
}
