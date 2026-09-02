package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.camera.fakes.FakeCrashReporter
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.core.camera.internal.platformFileOps
import com.snabbit.runner.shared.core.camera.internal.toCameraResultOrNull

import com.kashif.cameraK.result.ImageCaptureResult
import com.kashif.cameraK.state.CameraKEvent
import com.kashif.cameraK.video.VideoCaptureResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Tests the CameraK event → [CameraResult] mapping extracted from the
 * composable (A1 in the review). This logic was previously untestable
 * because it lived inside a `LaunchedEffect`.
 *
 * The mapper is `suspend` (it runs [compressImageToFit] on the captured
 * file); fixtures here are all within the size cap, so compression is a
 * no-op pass-through and never touches platform image APIs.
 */
class CameraKResultMapperTest {

    // Real platform file ops (the Android actual under testDebugUnitTest) so
    // writeTempFile / fileSize hit the disk exactly as before; Dispatchers.Unconfined
    // runs the seam's withContext inline within runTest.
    private val fileOps = platformFileOps(FakeCrashReporter(), TestAppDispatchers(Dispatchers.Unconfined))

    @Test
    fun `SuccessWithFile maps to Photo with the same path`() = runTest {
        val event = CameraKEvent.ImageCaptured(
            ImageCaptureResult.SuccessWithFile("/tmp/shot.jpg"),
        )
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Photo>(result)
        assertEquals("/tmp/shot.jpg", result.filePath)
        assertTrue(result.token.isNotBlank())
    }

    @Test
    fun `Success byte array writes a temp file and maps to Photo`() = runTest {
        val bytes = ByteArray(1024) { 1 }
        val event = CameraKEvent.ImageCaptured(ImageCaptureResult.Success(bytes))
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Photo>(result)
        assertTrue(result.filePath.isNotBlank())
        assertEquals(1024L, result.sizeBytes)
        // The temp file should actually exist on disk.
        assertEquals(1024L, fileOps.fileSize(result.filePath))
        fileOps.deleteFile(result.filePath) // cleanup
    }

    @Test
    fun `capture-level Error maps to Error result`() = runTest {
        val event = CameraKEvent.ImageCaptured(
            ImageCaptureResult.Error(RuntimeException("sensor busy")),
        )
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Error>(result)
        assertEquals(CameraErrorCode.INTERNAL_ERROR, result.code)
        assertEquals("sensor busy", result.message)
    }

    @Test
    fun `CaptureFailed event maps to Error result`() = runTest {
        val event = CameraKEvent.CaptureFailed(RuntimeException("boom"))
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Error>(result)
        assertEquals(CameraErrorCode.INTERNAL_ERROR, result.code)
    }

    @Test
    fun `RecordingStopped success maps to Video`() = runTest {
        val event = CameraKEvent.RecordingStopped(
            VideoCaptureResult.Success("/tmp/clip.mp4", durationMs = 5_000L),
        )
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Video>(result)
        assertEquals("/tmp/clip.mp4", result.filePath)
        assertEquals(5_000L, result.durationMs)
        assertTrue(result.token.isNotBlank())
    }

    @Test
    fun `RecordingMaxDurationReached maps to Video`() = runTest {
        val event = CameraKEvent.RecordingMaxDurationReached("/tmp/clip.mp4", durationMs = 30_000L)
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Video>(result)
        assertEquals(30_000L, result.durationMs)
    }

    @Test
    fun `RecordingStopped error maps to Error result`() = runTest {
        val event = CameraKEvent.RecordingStopped(
            VideoCaptureResult.Error(RuntimeException("disk full")),
        )
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Error>(result)
        assertEquals(CameraErrorCode.INTERNAL_ERROR, result.code)
    }

    @Test
    fun `RecordingFailed event maps to Error result`() = runTest {
        val event = CameraKEvent.RecordingFailed(RuntimeException("boom"))
        val result = event.toCameraResultOrNull(fileOps)

        assertIs<CameraResult.Error>(result)
        assertEquals(CameraErrorCode.INTERNAL_ERROR, result.code)
    }

    @Test
    fun `non-capture events map to null`() = runTest {
        assertNull(CameraKEvent.None.toCameraResultOrNull(fileOps))
        assertNull(CameraKEvent.RecordingStarted("/tmp/v.mp4").toCameraResultOrNull(fileOps))
    }
}
