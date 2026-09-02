package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.preview_retake_button
import com.snabbit.runner.shared.resources.preview_submit_button
import com.snabbit.runner.shared.resources.preview_subtitle
import com.snabbit.runner.shared.resources.preview_title
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * User-facing labels for the built-in media preview screen ([MediaPreviewScreen]).
 *
 * Same two-tier i18n as [CameraStrings]: the **fallbacks** live in
 * `composeResources` and are resolved by [rememberPreviewStrings]; the host may
 * **override** any label at runtime with a server-driven value. Identical defaults
 * for front and back camera — the caller overrides per flow (shift login, training,
 * go-live).
 */
data class PreviewStrings(
    val title: String,
    val subtitle: String,
    val retakeButton: String,
    val submitButton: String,
)

/**
 * [PreviewStrings] with every label defaulted to its `composeResources` fallback.
 * Pass a named argument to override just that label with a server-driven value.
 */
@Composable
fun rememberPreviewStrings(
    title: String = stringResource(Res.string.preview_title),
    subtitle: String = stringResource(Res.string.preview_subtitle),
    retakeButton: String = stringResource(Res.string.preview_retake_button),
    submitButton: String = stringResource(Res.string.preview_submit_button),
): PreviewStrings = remember(title, subtitle, retakeButton, submitButton) {
    PreviewStrings(
        title = title,
        subtitle = subtitle,
        retakeButton = retakeButton,
        submitButton = submitButton,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [PreviewStrings] (baked into
 * [rememberPreviewStrings]); absent keys fall back to the composeResources English.
 */
fun PreviewStrings.localized(store: LocalizationStore): PreviewStrings = copy(
    title = store.getMessage("login_capture.title", title),
    subtitle = store.getMessage("login_capture.subtitle", subtitle),
    retakeButton = store.getMessage("login_capture.cta_retake", retakeButton),
    submitButton = store.getMessage("login_capture.cta_submit", submitButton),
)
