package com.snabbit.runner.shared.features.shift.presentation.login
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraLens
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CaptureMode
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps
import com.snabbit.runner.shared.core.camera.ui.CameraFlow
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import com.snabbit.runner.shared.features.shift.presentation.login.ErrorSheet
import com.snabbit.runner.shared.features.shift.presentation.login.IntroSheet
import com.snabbit.runner.shared.features.shift.presentation.login.SuccessOverlay
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import org.koin.compose.koinInject

/**
 * Hosts the shift-login flow. Top-level structure:
 *
 *  - [SnabbitScreen] wraps the body in our theme + status-bar inset. The
 *    top nav (title + subtitle + back) is only shown when the body is NOT
 *    the camera — `CameraFlow` ships its own top bar that matches the figma
 *    exactly, so doubling up would just look wrong.
 *  - The body switches on [ShiftLoginPhase]. The IntroSheet/Validation/Error
 *    phases render a transparent body and stack a [SnabbitBottomSheet] on top.
 *  - The screen forwards [ShiftLoginUiEffect.Finish] to the host via [onFinish],
 *    so the activity can pop back to Home (and optionally refresh the runner
 *    state envelope).
 *
 * The camera is delegated to [CameraFlow]; its [CameraViewModel] is `remember`'d
 * so reentering the Camera phase after a Retake reuses the same instance.
 */
@Composable
fun ShiftLoginScreen(
    viewModel: ShiftLoginViewModel,
    strings: ShiftLoginStrings = rememberShiftLoginStrings(),
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                ShiftLoginUiEffect.Finish -> onFinish()
            }
        }
    }

    val phase = state.phase

    // Remember the last Error / Validation payload so their bottom sheets can
    // animate out after the phase has moved on.
    var lastError by remember { mutableStateOf<ShiftLoginError?>(null) }
    if (phase is ShiftLoginPhase.Error) lastError = phase.error
    var lastValidation by remember { mutableStateOf<ShiftLoginPhase.Validation?>(null) }
    if (phase is ShiftLoginPhase.Validation) lastValidation = phase

    // Decode the rejected capture once (front-camera → mirrored); shared by the
    // capture VIEW (screen body) and the ❌ tile inside ValidationSheet. Keyed on
    // the remembered path so it survives the sheet's out-animation.
    val fileOps = koinInject<PlatformFileOps>()
    val validationCapture by produceState<ImageBitmap?>(
        initialValue = null,
        key1 = lastValidation?.capturedPath,
    ) {
        value = lastValidation?.capturedPath?.let {
            fileOps.loadDownsampledBitmap(it, reqWidthPx = 1080, reqHeightPx = 1080, mirrorHorizontally = true)
        }
    }

    // Camera hosts its own top bar; every other phase (incl. the Validation
    // capture view) uses SnabbitScreen's "Take a selfie" nav.
    val showTopNav = phase !is ShiftLoginPhase.Camera
    SnabbitScreen(
        modifier = modifier,
        title = if (showTopNav) strings.screenTitle else null,
        subtitle = if (showTopNav) strings.screenSubtitle else null,
        onNavigateUp = if (showTopNav) {
            { viewModel.onIntent(ShiftLoginUiIntent.Dismiss) }
        } else null,
    ) { padding ->
        // Consume the scaffold insets we just applied. The Camera/Validation
        // phases nest CameraFlow's own SnabbitScreen (a second Scaffold whose
        // top nav re-applies the status-bar inset); without consuming here that
        // inset is counted twice, pushing the camera's app bar ~a status-bar
        // height too low. Harmless for the other phases (no nested insets).
        Box(modifier = Modifier.fillMaxSize().padding(padding).consumeWindowInsets(padding)) {
            when (phase) {
                ShiftLoginPhase.IntroSheet -> ScrimBackground()
                ShiftLoginPhase.Camera -> CameraHost(
                    onResult = { viewModel.onIntent(ShiftLoginUiIntent.CameraCompleted(it)) },
                    onCancel = { viewModel.onIntent(ShiftLoginUiIntent.Dismiss) },
                )
                is ShiftLoginPhase.Uploading -> UploadingBody(phase.capturedPath)
                is ShiftLoginPhase.Success -> SuccessOverlay(
                    capturedPath = phase.capturedPath,
                    strings = strings,
                )
                // The rejected-capture view stays as the body; the reason +
                // comparison + Retake ride on top in the ValidationSheet below.
                is ShiftLoginPhase.Validation -> ValidationCaptureView(
                    bitmap = validationCapture,
                    modifier = Modifier.padding(SnabbitTheme.spacing.componentPaddingMd),
                )
                is ShiftLoginPhase.Error -> ScrimBackground()
            }
        }
    }

    // Sheets layer — the DS SnabbitBottomSheet is a Popup driven by `visible`,
    // so each sheet is always composed and toggled; it stacks above the
    // SnabbitScreen body (`phase` / `lastError` / `lastValidation` hoisted above).
    SnabbitBottomSheet(
        visible = phase is ShiftLoginPhase.IntroSheet,
        // Dismissing the guideline sheet (X / scrim tap) advances to the
        // camera — same as OK — instead of finishing the flow; only the
        // top-bar back exits to Home (ECPO-829).
        onDismissRequest = { viewModel.onIntent(ShiftLoginUiIntent.AcknowledgeIntro) },
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        IntroSheet(
            strings = strings,
            onOk = { viewModel.onIntent(ShiftLoginUiIntent.AcknowledgeIntro) },
        )
    }
    SnabbitBottomSheet(
        visible = phase is ShiftLoginPhase.Error,
        onDismissRequest = { viewModel.onIntent(ShiftLoginUiIntent.Dismiss) },
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        ErrorSheet(
            message = lastError?.let { strings.messageFor(it) }.orEmpty(),
            strings = strings,
            onDismiss = { viewModel.onIntent(ShiftLoginUiIntent.Dismiss) },
        )
    }
    SnabbitBottomSheet(
        visible = phase is ShiftLoginPhase.Validation,
        // Dismissing the rejection (X / scrim tap) retries the capture rather
        // than exiting the flow; only the top-bar back exits to Home.
        onDismissRequest = { viewModel.onIntent(ShiftLoginUiIntent.Retake) },
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        ValidationSheet(
            codes = lastValidation?.codes.orEmpty(),
            capturedBitmap = validationCapture,
            strings = strings,
            onRetake = { viewModel.onIntent(ShiftLoginUiIntent.Retake) },
        )
    }
}

@Composable
private fun ScrimBackground() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(SnabbitTheme.colors.bgPrimary),
    )
}

@Composable
private fun CameraHost(
    onResult: (CameraResult) -> Unit,
    onCancel: () -> Unit,
) {
    // CameraFlow owns its own CameraViewModel (resolved from Koin with the
    // per-launch `source`), permission lifecycle, and the CameraK preview
    // surface. Analytics + the PermissionManager-backed permission controller
    // are injected by `cameraKoinModule`; the host only supplies the source tag
    // and the result/dismiss callbacks.
    CameraFlow(
        source = "shift_login",
        onResult = onResult,
        onDismiss = onCancel,
        config = CameraConfig(lens = CameraLens.FRONT, mode = CaptureMode.PHOTO),
        onNavigateUp = onCancel,
    )
}

@Composable
private fun UploadingBody(capturedPath: String) {
    val fileOps = koinInject<PlatformFileOps>()
    val bitmap by produceState<androidx.compose.ui.graphics.ImageBitmap?>(
        initialValue = null,
        key1 = capturedPath,
    ) {
        value = fileOps.loadDownsampledBitmap(
            path = capturedPath,
            reqWidthPx = 1080,
            reqHeightPx = 1080,
            mirrorHorizontally = true,
        )
    }
    Box(modifier = Modifier.fillMaxSize()) {
        bitmap?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(SnabbitTheme.colors.bgInverse.copy(alpha = 0.4f)),
        )
        CircularProgressIndicator(
            modifier = Modifier.align(Alignment.Center),
            color = SnabbitTheme.colors.textInverse,
        )
    }
}
