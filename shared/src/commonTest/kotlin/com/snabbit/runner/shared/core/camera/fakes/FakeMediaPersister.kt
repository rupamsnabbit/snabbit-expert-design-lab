package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.camera.CapturedMedia
import com.snabbit.runner.shared.core.camera.MediaPersister

/**
 * Records gallery-save calls for assertions. Set [failWith] to exercise the
 * failure path (the ViewModel must still deliver the capture and report, not
 * swallow, the error).
 */
internal class FakeMediaPersister(
    var failWith: Throwable? = null,
    var returnUri: String? = "content://fake/media/1",
) : MediaPersister {
    val saved = mutableListOf<CapturedMedia>()

    override suspend fun saveToGallery(media: CapturedMedia): String? {
        saved.add(media)
        failWith?.let { throw it }
        return returnUri
    }
}
