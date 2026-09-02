package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.camera.fakes.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.camera.fakes.FakeCameraModule
import com.snabbit.runner.shared.core.camera.fakes.FakeCameraPermissionController
import com.snabbit.runner.shared.core.camera.fakes.FakeCrashReporter
import com.snabbit.runner.shared.core.camera.fakes.FakeMediaPersister
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.core.camera.internal.platformFileOps
import com.snabbit.runner.shared.core.camera.ui.CameraCommand
import com.snabbit.runner.shared.core.camera.ui.CameraEffect
import com.snabbit.runner.shared.core.camera.ui.CameraIntent
import com.snabbit.runner.shared.core.camera.ui.CameraPhase
import com.snabbit.runner.shared.core.camera.ui.CameraViewModel
import com.snabbit.runner.shared.core.camera.ui.PreviewMode

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Tests the [CameraViewModel] capture↔preview flow state machine
 * (the testable core of [com.snabbit.runner.shared.core.camera.ui.CameraFlow]).
 *
 * The VM launches on [kotlinx.coroutines.Dispatchers.Main] via `viewModelScope`,
 * so Main is redirected to an [UnconfinedTestDispatcher] (launched collectors of
 * `effects` / `commands` run eagerly — emissions are captured deterministically
 * without manual scheduler advancement) and reset afterwards. The old
 * `CameraFlowState` navigation is now [com.snabbit.runner.shared.core.camera.ui.CameraUiState.preview]
 * (`null` = capturing, non-null = previewing).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CameraFlowViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    private val photo = CameraResult.Photo(filePath = "/tmp/p.jpg", token = "t1", sizeBytes = 1234)

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(
        previewMode: PreviewMode,
        mediaPersister: MediaPersister = NoOpMediaPersister,
        crashReporter: CrashReporter = CrashReporter { _, _ -> },
    ) = CameraViewModel(
        cameraModule = FakeCameraModule(),
        analyticsTracker = FakeAnalyticsTracker(),
        analyticsSource = "test",
        permissions = FakeCameraPermissionController(),
        crashReporter = crashReporter,
        // Real seam (Android actual under testDebugUnitTest); the VM only uses it to
        // reclaim temps (deleteFile on the preview path), a no-op for these fixtures.
        platformFileOps = platformFileOps(FakeCrashReporter(), TestAppDispatchers(dispatcher)),
        previewMode = previewMode,
        mediaPersister = mediaPersister,
    )

    /** Subscribes an eager collector to `vm.effects`, capturing delivered results. */
    private fun TestScope.collectResults(vm: CameraViewModel): Pair<MutableList<CameraResult>, Job> {
        val received = mutableListOf<CameraResult>()
        val job = backgroundScope.launch {
            vm.effects.collect { if (it is CameraEffect.DeliverResult) received.add(it.result) }
        }
        return received to job
    }

    // ── Disabled: emit immediately, no preview ─────────────────

    @Test
    fun `disabled mode emits result immediately and stays on capture`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Disabled)
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))

            assertNull(vm.state.value.preview)
            assertEquals(listOf<CameraResult>(photo), received)
            job.cancel()
        }

    // ── Default: hold for preview, emit on Submit ──────────────

    @Test
    fun `default mode holds the capture for preview without emitting`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))

            assertEquals(photo, vm.state.value.preview)
            assertTrue(received.isEmpty())
            job.cancel()
        }

    @Test
    fun `submit emits the previewed result`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)

            assertEquals(listOf<CameraResult>(photo), received)
            job.cancel()
        }

    @Test
    fun `retake returns to capture and emits nothing`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Retake)

            assertNull(vm.state.value.preview)
            assertTrue(received.isEmpty())
            job.cancel()
        }

    // ── Double-tap guard ───────────────────────────────────────

    @Test
    fun `double submit emits exactly once`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)
            vm.dispatch(CameraIntent.Submit)

            assertEquals(1, received.size)
            job.cancel()
        }

    @Test
    fun `submit after retake is a no-op`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Retake)  // resolves the preview
            vm.dispatch(CameraIntent.Submit)  // should be ignored

            assertTrue(received.isEmpty())
            assertNull(vm.state.value.preview)
            job.cancel()
        }

    // ── Non-success results never enter preview ────────────────

    @Test
    fun `error result stays on capture - no preview - no emit`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(
                CameraIntent.CaptureCompleted(
                    CameraResult.Error(CameraErrorCode.INTERNAL_ERROR, "boom"),
                ),
            )

            assertNull(vm.state.value.preview)
            assertTrue(received.isEmpty())
            job.cancel()
        }

    // ── S1: abandon-during-preview reclaims temp ───────────────

    @Test
    fun `dispose after submit does not re-resolve - host owns the file`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)          // resolves + emits
            vm.dispatch(CameraIntent.PreviewDisposed) // teardown — must be a no-op, not delete

            assertEquals(1, received.size) // submit emitted exactly once
            job.cancel()
        }

    @Test
    fun `dispose after retake is a no-op`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Retake)          // resolves (deletes temp)
            vm.dispatch(CameraIntent.PreviewDisposed) // must not double-act

            assertTrue(received.isEmpty())
            assertNull(vm.state.value.preview)
            job.cancel()
        }

    @Test
    fun `submit after dispose is a no-op - abandon won the race`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.PreviewDisposed) // abandoned → reclaims, resolves
            vm.dispatch(CameraIntent.Submit)          // too late — must be ignored

            assertTrue(received.isEmpty())
            job.cancel()
        }

    @Test
    fun `cancelled result dismisses`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Default())
            val dismissed = mutableListOf<Unit>()
            val job = backgroundScope.launch {
                vm.effects.collect { if (it is CameraEffect.Dismiss) dismissed.add(Unit) }
            }

            vm.dispatch(CameraIntent.CaptureCompleted(CameraResult.Cancelled))

            assertEquals(1, dismissed.size)
            assertNull(vm.state.value.preview)
            job.cancel()
        }

    // ── Gallery save (config-gated, module-owned) ──────────────

    @Test
    fun `submit publishes to gallery when saveToGallery is set`() =
        runTest(dispatcher) {
            val persister = FakeMediaPersister()
            val vm = viewModel(PreviewMode.Default(), mediaPersister = persister)
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.ConfigChanged(CameraConfig(saveToGallery = true)))
            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)

            assertEquals(listOf<CapturedMedia>(photo), persister.saved)
            assertEquals(listOf<CameraResult>(photo), received)
            job.cancel()
        }

    @Test
    fun `submit does not publish when saveToGallery is off`() =
        runTest(dispatcher) {
            val persister = FakeMediaPersister()
            val vm = viewModel(PreviewMode.Default(), mediaPersister = persister)
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.ConfigChanged(CameraConfig(saveToGallery = false)))
            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)

            assertTrue(persister.saved.isEmpty())
            assertEquals(listOf<CameraResult>(photo), received)
            job.cancel()
        }

    @Test
    fun `disabled mode publishes on capture when saveToGallery is set`() =
        runTest(dispatcher) {
            val persister = FakeMediaPersister()
            val vm = viewModel(PreviewMode.Disabled, mediaPersister = persister)
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.ConfigChanged(CameraConfig(saveToGallery = true)))
            vm.dispatch(CameraIntent.CaptureCompleted(photo))

            assertEquals(listOf<CapturedMedia>(photo), persister.saved)
            assertEquals(listOf<CameraResult>(photo), received)
            job.cancel()
        }

    @Test
    fun `capture is still delivered and the failure reported when gallery save throws`() =
        runTest(dispatcher) {
            val persister = FakeMediaPersister(failWith = RuntimeException("mediastore down"))
            val reporter = FakeCrashReporter()
            val vm = viewModel(
                PreviewMode.Default(),
                mediaPersister = persister,
                crashReporter = reporter,
            )
            val (received, job) = collectResults(vm)

            vm.dispatch(CameraIntent.ConfigChanged(CameraConfig(saveToGallery = true)))
            vm.dispatch(CameraIntent.CaptureCompleted(photo))
            vm.dispatch(CameraIntent.Submit)

            assertEquals(listOf<CameraResult>(photo), received) // delivered despite the failure
            assertEquals(1, reporter.reported.size)             // reported, not swallowed
            job.cancel()
        }

    // ── Watchdog / idempotency guards ──────────────────────────

    @Test
    fun `late success after a capture timeout is dropped`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Disabled)
            val (received, job) = collectResults(vm)
            vm.dispatch(CameraIntent.Start)          // permission GRANTED → Initializing
            vm.dispatch(CameraIntent.CameraReady)    // → Ready
            vm.dispatch(CameraIntent.ShutterPressed) // photo → Capturing
            assertEquals(CameraPhase.Capturing, vm.state.value.phase)

            vm.dispatch(CameraIntent.CaptureTimeout)             // watchdog → Error, phase Ready
            vm.dispatch(CameraIntent.CaptureCompleted(photo))    // real event lands late — dropped

            assertTrue(received.isEmpty())
            job.cancel()
        }

    @Test
    fun `shutter arms photo capture once and emits a single command`() =
        runTest(dispatcher) {
            val vm = viewModel(PreviewMode.Disabled)
            val commands = mutableListOf<CameraCommand>()
            val job = backgroundScope.launch { vm.commands.collect { commands.add(it) } }
            vm.dispatch(CameraIntent.Start)
            vm.dispatch(CameraIntent.CameraReady) // → Ready

            vm.dispatch(CameraIntent.ShutterPressed) // Ready → Capturing, arms once
            vm.dispatch(CameraIntent.ShutterPressed) // already Capturing → no-op

            assertEquals(CameraPhase.Capturing, vm.state.value.phase)
            assertEquals(listOf<CameraCommand>(CameraCommand.CapturePhoto), commands)
            job.cancel()
        }
}
