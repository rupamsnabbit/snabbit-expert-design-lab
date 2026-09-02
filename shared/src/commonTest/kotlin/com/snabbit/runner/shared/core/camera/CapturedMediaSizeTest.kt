package com.snabbit.runner.shared.core.camera

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Tests the size-cap rules used by the preview screen to block Submit on
 * over-cap media ([CapturedMedia.exceedsSizeCap] / [sizeCapBytes]).
 */
class CapturedMediaSizeTest {

    private val photoCap = CaptureRegistry.MAX_PHOTO_SIZE_BYTES // 10 MB
    private val videoCap = CaptureRegistry.MAX_VIDEO_SIZE_BYTES // 50 MB

    private fun photo(size: Long) = CameraResult.Photo("/p.jpg", "t", size)
    private fun video(size: Long) = CameraResult.Video("/v.mp4", "t", size, durationMs = 1000)

    @Test
    fun `photo at the cap is not over`() {
        assertFalse(photo(photoCap).exceedsSizeCap())
    }

    @Test
    fun `photo one byte over the cap is over`() {
        assertTrue(photo(photoCap + 1).exceedsSizeCap())
    }

    @Test
    fun `small photo is within cap`() {
        assertFalse(photo(2L * 1024 * 1024).exceedsSizeCap()) // 2 MB
    }

    @Test
    fun `video uses the larger 50MB cap`() {
        // 20 MB would be over the photo cap but is fine for video.
        assertFalse(video(20L * 1024 * 1024).exceedsSizeCap())
        assertTrue(video(videoCap + 1).exceedsSizeCap())
    }

    @Test
    fun `sizeCapBytes is media-type specific`() {
        assertEquals(photoCap, photo(1).sizeCapBytes())
        assertEquals(videoCap, video(1).sizeCapBytes())
    }
}
