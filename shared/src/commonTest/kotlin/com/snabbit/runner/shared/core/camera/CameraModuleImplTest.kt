package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.camera.fakes.FakeCameraProvider
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.core.camera.internal.CameraModuleImpl

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class CameraModuleImplTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var fakeProvider: FakeCameraProvider
    private lateinit var fakeLogger: FakeLogger
    private lateinit var module: CameraModuleImpl

    @BeforeTest
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        fakeProvider = FakeCameraProvider()
        fakeLogger = FakeLogger()
        module = CameraModuleImpl(
            provider = fakeProvider,
            logger = fakeLogger,
            dispatchers = TestAppDispatchers(testDispatcher),
        )
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Happy path ─────────────────────────────────────────────

    @Test
    fun `capture photo returns Photo result`() = runTest(testDispatcher) {
        val expected = CameraResult.Photo(
            filePath = "/tmp/captures/123.jpg",
            token = "123",
            sizeBytes = 2_000_000L,
        )
        fakeProvider.nextResult = expected

        val result = module.capture(CameraConfig(mode = CaptureMode.PHOTO))

        assertIs<CameraResult.Photo>(result)
        assertEquals("123", result.token)
        assertEquals(1, fakeProvider.photoCaptureCount)
        assertEquals(0, fakeProvider.videoCaptureCount)
    }

    @Test
    fun `capture video routes to captureVideo`() = runTest(testDispatcher) {
        val expected = CameraResult.Video(
            filePath = "/tmp/captures/456.mp4",
            token = "456",
            sizeBytes = 10_000_000L,
            durationMs = 5_000L,
        )
        fakeProvider.nextResult = expected

        val result = module.capture(CameraConfig(mode = CaptureMode.VIDEO))

        assertIs<CameraResult.Video>(result)
        assertEquals("456", result.token)
        assertEquals(0, fakeProvider.photoCaptureCount)
        assertEquals(1, fakeProvider.videoCaptureCount)
    }

    // ── User cancellation ──────────────────────────────────────

    @Test
    fun `capture returns Cancelled when user cancels`() = runTest(testDispatcher) {
        fakeProvider.nextResult = CameraResult.Cancelled

        val result = module.capture()

        assertIs<CameraResult.Cancelled>(result)
        assertFalse(module.isCapturing)
    }

    // ── Error from provider ────────────────────────────────────

    @Test
    fun `capture returns Error when provider fails`() = runTest(testDispatcher) {
        fakeProvider.nextResult = CameraResult.Error(
            code = CameraErrorCode.CAMERA_NOT_READY,
            message = "Camera not initialized",
        )

        val result = module.capture()

        assertIs<CameraResult.Error>(result)
        assertEquals(CameraErrorCode.CAMERA_NOT_READY, result.code)
    }

    // ── Reentrancy guard ───────────────────────────────────────

    @Test
    fun `isCapturing is false after capture completes`() = runTest(testDispatcher) {
        fakeProvider.nextResult = CameraResult.Photo("/path", "t", 100)

        module.capture()

        assertFalse(module.isCapturing)
    }

    // ── Config passthrough ─────────────────────────────────────

    @Test
    fun `config is passed through to provider`() = runTest(testDispatcher) {
        fakeProvider.nextResult = CameraResult.Cancelled
        val config = CameraConfig(
            lens = CameraLens.BACK,
            mode = CaptureMode.PHOTO,
            quality = CaptureQuality.MEDIUM,
        )

        module.capture(config)

        assertEquals(CameraLens.BACK, fakeProvider.lastConfig?.lens)
        assertEquals(CaptureQuality.MEDIUM, fakeProvider.lastConfig?.quality)
    }

    // ── Cancel ─────────────────────────────────────────────────

    @Test
    fun `cancel when not capturing is no-op`() {
        module.cancel()
        assertEquals(0, fakeProvider.cancelCount)
    }

    // ── Default config ─────────────────────────────────────────

    @Test
    fun `default config is front camera photo high quality`() = runTest(testDispatcher) {
        fakeProvider.nextResult = CameraResult.Cancelled

        module.capture()

        assertEquals(CameraLens.FRONT, fakeProvider.lastConfig?.lens)
        assertEquals(CaptureMode.PHOTO, fakeProvider.lastConfig?.mode)
        assertEquals(CaptureQuality.HIGH, fakeProvider.lastConfig?.quality)
    }

    // ── Reentrancy: overlapping capture ────────────────────────

    @Test
    fun `second capture while one is in progress returns CAPTURE_IN_PROGRESS`() =
        runTest(testDispatcher) {
            val gate = CompletableDeferred<Unit>()
            fakeProvider.captureGate = gate
            fakeProvider.nextResult = CameraResult.Photo("/p", "t", 1)

            // First capture launches and suspends on the gate, holding the guard.
            val first = launch { module.capture(CameraConfig(mode = CaptureMode.PHOTO)) }
            runCurrent()
            assertTrue(module.isCapturing)

            // Second capture while the first is in flight is rejected.
            val second = module.capture(CameraConfig(mode = CaptureMode.PHOTO))
            assertIs<CameraResult.Error>(second)
            assertEquals(CameraErrorCode.CAPTURE_IN_PROGRESS, second.code)
            assertEquals(1, fakeProvider.photoCaptureCount) // second never reached the provider

            gate.complete(Unit)
            first.join()
            assertFalse(module.isCapturing)
        }
}
