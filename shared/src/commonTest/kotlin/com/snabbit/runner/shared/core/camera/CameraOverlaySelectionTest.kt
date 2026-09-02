package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.camera.ui.defaultOverlay
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * Verifies the overlay-guide selection ([defaultOverlay]) — which guide (if any)
 * is chosen for a given [CameraConfig]. Asserts only presence/absence (the
 * composable itself isn't rendered), so it runs as a plain unit test.
 */
class CameraOverlaySelectionTest {

    @Test
    fun `video never shows a guide`() {
        assertNull(defaultOverlay(CameraConfig(mode = CaptureMode.VIDEO, overlay = CameraOverlay.FACE)))
        assertNull(defaultOverlay(CameraConfig(mode = CaptureMode.VIDEO, overlay = CameraOverlay.OVAL)))
    }

    @Test
    fun `NONE disables the overlay`() {
        assertNull(defaultOverlay(CameraConfig(mode = CaptureMode.PHOTO, overlay = CameraOverlay.NONE)))
    }

    @Test
    fun `FACE shows on the front camera photo only`() {
        assertNotNull(
            defaultOverlay(
                CameraConfig(lens = CameraLens.FRONT, mode = CaptureMode.PHOTO, overlay = CameraOverlay.FACE),
            ),
        )
        assertNull(
            defaultOverlay(
                CameraConfig(lens = CameraLens.BACK, mode = CaptureMode.PHOTO, overlay = CameraOverlay.FACE),
            ),
        )
    }

    @Test
    fun `OVAL shows on photo for either lens`() {
        assertNotNull(
            defaultOverlay(
                CameraConfig(lens = CameraLens.FRONT, mode = CaptureMode.PHOTO, overlay = CameraOverlay.OVAL),
            ),
        )
        assertNotNull(
            defaultOverlay(
                CameraConfig(lens = CameraLens.BACK, mode = CaptureMode.PHOTO, overlay = CameraOverlay.OVAL),
            ),
        )
    }

    @Test
    fun `default config keeps the front-selfie face guide`() {
        // Defaults: overlay = FACE, lens = FRONT, mode = PHOTO → guide present.
        assertNotNull(defaultOverlay(CameraConfig()))
        // Back camera with defaults → no guide (unchanged from prior behavior).
        assertNull(defaultOverlay(CameraConfig(lens = CameraLens.BACK)))
    }
}
