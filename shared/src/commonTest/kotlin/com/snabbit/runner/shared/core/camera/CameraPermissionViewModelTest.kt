package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.camera.fakes.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.camera.fakes.FakeCameraModule
import com.snabbit.runner.shared.core.camera.fakes.FakeCameraPermissionController
import com.snabbit.runner.shared.core.camera.fakes.FakeCrashReporter
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.core.camera.internal.platformFileOps
import com.snabbit.runner.shared.core.camera.ui.CameraIntent
import com.snabbit.runner.shared.core.camera.ui.CameraPhase
import com.snabbit.runner.shared.core.camera.ui.CameraViewModel

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
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Tests the [CameraViewModel] permission gate (via [CameraPermissionController])
 * and the error-reporting fold-in ([CrashReporter]).
 *
 * The VM now launches on [kotlinx.coroutines.Dispatchers.Main] via `viewModelScope`,
 * so Main is redirected to an [UnconfinedTestDispatcher] (launched coroutines run
 * eagerly — every `dispatch` settles synchronously) and reset afterwards. Inputs go
 * through [CameraViewModel.dispatch]; error reporting is asserted on the crash
 * reporter's recorded `meta["code"]`.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CameraPermissionViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(
        permissions: CameraPermissionController,
        crashReporter: CrashReporter = CrashReporter { _, _ -> },
    ) = CameraViewModel(
        cameraModule = FakeCameraModule(),
        analyticsTracker = FakeAnalyticsTracker(),
        analyticsSource = "test",
        permissions = permissions,
        crashReporter = crashReporter,
        platformFileOps = platformFileOps(FakeCrashReporter(), TestAppDispatchers(dispatcher)),
    )

    // ── Permission gate ────────────────────────────────────────

    @Test
    fun `granted status proceeds straight to Initializing`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.GRANTED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.Start)

            assertEquals(CameraPhase.Initializing, vm.state.value.phase)
            assertEquals(0, perms.requestCalls) // no prompt when already granted
        }

    @Test
    fun `denied status requests then lands on PermissionDenied`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.DENIED,
                requestResult = CameraPermissionStatus.DENIED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.Start)

            assertEquals(CameraPhase.PermissionDenied, vm.state.value.phase)
            assertEquals(1, perms.requestCalls)
            assertTrue(vm.state.value.needsPermission)
        }

    @Test
    fun `permanently denied lands on PermissionPermanentlyDenied`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.DENIED,
                requestResult = CameraPermissionStatus.PERMANENTLY_DENIED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.Start)

            assertEquals(CameraPhase.PermissionPermanentlyDenied, vm.state.value.phase)
        }

    @Test
    fun `granted after request proceeds to Initializing`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.DENIED,
                requestResult = CameraPermissionStatus.GRANTED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.Start)

            assertEquals(CameraPhase.Initializing, vm.state.value.phase)
        }

    @Test
    fun `onStart is idempotent`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(statusResult = CameraPermissionStatus.GRANTED)
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.Start)
            vm.dispatch(CameraIntent.Start)
            vm.dispatch(CameraIntent.Start)

            assertEquals(1, perms.statusCalls) // gate ran once
        }

    @Test
    fun `RequestPermission re-requests from denied`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.DENIED,
                requestResult = CameraPermissionStatus.DENIED,
            )
            val vm = viewModel(perms)
            vm.dispatch(CameraIntent.Start) // → PermissionDenied (1 request)

            perms.requestResult = CameraPermissionStatus.GRANTED
            vm.dispatch(CameraIntent.RequestPermission) // user taps "Allow"

            assertEquals(CameraPhase.Initializing, vm.state.value.phase)
            assertEquals(2, perms.requestCalls)
        }

    @Test
    fun `Resumed rechecks and proceeds when granted in settings`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                statusResult = CameraPermissionStatus.DENIED,
                requestResult = CameraPermissionStatus.PERMANENTLY_DENIED,
            )
            val vm = viewModel(perms)
            vm.dispatch(CameraIntent.Start) // → PermissionPermanentlyDenied
            assertIs<CameraPhase.PermissionPermanentlyDenied>(vm.state.value.phase)

            // User granted it in app settings; status now reports GRANTED.
            perms.statusResult = CameraPermissionStatus.GRANTED
            vm.dispatch(CameraIntent.Resumed)

            assertEquals(CameraPhase.Initializing, vm.state.value.phase)
        }

    @Test
    fun `OpenAppSettings delegates to the controller`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController()
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.OpenAppSettings)

            assertEquals(1, perms.openSettingsCalls)
        }

    @Test
    fun `RequestMicrophone clears the audio-off banner when granted`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                microphoneResult = CameraPermissionStatus.GRANTED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.RequestMicrophone)

            assertEquals(1, perms.microphoneRequestCalls)
            assertFalse(vm.state.value.microphoneDenied)
        }

    @Test
    fun `denied mic flags the audio-off banner`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                microphoneResult = CameraPermissionStatus.PERMANENTLY_DENIED,
            )
            val vm = viewModel(perms)

            vm.dispatch(CameraIntent.RequestMicrophone)

            assertTrue(vm.state.value.microphoneDenied)
            assertTrue(vm.state.value.microphonePermanentlyDenied)
        }

    @Test
    fun `RequestMicrophone re-requests and clears the banner when granted`() =
        runTest(dispatcher) {
            val perms = FakeCameraPermissionController(
                microphoneResult = CameraPermissionStatus.DENIED,
            )
            val vm = viewModel(perms)
            vm.dispatch(CameraIntent.RequestMicrophone) // denied → banner on
            assertTrue(vm.state.value.microphoneDenied)

            perms.microphoneResult = CameraPermissionStatus.GRANTED
            vm.dispatch(CameraIntent.RequestMicrophone)

            assertEquals(2, perms.microphoneRequestCalls)
            assertFalse(vm.state.value.microphoneDenied)
        }

    // ── Error reporting (folded into CrashReporter) ────────────

    @Test
    fun `camera init error is reported`() =
        runTest(dispatcher) {
            val reporter = FakeCrashReporter()
            val vm = viewModel(FakeCameraPermissionController(), reporter)

            vm.dispatch(CameraIntent.CameraError("init failed"))

            assertEquals(1, reporter.reported.size)
            assertEquals(CameraErrorCode.CAMERA_NOT_READY, reporter.reported.first().second["code"])
        }

    @Test
    fun `init timeout while initializing reports CAMERA_NOT_READY`() =
        runTest(dispatcher) {
            val reporter = FakeCrashReporter()
            val perms = FakeCameraPermissionController(statusResult = CameraPermissionStatus.GRANTED)
            val vm = viewModel(perms, reporter)
            vm.dispatch(CameraIntent.Start) // GRANTED → Initializing

            vm.dispatch(CameraIntent.CameraInitTimeout)

            assertIs<CameraPhase.Error>(vm.state.value.phase)
            assertEquals(CameraErrorCode.CAMERA_NOT_READY, reporter.reported.single().second["code"])
        }

    @Test
    fun `init timeout is a no-op once the camera is ready`() =
        runTest(dispatcher) {
            val reporter = FakeCrashReporter()
            val perms = FakeCameraPermissionController(statusResult = CameraPermissionStatus.GRANTED)
            val vm = viewModel(perms, reporter)
            vm.dispatch(CameraIntent.Start)
            vm.dispatch(CameraIntent.CameraReady) // → Ready

            vm.dispatch(CameraIntent.CameraInitTimeout)

            assertEquals(CameraPhase.Ready, vm.state.value.phase)
            assertTrue(reporter.reported.isEmpty())
        }

    @Test
    fun `capture error is reported with code and context`() =
        runTest(dispatcher) {
            val reporter = FakeCrashReporter()
            val vm = viewModel(FakeCameraPermissionController(), reporter)

            vm.dispatch(
                CameraIntent.CaptureCompleted(
                    CameraResult.Error(CameraErrorCode.STORAGE_FULL, "disk full"),
                ),
            )

            val reported = reporter.reported.single()
            assertEquals(CameraErrorCode.STORAGE_FULL, reported.second["code"])
            assertTrue(reported.second.containsKey("lens"))
        }
}
