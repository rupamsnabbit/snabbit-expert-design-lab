package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.camera_audio_off_enable
import com.snabbit.runner.shared.resources.camera_audio_off_recording
import com.snabbit.runner.shared.resources.camera_audio_off_settings
import com.snabbit.runner.shared.resources.camera_capture_button
import com.snabbit.runner.shared.resources.camera_permission_allow_action
import com.snabbit.runner.shared.resources.camera_permission_denied_message
import com.snabbit.runner.shared.resources.camera_permission_rationale
import com.snabbit.runner.shared.resources.camera_permission_settings_action
import com.snabbit.runner.shared.resources.camera_permission_title
import com.snabbit.runner.shared.resources.camera_retake_button
import com.snabbit.runner.shared.resources.camera_subtitle
import com.snabbit.runner.shared.resources.camera_title
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * User-facing labels for the camera capture screen.
 *
 * Two-tier i18n: the **fallbacks** live in `composeResources` (English today,
 * per-locale `values-*` folders later) and are resolved by [rememberCameraStrings];
 * the host can still **override** any label at runtime by passing the app's
 * server-driven i18n value into the corresponding field. So a caller wanting the
 * defaults uses `rememberCameraStrings()`, and a caller with server labels passes
 * them as named arguments.
 */
data class CameraStrings(
    val title: String,
    val subtitle: String,
    val captureButton: String,
    val retakeButton: String,
    val permissionTitle: String,
    // Soft-denied (re-requestable): "Allow" re-prompts the OS.
    val permissionRationale: String,
    val permissionAllowAction: String,
    // Permanently denied: only app settings can grant it.
    val permissionDeniedMessage: String,
    val permissionSettingsAction: String,
    // Audio video without mic permission — recording continues silently.
    val audioOffRecording: String,
    val audioOffEnable: String,
    val audioOffSettings: String,
)

/**
 * [CameraStrings] with every label defaulted to its `composeResources` fallback.
 *
 * Each parameter defaults to a `stringResource(...)` lookup, so passing nothing
 * yields the fully-localised fallbacks and passing a named argument overrides just
 * that label with a server-driven value.
 */
@Composable
fun rememberCameraStrings(
    title: String = stringResource(Res.string.camera_title),
    subtitle: String = stringResource(Res.string.camera_subtitle),
    captureButton: String = stringResource(Res.string.camera_capture_button),
    retakeButton: String = stringResource(Res.string.camera_retake_button),
    permissionTitle: String = stringResource(Res.string.camera_permission_title),
    permissionRationale: String = stringResource(Res.string.camera_permission_rationale),
    permissionAllowAction: String = stringResource(Res.string.camera_permission_allow_action),
    permissionDeniedMessage: String = stringResource(Res.string.camera_permission_denied_message),
    permissionSettingsAction: String = stringResource(Res.string.camera_permission_settings_action),
    audioOffRecording: String = stringResource(Res.string.camera_audio_off_recording),
    audioOffEnable: String = stringResource(Res.string.camera_audio_off_enable),
    audioOffSettings: String = stringResource(Res.string.camera_audio_off_settings),
): CameraStrings = remember(
    title, subtitle, captureButton, retakeButton, permissionTitle, permissionRationale,
    permissionAllowAction, permissionDeniedMessage, permissionSettingsAction,
    audioOffRecording, audioOffEnable, audioOffSettings,
) {
    CameraStrings(
        title = title,
        subtitle = subtitle,
        captureButton = captureButton,
        retakeButton = retakeButton,
        permissionTitle = permissionTitle,
        permissionRationale = permissionRationale,
        permissionAllowAction = permissionAllowAction,
        permissionDeniedMessage = permissionDeniedMessage,
        permissionSettingsAction = permissionSettingsAction,
        audioOffRecording = audioOffRecording,
        audioOffEnable = audioOffEnable,
        audioOffSettings = audioOffSettings,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [CameraStrings]: each field resolves
 * via `getMessage("<key>", englishFallback)` and falls back to the composeResources
 * English when the store has no entry. Baked into [rememberCameraStrings] so every call
 * site localizes. Keys follow the PM localization catalog (dotted namespace).
 */
fun CameraStrings.localized(store: LocalizationStore): CameraStrings = copy(
    title = store.getMessage("login_capture.title", title),
    subtitle = store.getMessage("login_capture.subtitle", subtitle),
    captureButton = store.getMessage("login_capture.capture_button", captureButton),
    retakeButton = store.getMessage("login_capture.retake_button", retakeButton),
    permissionTitle = store.getMessage("login_capture.permission_title", permissionTitle),
    permissionRationale =
        store.getMessage("login_capture.permission_rationale", permissionRationale),
    permissionAllowAction =
        store.getMessage("login_capture.permission_allow_action", permissionAllowAction),
    permissionDeniedMessage =
        store.getMessage("login_capture.permission_denied_message", permissionDeniedMessage),
    permissionSettingsAction =
        store.getMessage("login_capture.permission_settings_action", permissionSettingsAction),
    audioOffRecording = store.getMessage("login_capture.audio_off_recording", audioOffRecording),
    audioOffEnable = store.getMessage("login_capture.audio_off_enable", audioOffEnable),
    audioOffSettings = store.getMessage("login_capture.audio_off_settings", audioOffSettings),
)
