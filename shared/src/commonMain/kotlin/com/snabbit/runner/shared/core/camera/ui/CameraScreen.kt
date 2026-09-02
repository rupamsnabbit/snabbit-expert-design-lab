package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraLens
import com.snabbit.runner.shared.core.camera.CaptureMode
import com.snabbit.runner.shared.core.camera.CaptureQuality
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps
import com.snabbit.runner.shared.core.camera.internal.toCameraResultOrNull

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kashif.cameraK.compose.CameraKScreen
import com.kashif.cameraK.compose.rememberCameraKState
import com.kashif.cameraK.enums.CameraLens as CKLens
import com.kashif.cameraK.enums.DeviceOrientation
import com.kashif.cameraK.enums.Directory
import com.kashif.cameraK.enums.FlashMode as CKFlash
import com.kashif.cameraK.enums.ImageFormat
import com.kashif.cameraK.enums.QualityPrioritization
import com.kashif.cameraK.state.CameraConfiguration
import com.kashif.cameraK.state.CameraKState as CKState
import com.kashif.cameraK.state.CameraKStateHolder
import com.kashif.cameraK.video.VideoConfiguration
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import kotlinx.coroutines.delay
import org.koin.compose.koinInject

/**
 * Camera capture screen — permission gate → live preview → capture button.
 *
 * Normally hosted inside [CameraFlow]. Responsibilities:
 * 1. Drive the permission gate via [CameraViewModel.onStart].
 * 2. Render the right surface for the current [CameraPhase]: permission UI,
 *    a loading spinner, the live CameraK preview, or an error message.
 * 3. **Only compose the CameraK preview once permission is granted** — the
 *    camera hardware is never initialized behind a denied permission.
 *
 * Chrome (theme, background, top nav, insets) comes from [SnabbitScreen]; all
 * visible UI uses Snabbit Design System components + `SnabbitTheme` tokens. The
 * one exception is the bespoke [CaptureButton] shutter and the dark-scrim HUD
 * pills (REC / audio-off) drawn over the live preview — no DS component models a
 * video HUD, so those are `Box` + `SnabbitText` + tokens.
 *
 * @param overlay drawn on top of the live preview (face guide, document frame…).
 * @param allowBack when `false`, the back affordance is hidden and the system
 *   back gesture is swallowed (mandatory-capture flows).
 * @param saveToGalleryOnCapture `true` → CameraK saves to the public gallery
 *   immediately (no-preview path); `false` (default — fail-closed for PII) →
 *   private capture, gallery save deferred to Submit (preview path). [CameraFlow]
 *   always passes an explicit value derived from `config.saveToGallery`.
 */
@Composable
fun CameraScreen(
    viewModel: CameraViewModel,
    strings: CameraStrings,
    modifier: Modifier = Modifier,
    config: CameraConfig = CameraConfig(),
    allowBack: Boolean = true,
    overlay: (@Composable BoxScope.() -> Unit)? = null,
    saveToGalleryOnCapture: Boolean = false,
    captureContent: (@Composable BoxScope.(CameraCaptureScope) -> Unit)? = null,
    onNavigateUp: (() -> Unit)? = null,
) {
    val uiState by viewModel.state.collectAsStateWithLifecycle()

    // Swallow the system back gesture when back is not allowed.
    CameraBackHandler(enabled = !allowBack) { /* swallow */ }

    // Run the permission gate once (idempotent in the VM).
    LaunchedEffect(Unit) { viewModel.dispatch(CameraIntent.Start) }

    // Re-check permission when the app returns to the foreground — recovers a
    // permanently-denied user who granted it in OS settings and came back, without
    // relying on the host to forward onResume.
    OnAppResumed { viewModel.dispatch(CameraIntent.Resumed) }

    // Show the back affordance only when allowed, rendered as the design's chevron
    // (replacing the DS default arrow) via SnabbitScreen's leading slot.
    val onBack = if (allowBack) onNavigateUp else null
    SnabbitScreen(
        modifier = modifier,
        title = strings.title,
        subtitle = strings.subtitle,
        onNavigateUp = onBack,
        navigationIcon = if (onBack != null) {
            { CameraBackButton(onClick = onBack) }
        } else {
            null
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            val phase = uiState.phase
            when {
                // Camera hardware is only created in this branch (post-permission).
                uiState.canShowCamera -> CameraCaptureArea(
                    viewModel = viewModel,
                    strings = strings,
                    config = config,
                    overlay = overlay,
                    saveToGalleryOnCapture = saveToGalleryOnCapture,
                    captureContent = captureContent,
                )
                uiState.needsPermission -> PermissionGate(
                    permanentlyDenied = phase is CameraPhase.PermissionPermanentlyDenied,
                    strings = strings,
                    onAllow = { viewModel.dispatch(CameraIntent.RequestPermission) },
                    onOpenSettings = { viewModel.dispatch(CameraIntent.OpenAppSettings) },
                )
                phase is CameraPhase.Error -> CenteredMessage(phase.message)
                else -> CenteredProgress() // CheckingPermission
            }
        }
    }
}

/**
 * The live-camera surface: owns [rememberCameraKState] (so the camera is
 * only created when this is composed — i.e. after permission), event
 * collection, the capture/init/recording watchdogs, and the capture button.
 *
 * When [captureContent] is `null` the built-in chrome (framed preview + overlay +
 * REC/audio HUD + bespoke shutter) is used — the default. When it's supplied, the
 * module still owns the CameraK engine but renders the preview full-bleed and hands
 * the caller a [CameraCaptureScope] to draw their own chrome. Either way the shutter
 * is a single [CameraIntent.ShutterPressed] dispatch and the VM decides + arms, so
 * behaviour is identical.
 */
@Composable
private fun ColumnScope.CameraCaptureArea(
    viewModel: CameraViewModel,
    strings: CameraStrings,
    config: CameraConfig,
    overlay: (@Composable BoxScope.() -> Unit)?,
    saveToGalleryOnCapture: Boolean,
    captureContent: (@Composable BoxScope.(CameraCaptureScope) -> Unit)?,
) {
    val uiState by viewModel.state.collectAsStateWithLifecycle()
    var stateHolder by remember { mutableStateOf<CameraKStateHolder?>(null) }
    // File-ops seam for the CameraK event → domain mapping (temp write / compress /
    // stat). Injected so the mapping stays testable and platform-free here.
    val fileOps = koinInject<PlatformFileOps>()

    // Budget-device safeguard: under memory pressure, drop to the lowest capture
    // quality to cut peak memory during encode. Read once (via the injected,
    // non-composable DeviceMemory seam), before the live preview is composed.
    // Never blocks the camera (a partner must still shoot).
    val deviceMemory = koinInject<DeviceMemory>()
    val effectiveConfig = remember(config, deviceMemory) {
        if (deviceMemory.isLow() && config.quality != CaptureQuality.LOW) {
            config.copy(quality = CaptureQuality.LOW)
        } else {
            config
        }
    }
    // Push the effective (possibly memory-downgraded) config into the VM so the
    // shutter decides photo/video and arms against it, and StartRecording carries it.
    LaunchedEffect(effectiveConfig) {
        viewModel.dispatch(CameraIntent.ConfigChanged(effectiveConfig))
    }
    val cameraKConfig = effectiveConfig.toCameraKConfiguration(saveToGalleryOnCapture)
    val cameraKState by rememberCameraKState(
        config = cameraKConfig,
        setupPlugins = { holder -> stateHolder = holder },
    )

    LaunchedEffect(cameraKState) {
        when (val state = cameraKState) {
            is CKState.Ready -> {
                // Lock capture output to PORTRAIT — CameraK otherwise follows
                // the device's physical tilt (saved image came out landscape).
                state.controller.setTargetOrientation(DeviceOrientation.PORTRAIT)
                viewModel.dispatch(CameraIntent.CameraReady)
            }
            is CKState.Error -> viewModel.dispatch(CameraIntent.CameraError(state.message))
            is CKState.Initializing -> { /* waiting */ }
        }
    }

    val holder = stateHolder
    if (holder != null) {
        // Map CameraK capture events → domain result → ViewModel.
        LaunchedEffect(holder) {
            holder.events.collect { event ->
                event.toCameraResultOrNull(fileOps)?.let { viewModel.dispatch(CameraIntent.CaptureCompleted(it)) }
            }
        }
        // Drive the CameraK holder from the VM's hardware commands. The VM decides
        // photo/video-start/video-stop and arms on ShutterPressed; the surface just
        // runs the command. Collected here because commands only ever fire while the
        // capture surface is composed. runCatching so a redundant CameraK call can't crash.
        LaunchedEffect(holder) {
            viewModel.commands.collect { command ->
                when (command) {
                    CameraCommand.CapturePhoto -> runCatching { holder.captureImage() }
                    is CameraCommand.StartRecording -> runCatching {
                        holder.startRecording(
                            VideoConfiguration(
                                enableAudio = command.config.enableAudio,
                                maxDurationMs = command.config.maxVideoDurationMs,
                            ),
                        )
                    }
                    CameraCommand.StopRecording -> runCatching { holder.stopRecording() }
                }
            }
        }
    }

    // Capture watchdog: a hung capture must not pin the Capturing phase forever.
    // Keyed on isCapturing — when the result arrives, this cancels; if it never
    // does, the VM re-checks the live phase and fires a timeout error.
    LaunchedEffect(uiState.isCapturing) {
        if (uiState.isCapturing) {
            delay(CAPTURE_TIMEOUT_MS)
            viewModel.dispatch(CameraIntent.CaptureTimeout)
        }
    }

    // Init watchdog: if the camera never reaches Ready (disabled by device
    // policy, held by another app, or a slow HAL), don't spin forever —
    // surface an error so the user isn't stuck on the loading spinner.
    // Safe to re-arm on every phase change (incl. retake → Initializing):
    // CameraInitTimeout re-checks the live phase and no-ops unless still
    // Initializing — keep that VM-side guard if a new phase is ever added.
    LaunchedEffect(uiState.phase) {
        if (uiState.phase is CameraPhase.Initializing) {
            delay(CAMERA_INIT_TIMEOUT_MS)
            viewModel.dispatch(CameraIntent.CameraInitTimeout)
        }
    }

    // Recording watchdog. While recording, arm a timeout so a wedged HAL that never
    // emits a stop can't pin the Recording phase forever (CameraK should auto-stop at
    // maxDuration first, cancelling this). The record-action debounce reset now lives
    // in the VM (cleared when the recording ends).
    LaunchedEffect(uiState.isRecording) {
        if (uiState.isRecording) {
            delay(config.maxVideoDurationMs + RECORDING_GRACE_MS)
            viewModel.dispatch(CameraIntent.RecordingTimeout)
        }
    }

    // Custom capture UI: the module keeps the CameraK engine (effects above) and
    // renders the preview full-bleed; the caller draws all chrome (shutter, HUD,
    // guides) over it and drives capture via [CameraCaptureScope]. The built-in
    // overlay/HUD/shutter are skipped — the caller owns them.
    if (captureContent != null) {
        val liveState = uiState
        val captureScope = object : CameraCaptureScope {
            override val uiState: CameraUiState = liveState
            override fun onShutter() = viewModel.dispatch(CameraIntent.ShutterPressed)
            override fun onRequestMicrophone() = viewModel.dispatch(CameraIntent.RequestMicrophone)
            override fun onOpenAppSettings() = viewModel.dispatch(CameraIntent.OpenAppSettings)
        }
        Box(modifier = Modifier.fillMaxWidth().weight(1f)) {
            LivePreview(cameraKState = cameraKState, modifier = Modifier.fillMaxSize())
            captureContent(captureScope)
        }
        return
    }

    // ── Built-in capture chrome (default) ─────────────────────────────
    // Framed preview locked to the design's 353×519 window (@ 393×852): full
    // width minus the 20.dp side margins yields the 353 width, and
    // PREVIEW_ASPECT_RATIO then fixes the 519 height, so the frame keeps its
    // proportion on other widths instead of stretching to fill the column.
    Spacer(Modifier.height(16.dp))
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .aspectRatio(PREVIEW_ASPECT_RATIO)
            .clip(RoundedCornerShape(24.dp)),
    ) {
        LivePreview(cameraKState = cameraKState, modifier = Modifier.fillMaxSize())
        overlay?.invoke(this)

        if (uiState.isRecording) {
            RecordingIndicator(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 12.dp),
            )
        }

        // Audio requested but mic not granted → non-blocking "audio off" HUD pill
        // (feedback + a fix path when idle). Recording still proceeds silently.
        if (config.enableAudio && uiState.microphoneDenied) {
            AudioPermissionBanner(
                permanentlyDenied = uiState.microphonePermanentlyDenied,
                isRecording = uiState.isRecording,
                strings = strings,
                onEnable = { viewModel.dispatch(CameraIntent.RequestMicrophone) },
                onOpenSettings = { viewModel.dispatch(CameraIntent.OpenAppSettings) },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 12.dp),
            )
        }
    }

    Spacer(Modifier.weight(1f))

    Box(
        modifier = Modifier.fillMaxWidth().padding(bottom = 32.dp),
        contentAlignment = Alignment.Center,
    ) {
        CaptureButton(
            onClick = { viewModel.dispatch(CameraIntent.ShutterPressed) },
            // Ready → start; Recording → stop. (isCapturing is the photo snap.)
            enabled = (uiState.canCapture || uiState.isRecording) &&
                !uiState.isCapturing && stateHolder != null && !uiState.recordActionInFlight,
            // Video: morph to the stop-square while recording; photo stays a circle.
            isRecording = config.mode == CaptureMode.VIDEO && uiState.isRecording,
        )
    }
}

/**
 * The module-owned live camera preview (CameraK), with the standard loading and
 * error surfaces. Shared by the built-in chrome and a custom `captureContent`, so
 * the preview renders identically either way. Overlays and chrome are drawn as
 * siblings on top of this by the caller (default chrome) or the custom content.
 */
@Composable
private fun LivePreview(
    cameraKState: CKState,
    modifier: Modifier,
) {
    CameraKScreen(
        modifier = modifier,
        cameraState = cameraKState,
        loadingContent = {
            Box(
                modifier = Modifier.fillMaxSize().background(SnabbitTheme.colors.bgInverse),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = SnabbitTheme.colors.textInverse) }
        },
        errorContent = { error ->
            Box(
                modifier = Modifier.fillMaxSize().background(SnabbitTheme.colors.bgInverse),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitText(
                    text = error.message,
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textInverse,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(24.dp),
                )
            }
        },
    ) { _ -> }
}

/**
 * Back affordance for the camera screens' top nav — the design's left chevron
 * (replacing the DS default arrow), rendered via SnabbitScreen's leading slot.
 * Mirrors the DS back-button footprint (48dp circular tap target) so layout/spacing
 * match. Shared by the capture screen and the preview screen ([MediaPreviewScreen]).
 */
@Composable
internal fun CameraBackButton(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitIcon(
            name = SnabbitIconName.ChevronLeft,
            size = 24.dp,
            color = SnabbitTheme.colors.textPrimary,
            contentDescription = "Back",
        )
    }
}

/** Permission rationale / settings prompt, shown when the camera is gated. */
@Composable
private fun ColumnScope.PermissionGate(
    permanentlyDenied: Boolean,
    strings: CameraStrings,
    onAllow: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .weight(1f)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        SnabbitText(
            text = strings.permissionTitle,
            variant = SnabbitTextVariant.Title,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
        )
        SnabbitText(
            text = if (permanentlyDenied) strings.permissionDeniedMessage else strings.permissionRationale,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
        )
        SnabbitButton(
            text = if (permanentlyDenied) strings.permissionSettingsAction else strings.permissionAllowAction,
            onClick = if (permanentlyDenied) onOpenSettings else onAllow,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
        )
    }
}

@Composable
private fun ColumnScope.CenteredProgress() {
    Box(
        modifier = Modifier.fillMaxWidth().weight(1f),
        contentAlignment = Alignment.Center,
    ) { CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand) }
}

@Composable
private fun ColumnScope.CenteredMessage(message: String) {
    Box(
        modifier = Modifier.fillMaxWidth().weight(1f).padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitText(
            text = message,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

/** Red "REC" pill with a running mm:ss timer, shown while recording. */
@Composable
private fun RecordingIndicator(modifier: Modifier = Modifier) {
    var elapsedSec by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000)
            elapsedSec++
        }
    }
    @Suppress("MagicNumber")
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SnabbitTheme.colors.bgInverse.copy(alpha = 0.8f))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        SnabbitText(
            text = "🔴 REC  ${elapsedSec / 60}:${(elapsedSec % 60).toString().padStart(2, '0')}",
            variant = SnabbitTextVariant.Caption,
            color = SnabbitTheme.colors.textInverse,
        )
    }
}

/** Non-blocking "audio off" HUD pill when an audio video lacks mic permission. */
@Composable
private fun AudioPermissionBanner(
    permanentlyDenied: Boolean,
    isRecording: Boolean,
    strings: CameraStrings,
    onEnable: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val text = when {
        isRecording -> strings.audioOffRecording
        permanentlyDenied -> strings.audioOffSettings
        else -> strings.audioOffEnable
    }
    // Offer the fix only when idle — don't navigate away mid-recording.
    val tappable = !isRecording
    @Suppress("MagicNumber")
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(SnabbitTheme.colors.bgInverse.copy(alpha = 0.9f))
            .then(
                if (tappable) {
                    Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { if (permanentlyDenied) onOpenSettings() else onEnable() }
                } else {
                    Modifier
                },
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        SnabbitText(
            text = text,
            variant = SnabbitTextVariant.Caption,
            color = SnabbitTheme.colors.textInverse,
        )
    }
}

// ── Config mapping ───────────────────────────────────────────────

private fun CameraConfig.toCameraKConfiguration(
    saveToGalleryOnCapture: Boolean,
): CameraConfiguration {
    return CameraConfiguration(
        cameraLens = when (lens) {
            CameraLens.FRONT -> CKLens.FRONT
            CameraLens.BACK -> CKLens.BACK
        },
        flashMode = CKFlash.OFF,
        imageFormat = ImageFormat.JPEG,
        qualityPrioritization = when (quality) {
            CaptureQuality.LOW -> QualityPrioritization.SPEED
            CaptureQuality.MEDIUM -> QualityPrioritization.BALANCED
            CaptureQuality.HIGH -> QualityPrioritization.QUALITY
        },
        // Keep CameraK's own capture files in app-private storage. CameraK
        // otherwise defaults `directory` to PICTURES and writes every photo to the
        // PUBLIC Pictures/ folder (and videos to Movies/), leaking captures into
        // the device gallery regardless of returnFilePath. DOCUMENTS maps to
        // getExternalFilesDir ("not synced with Photos"), so the ONLY route to the
        // public gallery is the opt-in MediaPersister path (config.saveToGallery).
        directory = Directory.DOCUMENTS,
        // true → CameraK returns a saved (app-private) file path; false → ByteArray
        //   to a private temp (the default). Neither publishes to the public
        //   gallery — that is the MediaPersister's job when a capture is accepted.
        returnFilePath = saveToGalleryOnCapture,
    )
}

/**
 * Camera preview window aspect ratio (width ÷ height) — the design's 353×519
 * frame at a 393×852 screen. The 20.dp side margins set the 353 width; this
 * ratio then fixes the 519 height so the frame scales proportionally on other
 * widths instead of stretching to fill the column.
 */
private const val PREVIEW_ASPECT_RATIO = 353f / 519f

/** Watchdog timeout for a capture that never produces an event (C2). */
private const val CAPTURE_TIMEOUT_MS = 15_000L

/** Watchdog timeout for a camera that never reaches Ready (#6 — stuck init). */
private const val CAMERA_INIT_TIMEOUT_MS = 10_000L

/**
 * Grace beyond `maxVideoDurationMs` before the recording watchdog fires. CameraK
 * should auto-stop at the max (cancelling the watchdog); this only catches a wedged
 * HAL that never emits a stop event.
 */
private const val RECORDING_GRACE_MS = 5_000L
