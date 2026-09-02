package com.snabbit.runner.shared.core.camera.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.camera.CameraAnalyticsEmitter
import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraException
import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.CameraPermissionController
import com.snabbit.runner.shared.core.camera.CameraPermissionStatus
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CapturedMedia
import com.snabbit.runner.shared.core.camera.CaptureMode
import com.snabbit.runner.shared.core.camera.MediaPersister
import com.snabbit.runner.shared.core.camera.NoOpMediaPersister
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps

import kotlinx.atomicfu.atomic
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * ViewModel for the camera flow — full MVI.
 *
 * An [androidx.lifecycle.ViewModel] (Compose MP) resolved via `koinViewModel`;
 * all coroutines run on [viewModelScope]. Every input arrives as a
 * [CameraIntent] through the single [dispatch] funnel; outputs are:
 * - [state] — the render [CameraUiState] (capture-screen phase **plus** the
 *   capture↔preview navigation via [CameraUiState.preview]).
 * - [effects] — one-shot host signals ([CameraEffect.DeliverResult] /
 *   [CameraEffect.Dismiss]), collected at the [CameraFlow] level.
 * - [commands] — hardware actions ([CameraCommand]) the live capture surface
 *   runs against the CameraK holder.
 *
 * On a successful capture, [previewMode] decides whether the result is
 * emitted immediately ([PreviewMode.Disabled]) or held for preview.
 */
class CameraViewModel(
    private val cameraModule: CameraModule,
    private val analyticsTracker: AnalyticsTracker,
    /** Launch context ("go_live", "shift_login", …) tagged on every camera event. */
    private val analyticsSource: String,
    // Required (no fail-open default): production wires PermissionManagerCameraController;
    // tests inject a fake. AlwaysGrantedCameraPermissionController remains available for
    // hosts that genuinely pre-gate permission externally, but is never the silent default.
    private val permissions: CameraPermissionController,
    private val crashReporter: CrashReporter,
    // Injected file-ops seam: records previously-swallowed I/O failures via
    // CrashReporter and threads reclaim work on AppDispatchers (not Dispatchers.Default).
    private val platformFileOps: PlatformFileOps,
    val previewMode: PreviewMode = PreviewMode.Disabled,
    private val mediaPersister: MediaPersister = NoOpMediaPersister,
) : ViewModel() {
    /** Owns camera event names/props; fans to [analyticsTracker] tagged with source. */
    private val analytics = CameraAnalyticsEmitter(analyticsTracker, analyticsSource)

    private val _state = MutableStateFlow(CameraUiState())
    val state: StateFlow<CameraUiState> = _state.asStateFlow()

    private val _effects = Channel<CameraEffect>(Channel.BUFFERED)
    /** One-shot host signals — deliver a result or dismiss the flow. */
    val effects: Flow<CameraEffect> = _effects.receiveAsFlow()

    private val _commands = Channel<CameraCommand>(Channel.BUFFERED)
    /** Hardware actions the live capture surface runs against the CameraK holder. */
    val commands: Flow<CameraCommand> = _commands.receiveAsFlow()

    /** Runs the permission gate at most once per flow lifetime. */
    private val permissionFlowStarted = atomic(false)

    /** Guards [onRequestPermission] against double-taps launching concurrent requests. */
    private val permissionRequestInFlight = atomic(false)

    /**
     * Set when a capture/recording watchdog fires. Guards [onCaptureCompleted] from
     * delivering a late success (the real CameraK event can land after the timeout)
     * that the user was already told had failed. Cleared when a new capture arms.
     */
    private val captureTimedOut = atomic(false)

    /**
     * Guards Retake/Submit against double-taps while previewing. Reset to
     * `false` each time we hold a capture for preview; the first Retake or
     * Submit flips it to `true` and the rest become no-ops.
     */
    private val previewResolved = atomic(true)

    /** Whether preview will be shown after capture (vs. emit immediately). */
    val isPreviewEnabled: Boolean get() = previewMode != PreviewMode.Disabled

    /**
     * The single input funnel. Every UI action plus the lifecycle/watchdog hooks
     * send a [CameraIntent] here; this exhaustive `when` delegates to the private
     * handlers that own each state transition.
     */
    fun dispatch(intent: CameraIntent) {
        when (intent) {
            CameraIntent.Start -> onStart()
            CameraIntent.RequestPermission -> onRequestPermission()
            CameraIntent.OpenAppSettings -> onOpenAppSettings()
            CameraIntent.Resumed -> onResumed()
            CameraIntent.CameraReady -> onCameraReady()
            is CameraIntent.CameraError -> onCameraError(intent.message)
            CameraIntent.CameraInitTimeout -> onCameraInitTimeout()
            CameraIntent.CaptureTimeout -> onCaptureTimeout()
            CameraIntent.RecordingTimeout -> onRecordingTimeout()
            CameraIntent.ShutterPressed -> onShutterPressed()
            CameraIntent.RequestMicrophone -> onRequestMicrophone()
            is CameraIntent.CaptureCompleted -> onCaptureCompleted(intent.result)
            CameraIntent.Retake -> onRetake()
            CameraIntent.Submit -> onSubmit()
            CameraIntent.PreviewDisposed -> onPreviewDisposed()
            CameraIntent.CancelRequested -> onCancelRequested()
            is CameraIntent.ConfigChanged -> onConfigChanged(intent.config)
        }
    }

    // ── Permission gate ────────────────────────────────────────

    /**
     * Entry point for the flow. Runs the permission gate once: if granted,
     * proceeds to camera init; otherwise requests and routes to the
     * denied / permanently-denied state. Idempotent — safe to dispatch on every
     * (re)composition of the host.
     */
    private fun onStart() {
        if (!permissionFlowStarted.compareAndSet(expect = false, update = true)) return
        viewModelScope.launch { resolvePermission() }
    }

    /** User tapped "Allow" on the denied state — re-request. */
    private fun onRequestPermission() {
        if (!permissionRequestInFlight.compareAndSet(expect = false, update = true)) return
        _state.update { it.copy(phase = CameraPhase.CheckingPermission) }
        viewModelScope.launch {
            try {
                requestPermission()
            } finally {
                permissionRequestInFlight.value = false
            }
        }
    }

    /** User tapped "Open settings" on the permanently-denied state. */
    private fun onOpenAppSettings() {
        permissions.openAppSettings()
    }

    /**
     * Host lifecycle hook (Activity onResume). After returning from app
     * settings the user may have granted permission — re-check and proceed.
     */
    private fun onResumed() {
        if (_state.value.needsPermission) {
            viewModelScope.launch { resolvePermission() }
        }
    }

    private suspend fun resolvePermission() {
        // Bound the status check: a controller that throws or hangs must not wedge
        // the flow on the (watchdog-less) CheckingPermission spinner. status() shows
        // no dialog, so a timeout here can't cut short a user interaction.
        val status: CameraPermissionStatus? = try {
            withTimeoutOrNull(PERMISSION_CHECK_TIMEOUT_MS) { permissions.status() }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            reportPermissionError("status", e)
            null
        }
        when (status) {
            CameraPermissionStatus.GRANTED ->
                _state.update { it.copy(phase = CameraPhase.Initializing) }
            // Timed out / threw → surface the re-requestable denied state ("Allow")
            // rather than wedging on the CheckingPermission spinner.
            null ->
                _state.update { it.copy(phase = CameraPhase.PermissionDenied) }
            else -> requestPermission()
        }
    }

    private suspend fun requestPermission() {
        // A throwing controller (e.g. "can only request one permission set at a
        // time", Activity in a bad state) must not crash the flow — degrade to the
        // re-requestable denied state. No timeout: request() legitimately suspends
        // for as long as the OS permission dialog is up.
        val status = try {
            permissions.request()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            reportPermissionError("request", e)
            CameraPermissionStatus.DENIED
        }
        when (status) {
            CameraPermissionStatus.GRANTED ->
                _state.update { it.copy(phase = CameraPhase.Initializing) }
            CameraPermissionStatus.DENIED -> {
                analytics.permissionDenied("denied")
                _state.update { it.copy(phase = CameraPhase.PermissionDenied) }
            }
            CameraPermissionStatus.PERMANENTLY_DENIED -> {
                analytics.permissionDenied("permanently_denied")
                _state.update { it.copy(phase = CameraPhase.PermissionPermanentlyDenied) }
            }
        }
    }

    private fun reportPermissionError(op: String, e: Throwable) {
        reportError(
            code = CameraErrorCode.INTERNAL_ERROR,
            message = "Camera permission $op failed: ${e.message ?: "unknown error"}",
            cause = e,
        )
    }

    // ── Camera init ────────────────────────────────────────────

    /** Signal that the camera preview is ready for capture. */
    private fun onCameraReady() {
        _state.update { it.copy(phase = CameraPhase.Ready) }
    }

    /**
     * Watchdog hook: fire a timeout error **only if still capturing** (the
     * capture never produced an event). Re-checks current phase here so the
     * composable's delay can't act on a stale snapshot.
     */
    private fun onCaptureTimeout() {
        if (_state.value.phase !is CameraPhase.Capturing) return
        captureTimedOut.value = true
        onCaptureCompleted(
            CameraResult.Error(
                code = CameraErrorCode.INTERNAL_ERROR,
                message = "Capture timed out. Please try again.",
            ),
        )
    }

    /**
     * Recording watchdog hook: fire a timeout error **only if still recording**
     * (a wedged HAL never emitted a stop event). Re-checks the live phase so the
     * composable's delay can't act on a stale snapshot.
     */
    private fun onRecordingTimeout() {
        if (_state.value.phase !is CameraPhase.Recording) return
        captureTimedOut.value = true
        onCaptureCompleted(
            CameraResult.Error(
                code = CameraErrorCode.INTERNAL_ERROR,
                message = "Recording timed out. Please try again.",
            ),
        )
    }

    /**
     * Init watchdog hook: fire an error **only if still initializing** (the
     * camera never reached Ready). Re-checks the live phase so the composable's
     * delay can't act on a stale snapshot — a no-op once Ready/Capturing.
     */
    private fun onCameraInitTimeout() {
        if (_state.value.phase !is CameraPhase.Initializing) return
        onCameraError("Camera didn't start in time. Please try again.")
    }

    /** Signal that the camera failed to initialize. */
    private fun onCameraError(message: String) {
        _state.update { it.copy(phase = CameraPhase.Error(message)) }
        reportError(
            code = CameraErrorCode.CAMERA_NOT_READY,
            message = message,
            context = mapOf("lens" to _state.value.config.lens.name),
        )
    }

    // ── Shutter ────────────────────────────────────────────────

    /**
     * Shutter tapped. Decides the action from the live [CameraConfig.mode] +
     * [CameraPhase] and, **only when it actually arms**, emits the matching
     * [CameraCommand] for the capture surface to run against CameraK:
     * - PHOTO → arm Ready → Capturing, then [CameraCommand.CapturePhoto].
     * - VIDEO, not recording → mic-permission + arm Ready → Recording, then
     *   [CameraCommand.StartRecording]. Debounced via [CameraUiState.recordActionInFlight].
     * - VIDEO, recording → [CameraCommand.StopRecording] (the in-flight guard stays
     *   set until the recording actually ends — the video stop-tap fix).
     */
    private fun onShutterPressed() {
        val config = _state.value.config
        when (config.mode) {
            // armPhotoCapture arms exactly once (Ready → Capturing); emit the shutter
            // command only if it actually armed, so a same-frame double-tap can't
            // trigger a second captureImage().
            CaptureMode.PHOTO ->
                if (armPhotoCapture(config)) emit(CameraCommand.CapturePhoto)

            // Tap to start, tap again to stop. recordActionInFlight debounces the async
            // start (incl. the mic-permission suspension) and the stop (the phase stays
            // Recording until the event lands) so neither fires twice; the result
            // arrives via CaptureCompleted.
            CaptureMode.VIDEO -> {
                if (_state.value.recordActionInFlight) return
                _state.update { it.copy(recordActionInFlight = true) }
                if (_state.value.isRecording) {
                    // Stop tap. Cleared when the recording ends (onCaptureCompleted).
                    emit(CameraCommand.StopRecording)
                } else {
                    viewModelScope.launch {
                        try {
                            // Request the mic first if audio was asked for. CameraK adds
                            // the track only when granted, else records silently —
                            // capture is never blocked.
                            if (config.enableAudio) {
                                ensureMicrophonePermission()
                            }
                            if (armRecording(config)) {
                                _commands.send(CameraCommand.StartRecording(config))
                            }
                        } finally {
                            _state.update { it.copy(recordActionInFlight = false) }
                        }
                    }
                }
            }
        }
    }

    /**
     * Photo shutter: transitions Ready → Capturing + fires analytics. Idempotent —
     * only Ready → Capturing (a double-tap while the button-disable lags one frame
     * would otherwise double-fire). Returns whether it actually armed.
     */
    private fun armPhotoCapture(config: CameraConfig): Boolean {
        if (_state.value.phase != CameraPhase.Ready) return false
        captureTimedOut.value = false
        _state.update { it.copy(phase = CameraPhase.Capturing, config = config) }
        analytics.captureStarted(config)
        return true
    }

    /**
     * Video shutter (start): transitions Ready → Recording + fires analytics.
     * Idempotent — only Ready → Recording (guards a double-tap start). Returns
     * whether it actually armed.
     */
    private fun armRecording(config: CameraConfig): Boolean {
        if (_state.value.phase != CameraPhase.Ready) return false
        captureTimedOut.value = false
        _state.update { it.copy(phase = CameraPhase.Recording, config = config) }
        analytics.captureStarted(config)
        return true
    }

    /**
     * Requests microphone permission for an audio video capture and records the
     * result in [CameraUiState.micPermission] (drives the "audio off" banner).
     * Returns whether it ended up granted; callers may proceed either way
     * (CameraK records silently when it isn't). Only called when
     * [CameraConfig.enableAudio].
     */
    private suspend fun ensureMicrophonePermission(): Boolean {
        // A throwing mic controller must not crash the record coroutine — degrade to
        // "denied" (CameraK then records silently; capture is never blocked).
        val status = try {
            permissions.requestMicrophone()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            CameraPermissionStatus.DENIED
        }
        _state.update { it.copy(micPermission = status) }
        return status == CameraPermissionStatus.GRANTED
    }

    /** User tapped the "audio off" banner's enable action — re-request the mic. */
    private fun onRequestMicrophone() {
        viewModelScope.launch { ensureMicrophonePermission() }
    }

    /**
     * CameraK fired a capture event. Routes by result type:
     * - success + preview disabled → emit immediately (host closes)
     * - success + preview enabled  → hold for preview (set [CameraUiState.preview])
     * - cancelled → dismiss
     * - error → stay on capture so the user can retry
     */
    private fun onCaptureCompleted(result: CameraResult) {
        // A capture that already timed out must not later deliver a SUCCESS the user
        // was told had failed — the real CameraK event can land after the watchdog
        // fired. Drop that stale success (the timeout's own Error still processes).
        if (captureTimedOut.value && result is CapturedMedia) {
            captureTimedOut.value = false
            return
        }
        val config = _state.value.config
        // Recording (if any) is over → clear the record-action debounce so the
        // shutter re-enables (this is the stop-tap reset).
        _state.update {
            it.copy(phase = CameraPhase.Ready, lastResult = result, recordActionInFlight = false)
        }

        when (result) {
            is CapturedMedia -> {
                analytics.captureCompleted(
                    config = config,
                    sizeBytes = result.sizeBytes,
                    durationMs = (result as? CameraResult.Video)?.durationMs ?: 0L,
                )
                if (isPreviewEnabled) {
                    // Hold for preview — emit only on Submit.
                    previewResolved.value = false
                    _state.update { it.copy(preview = result) }
                } else {
                    // Preview disabled: publish (if opted in) then emit.
                    viewModelScope.launch {
                        maybeSaveToGallery(result, config)
                        _effects.send(CameraEffect.DeliverResult(result))
                    }
                }
            }
            is CameraResult.Cancelled -> {
                analytics.captureCancelled(config)
                emit(CameraEffect.Dismiss)
            }
            is CameraResult.Error -> {
                analytics.captureFailed(config, result.code)
                reportError(
                    code = result.code,
                    message = result.message,
                    context = mapOf(
                        "lens" to config.lens.name,
                        "mode" to config.mode.name,
                    ),
                )
                // Stay on the capture screen so the user can retry.
            }
        }
    }

    /**
     * Preview "Retake" — discard the captured artifact and return to capture.
     * Deletes the (private) temp file so retakes don't accumulate on disk.
     * Guarded against double-tap.
     */
    private fun onRetake() {
        if (!previewResolved.compareAndSet(expect = false, update = true)) return
        val path = _state.value.preview?.filePath
        _state.update { it.copy(phase = CameraPhase.Initializing, preview = null) }
        // Reclaim the private temp — the seam threads the delete off the main thread.
        if (path != null) viewModelScope.launch { platformFileOps.deleteFile(path) }
    }

    /**
     * Preview "Submit" — accept the captured artifact. Optionally publishes it
     * to the device gallery (when [CameraConfig.saveToGallery]) and then emits
     * the result so the host uploads it and closes the flow. Guarded against
     * double-tap.
     */
    private fun onSubmit() {
        if (!previewResolved.compareAndSet(expect = false, update = true)) return
        val media = _state.value.preview ?: return
        // Publish (if opted in) before emitting, so a host that closes the
        // flow on delivery can't cut the gallery save short.
        viewModelScope.launch {
            maybeSaveToGallery(media, _state.value.config)
            _effects.send(CameraEffect.DeliverResult(media as CameraResult))
        }
    }

    /**
     * Publishes [media] to the device gallery when [CameraConfig.saveToGallery]
     * is set, via the injected [mediaPersister]. A failure is reported (never
     * re-thrown past cancellation) so the capture is still delivered even if the
     * gallery publish fails — the private [CapturedMedia.filePath] the host
     * receives is unaffected either way.
     */
    private suspend fun maybeSaveToGallery(media: CapturedMedia, config: CameraConfig) {
        if (!config.saveToGallery) return
        try {
            mediaPersister.saveToGallery(media)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            reportError(
                code = CameraErrorCode.INTERNAL_ERROR,
                message = "Gallery save failed: ${e.message ?: "unknown error"}",
                cause = e,
                context = mapOf("token" to media.token),
            )
        }
    }

    /**
     * Called when the preview leaves composition (back-out, process teardown).
     * Reclaims the private temp file **only if the preview was never resolved**
     * — i.e. neither Retake (which already deleted it) nor Submit (which hands
     * the file to the host's gallery save) ran. The `compareAndSet` makes this
     * a no-op after a resolution, so it never races the host's save.
     */
    private fun onPreviewDisposed() {
        if (!previewResolved.compareAndSet(expect = false, update = true)) return
        val path = _state.value.preview?.filePath
        // Reclaim the private temp — the seam threads the delete off the main thread.
        if (path != null) viewModelScope.launch { platformFileOps.deleteFile(path) }
    }

    /** User tapped back on the capture screen — cancel the whole flow. */
    private fun onCancelRequested() {
        cameraModule.cancel()
        emit(CameraEffect.Dismiss)
    }

    /** Update the camera config (e.g. switch lens, or the memory-downgraded quality). */
    private fun onConfigChanged(config: CameraConfig) {
        _state.update { it.copy(config = config) }
    }

    // ── One-shot channels ──────────────────────────────────────

    private fun emit(effect: CameraEffect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    private fun emit(command: CameraCommand) {
        viewModelScope.launch { _commands.send(command) }
    }

    /**
     * Folds a camera failure into the core [CrashReporter]: reports the real
     * [cause] when there is one, otherwise a [CameraException] carrying the
     * [code]; the [code]/[message] and any [context] travel in the crash `meta`.
     */
    private fun reportError(
        code: String,
        message: String,
        cause: Throwable? = null,
        context: Map<String, String> = emptyMap(),
    ) {
        crashReporter.report(
            cause ?: CameraException(code, message),
            context + mapOf("code" to code, "message" to message),
        )
    }
}

/** Bounds the initial permission status() check (not the request dialog). */
private const val PERMISSION_CHECK_TIMEOUT_MS = 10_000L
