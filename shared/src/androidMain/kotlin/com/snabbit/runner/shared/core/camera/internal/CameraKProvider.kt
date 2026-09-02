package com.snabbit.runner.shared.core.camera.internal

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraLens
import com.snabbit.runner.shared.core.camera.CameraProvider
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CaptureQuality

import com.kashif.cameraK.enums.CameraLens as CKLens
import com.kashif.cameraK.enums.Directory
import com.kashif.cameraK.enums.FlashMode as CKFlash
import com.kashif.cameraK.enums.ImageFormat
import com.kashif.cameraK.enums.QualityPrioritization
import com.kashif.cameraK.state.CameraConfiguration
import com.kashif.cameraK.state.CameraKStateHolder
import com.kashif.cameraK.video.VideoConfiguration
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * CameraK-specific [CameraProvider] implementation for Android.
 *
 * **This is the ONLY file that imports CameraK types.** Everything above
 * this (CameraModule, CameraModuleImpl, handlers, UI) is library-agnostic.
 *
 * ## Compose path (current — CameraScreen)
 *
 * [CameraScreen] captures directly via `CameraKStateHolder.captureImage()`
 * obtained through the `setupPlugins` callback. It collects events in a
 * `LaunchedEffect` and forwards results to `CameraViewModel.onCaptureCompleted`.
 * The `capturePhoto()` / `captureVideo()` methods below are **NOT called**
 * in this path.
 *
 * ## Bifrost/headless path (Phase 4 — future)
 *
 * The methods below (`capturePhoto`, `captureVideo`, `bindStateHolder`) are
 * reserved for the bifrost RPC handler, which will call
 * `CameraModule.capture` → `CameraModuleImpl` → this provider. The
 * `stateHolder` must be bound before capture can proceed. This path will
 * be wired in Phase 4 when bifrost handlers are built.
 *
 * The CameraK→domain mapping is delegated to [toCameraResultOrNull] (the single,
 * unit-tested mapper) rather than re-implemented here.
 */
internal class CameraKProvider(
    private val logger: Logger,
    private val fileOps: PlatformFileOps,
) : CameraProvider {

    private val tag = "CameraKProvider"

    @Volatile
    private var _isCapturing = false
    override val isCapturing: Boolean get() = _isCapturing

    /**
     * The active CameraK state holder, set by the Compose UI layer.
     * Null until [CameraScreen] binds it.
     */
    private var stateHolder: CameraKStateHolder? = null

    /** Pending capture result — completed when CameraK fires the event. */
    private var pendingCapture: CompletableDeferred<CameraResult>? = null

    /**
     * Called by the Compose UI layer to provide the active [CameraKStateHolder].
     * Must be called after `rememberCameraKState()` produces a Ready state.
     */
    fun bindStateHolder(holder: CameraKStateHolder) {
        stateHolder = holder
        logger.d(tag, "StateHolder bound")
    }

    /** Called when the camera screen is disposed. */
    fun unbindStateHolder() {
        stateHolder = null
        logger.d(tag, "StateHolder unbound")
    }

    override suspend fun capturePhoto(config: CameraConfig): CameraResult =
        runCapture("capturePhoto") { holder -> holder.captureImage() }

    override suspend fun captureVideo(config: CameraConfig): CameraResult =
        runCapture("captureVideo") { holder ->
            holder.startRecording(
                VideoConfiguration(
                    enableAudio = config.enableAudio,
                    maxDurationMs = config.maxVideoDurationMs,
                ),
            )
        }

    /**
     * Shared capture driver: fires [trigger], then completes with the first CameraK
     * event that maps to a terminal [CameraResult] via [toCameraResultOrNull] — the
     * same mapping the Compose path uses, so there is one source of truth.
     */
    private suspend fun runCapture(
        op: String,
        trigger: (CameraKStateHolder) -> Unit,
    ): CameraResult {
        val holder = stateHolder
        if (holder == null) {
            logger.w(tag, "$op called but no StateHolder bound")
            return CameraResult.Error(
                code = CameraErrorCode.CAMERA_NOT_READY,
                message = "Camera not ready — open the camera screen first",
            )
        }

        _isCapturing = true
        val deferred = CompletableDeferred<CameraResult>()
        pendingCapture = deferred

        return try {
            coroutineScope {
                val eventJob = launch {
                    holder.events.collect { event ->
                        event.toCameraResultOrNull(fileOps)?.let { deferred.complete(it) }
                    }
                }
                trigger(holder)
                logger.d(tag, "$op fired, awaiting event...")
                val result = deferred.await()
                eventJob.cancel()
                result
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Throwable) {
            logger.e(tag, "$op failed", e)
            CameraResult.Error(
                code = CameraErrorCode.INTERNAL_ERROR,
                message = "Capture failed: ${e.message}",
            )
        } finally {
            _isCapturing = false
            pendingCapture = null
        }
    }

    override fun cancel() {
        logger.d(tag, "cancel requested")
        pendingCapture?.complete(CameraResult.Cancelled)
        _isCapturing = false
    }

    companion object {
        /**
         * Maps our [CameraConfig] to CameraK's [CameraConfiguration].
         * Called by the Compose UI layer when setting up the camera preview.
         */
        fun toCameraKConfig(config: CameraConfig): CameraConfiguration {
            return CameraConfiguration(
                cameraLens = when (config.lens) {
                    CameraLens.FRONT -> CKLens.FRONT
                    CameraLens.BACK -> CKLens.BACK
                },
                flashMode = CKFlash.OFF,
                imageFormat = ImageFormat.JPEG,
                qualityPrioritization = when (config.quality) {
                    CaptureQuality.LOW -> QualityPrioritization.SPEED
                    CaptureQuality.MEDIUM -> QualityPrioritization.BALANCED
                    CaptureQuality.HIGH -> QualityPrioritization.QUALITY
                },
                // App-private capture dir — never the public gallery (see the
                // CameraScreen mapper). Public publish is the MediaPersister's job.
                directory = Directory.DOCUMENTS,
                returnFilePath = true,
            )
        }
    }
}
