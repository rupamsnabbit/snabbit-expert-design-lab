package com.snabbit.runner.shared.core.camera.internal

import androidx.compose.ui.graphics.ImageBitmap
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter

/**
 * Minimal platform file operations needed by the camera module.
 *
 * An **injected seam** (constructed by [platformFileOps], bound in
 * `cameraKoinModule`) rather than loose top-level functions, so it can:
 * - carry a [CrashReporter] — the decode / EXIF / compress / delete failures that
 *   used to be swallowed silently are now recorded; and
 * - carry [AppDispatchers] — the heavy I/O and image work runs on injected
 *   dispatchers (consistent and test-substitutable) instead of a hardcoded
 *   `Dispatchers.Default`.
 *
 * Keeps [CameraScreen], [MediaPreviewScreen], and [toCameraResultOrNull] free of
 * platform imports while still doing real file I/O / decoding. Consumers get the
 * instance via `koinInject`/constructor injection and never construct it directly.
 */
interface PlatformFileOps {

    /** Returns the file size in bytes, or 0 if the file doesn't exist. */
    fun fileSize(path: String): Long

    /**
     * Writes [bytes] to a temporary file and returns the absolute path. Runs on
     * [AppDispatchers.io]. The file is created in the platform's temp/cache directory.
     */
    suspend fun writeTempFile(bytes: ByteArray, prefix: String, suffix: String): String

    /**
     * Deletes the file at [path]. Best-effort — a missing file is a no-op and any
     * failure is recorded via [CrashReporter], never thrown. Runs on [AppDispatchers.io].
     */
    suspend fun deleteFile(path: String)

    /**
     * Decodes the image at [path], downsampled to at most [reqWidthPx] ×
     * [reqHeightPx], to avoid OOM on budget devices (a full 12MP JPEG decodes
     * to ~48MB ARGB_8888). Returns `null` if the file is missing or undecodable
     * (the caller shows the error state) — a decode failure is recorded via
     * [CrashReporter] rather than swallowed silently. Runs on [AppDispatchers.default].
     *
     * @param mirrorHorizontally when `true`, the decoded bitmap is flipped
     *   left↔right. Front-camera sensors deliver a mirrored image with no EXIF
     *   flag to signal it; flipping the (small, already-downsampled) preview
     *   bitmap un-mirrors it so the preview matches a natural photo.
     */
    suspend fun loadDownsampledBitmap(
        path: String,
        reqWidthPx: Int,
        reqHeightPx: Int,
        mirrorHorizontally: Boolean,
    ): ImageBitmap?

    /**
     * Returns a path to a JPEG no larger than [maxBytes].
     *
     * If the file at [path] is already within the cap (the common case) it is
     * returned **unchanged with no decode** — so normal captures keep full
     * resolution and this is cheap. Only an oversize capture is re-encoded
     * (lower JPEG quality, then downscaled if still too big) into a **new** temp
     * file whose path is returned. Best-effort: a decode/encode failure is
     * recorded via [CrashReporter] and [path] is returned unchanged. The heavy
     * work runs on [AppDispatchers.default].
     */
    suspend fun compressImageToFit(path: String, maxBytes: Long): String
}

/**
 * Platform factory for [PlatformFileOps]. Each platform wires the real impl
 * (Android) or the iOS-launch stub, carrying the injected [crashReporter] and
 * [dispatchers].
 */
internal expect fun platformFileOps(
    crashReporter: CrashReporter,
    dispatchers: AppDispatchers,
): PlatformFileOps
