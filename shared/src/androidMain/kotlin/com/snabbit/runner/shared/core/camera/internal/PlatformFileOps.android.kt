package com.snabbit.runner.shared.core.camera.internal

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

internal actual fun platformFileOps(
    crashReporter: CrashReporter,
    dispatchers: AppDispatchers,
): PlatformFileOps = AndroidPlatformFileOps(crashReporter, dispatchers)

/**
 * Real Android [PlatformFileOps]: `java.io` file I/O plus `BitmapFactory` /
 * `ImageDecoder` decoding. Swallowed decode/EXIF/compress/delete failures are
 * recorded via [crashReporter]; heavy work is threaded onto [dispatchers].
 */
internal class AndroidPlatformFileOps(
    private val crashReporter: CrashReporter,
    private val dispatchers: AppDispatchers,
) : PlatformFileOps {

    override fun fileSize(path: String): Long {
        val file = File(path)
        return if (file.exists()) file.length() else 0L
    }

    override suspend fun writeTempFile(bytes: ByteArray, prefix: String, suffix: String): String =
        withContext(dispatchers.io) {
            val tempFile = File.createTempFile(prefix, suffix)
            tempFile.writeBytes(bytes)
            tempFile.absolutePath
        }

    override suspend fun deleteFile(path: String): Unit = withContext(dispatchers.io) {
        try {
            val file = File(path)
            if (file.exists()) file.delete()
        } catch (e: Throwable) {
            // Best-effort cleanup — record instead of swallowing so a leaked
            // temp (undeleted private capture) leaves a diagnostic trail.
            crashReporter.report(e, mapOf("op" to "deleteFile"))
        }
    }

    override suspend fun loadDownsampledBitmap(
        path: String,
        reqWidthPx: Int,
        reqHeightPx: Int,
        mirrorHorizontally: Boolean,
    ): ImageBitmap? = withContext(dispatchers.default) {
        val file = File(path)
        if (!file.exists()) return@withContext null
        try {
            val decoded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // ImageDecoder applies EXIF orientation (rotation) like the system gallery.
                decodeWithImageDecoder(file, reqWidthPx, reqHeightPx)
            } else {
                decodeWithBitmapFactory(path, reqWidthPx, reqHeightPx)
            } ?: return@withContext null

            // Front-camera un-mirror: applied to the downsampled bitmap (cheap, no OOM).
            val oriented = if (mirrorHorizontally) decoded.flippedHorizontally() else decoded
            oriented.asImageBitmap()
        } catch (e: Throwable) {
            // Undecodable file → the preview shows the error state; record why.
            crashReporter.report(e, mapOf("op" to "loadDownsampledBitmap"))
            null
        }
    }

    override suspend fun compressImageToFit(path: String, maxBytes: Long): String {
        val file = File(path)
        // Common case: already within the cap → no decode, full quality preserved.
        if (!file.exists() || file.length() <= maxBytes) return path

        return withContext(dispatchers.default) {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@withContext path

            // Clamp the DECODE so the long edge is ≤ MAX_ENCODE_DIMEN — we never
            // inflate the full-res bitmap on a budget device just to re-encode it.
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sampleSizeForMaxDimen(bounds.outWidth, bounds.outHeight, MAX_ENCODE_DIMEN)
            }
            var bitmap = (BitmapFactory.decodeFile(path, opts) ?: return@withContext path)
                .let { applyExifOrientation(path, it) }

            // Recycle the working bitmap on EVERY exit path (incl. a compress/scale
            // OOM caught below) — releasing native pixels exactly when memory is scarce.
            try {
                // Step 1: drop JPEG quality. Step 2: if still too big, scale down and retry.
                var scaleAttempts = 0
                while (true) {
                    var quality = START_QUALITY
                    while (quality >= MIN_QUALITY) {
                        val bytes = ByteArrayOutputStream().use { out ->
                            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                            out.toByteArray()
                        }
                        if (bytes.size <= maxBytes) {
                            return@withContext writeTempFileBlocking(bytes, "capture_fit_", ".jpg")
                        }
                        quality -= QUALITY_STEP
                    }
                    if (scaleAttempts >= MAX_SCALE_ATTEMPTS) break
                    scaleAttempts++
                    val scaled = Bitmap.createScaledBitmap(
                        bitmap,
                        (bitmap.width * SCALE_FACTOR).toInt().coerceAtLeast(1),
                        (bitmap.height * SCALE_FACTOR).toInt().coerceAtLeast(1),
                        true,
                    )
                    if (scaled !== bitmap) bitmap.recycle()
                    bitmap = scaled
                }

                // Couldn't reach the cap — return the smallest we produced.
                val bytes = ByteArrayOutputStream().use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, MIN_QUALITY, out)
                    out.toByteArray()
                }
                writeTempFileBlocking(bytes, "capture_fit_", ".jpg")
            } catch (e: Throwable) {
                // Best-effort — record, then fall back to the original (the preview
                // gate still applies).
                crashReporter.report(e, mapOf("op" to "compressImageToFit"))
                path
            } finally {
                if (!bitmap.isRecycled) bitmap.recycle()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun decodeWithImageDecoder(file: File, reqWidthPx: Int, reqHeightPx: Int): Bitmap {
        val source = ImageDecoder.createSource(file)
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.setTargetSampleSize(
                calculateInSampleSize(
                    info.size.width,
                    info.size.height,
                    reqWidthPx.coerceAtLeast(1),
                    reqHeightPx.coerceAtLeast(1),
                ),
            )
            // Software allocation so the bitmap is safe to flip/wrap across all paths.
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
    }

    private fun decodeWithBitmapFactory(path: String, reqWidthPx: Int, reqHeightPx: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val opts = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(
                bounds.outWidth,
                bounds.outHeight,
                reqWidthPx.coerceAtLeast(1),
                reqHeightPx.coerceAtLeast(1),
            )
        }
        val decoded = BitmapFactory.decodeFile(path, opts) ?: return null
        // BitmapFactory ignores EXIF — apply the orientation tag ourselves.
        return applyExifOrientation(path, decoded)
    }

    /**
     * Rotates/flips [bitmap] to match the JPEG's EXIF orientation tag (rotation +
     * mirror variants). Returns [bitmap] unchanged for NORMAL/UNDEFINED, and — on a
     * failed EXIF read — records via [crashReporter] and returns [bitmap] unrotated.
     */
    private fun applyExifOrientation(path: String, bitmap: Bitmap): Bitmap {
        return try {
            val orientation = ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> {
                    matrix.postRotate(90f); matrix.postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_TRANSVERSE -> {
                    matrix.postRotate(270f); matrix.postScale(-1f, 1f)
                }
                else -> return bitmap
            }
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                .also { rotated -> if (rotated !== bitmap) bitmap.recycle() }
        } catch (e: Throwable) {
            crashReporter.report(e, mapOf("op" to "applyExifOrientation"))
            bitmap
        }
    }

    /** Blocking temp-file write, already inside a [withContext] on this seam's dispatcher. */
    private fun writeTempFileBlocking(bytes: ByteArray, prefix: String, suffix: String): String {
        val tempFile = File.createTempFile(prefix, suffix)
        tempFile.writeBytes(bytes)
        return tempFile.absolutePath
    }
}

/** Flips a bitmap left↔right. Recycles the source when a new bitmap is produced. */
private fun Bitmap.flippedHorizontally(): Bitmap {
    val matrix = Matrix().apply { postScale(-1f, 1f) }
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
        .also { flipped -> if (flipped !== this) recycle() }
}

/**
 * Largest power-of-two sample size that keeps both dimensions ≥ requested, then
 * clamped so the decoded long edge never exceeds [MAX_ENCODE_DIMEN].
 *
 * The second clamp is the memory safety-net: the "keep both ≥ requested" rule
 * leaves `sampleSize == 1` whenever the image and the requested box have
 * mismatched aspect ratios (e.g. a landscape capture in a portrait preview),
 * which would otherwise decode the FULL-resolution bitmap (~48 MB ARGB_8888) and
 * OOM budget devices. The clamp bounds the decode regardless of caller aspect.
 */
private fun calculateInSampleSize(
    width: Int,
    height: Int,
    reqWidth: Int,
    reqHeight: Int,
): Int {
    var sampleSize = 1
    if (height > reqHeight || width > reqWidth) {
        val halfH = height / 2
        val halfW = width / 2
        while ((halfH / sampleSize) >= reqHeight && (halfW / sampleSize) >= reqWidth) {
            sampleSize *= 2
        }
    }
    while (maxOf(width, height) / sampleSize > MAX_ENCODE_DIMEN) {
        sampleSize *= 2
    }
    return sampleSize
}

// ── Compress-to-cap (oversize capture) ───────────────────────────────────

private const val MAX_ENCODE_DIMEN = 2048 // cap working resolution (budget-safe)
private const val START_QUALITY = 90
private const val MIN_QUALITY = 40
private const val QUALITY_STEP = 10
private const val MAX_SCALE_ATTEMPTS = 3
private const val SCALE_FACTOR = 0.75f

/**
 * Smallest power-of-two sample size that brings the LONGER edge to
 * ≤ [maxDimen]. Unlike [calculateInSampleSize] (which keeps dimensions
 * *above* a requested preview size), this clamps DOWN, so an oversize
 * capture's decode is genuinely memory-bounded (e.g. 4000×3000 → sample 2 →
 * 2000×1500 ≈ 12 MB, not the full ≈ 48 MB).
 */
private fun sampleSizeForMaxDimen(width: Int, height: Int, maxDimen: Int): Int {
    var sampleSize = 1
    while (maxOf(width, height) / sampleSize > maxDimen) {
        sampleSize *= 2
    }
    return sampleSize
}
