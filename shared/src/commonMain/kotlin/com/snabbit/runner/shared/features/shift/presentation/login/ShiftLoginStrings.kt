package com.snabbit.runner.shared.features.shift.presentation.login

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.shift_login_camera_alignment_hint
import com.snabbit.runner.shared.resources.shift_login_error_dismiss
import com.snabbit.runner.shared.resources.shift_login_error_generic_title
import com.snabbit.runner.shared.resources.shift_login_error_no_connection
import com.snabbit.runner.shared.resources.shift_login_error_server
import com.snabbit.runner.shared.resources.shift_login_error_unauthorized
import com.snabbit.runner.shared.resources.shift_login_error_unknown
import com.snabbit.runner.shared.resources.shift_login_intro_bad_header
import com.snabbit.runner.shared.resources.shift_login_intro_cta
import com.snabbit.runner.shared.resources.shift_login_intro_good_caption
import com.snabbit.runner.shared.resources.shift_login_intro_title
import com.snabbit.runner.shared.resources.shift_login_screen_subtitle
import com.snabbit.runner.shared.resources.shift_login_screen_title
import com.snabbit.runner.shared.resources.shift_login_sheet_close
import com.snabbit.runner.shared.resources.shift_login_success_label
import com.snabbit.runner.shared.resources.shift_login_validation_bike_not_detected
import com.snabbit.runner.shared.resources.shift_login_validation_face_mismatch
import com.snabbit.runner.shared.resources.shift_login_validation_face_not_detected
import com.snabbit.runner.shared.resources.shift_login_validation_helmet_not_detected
import com.snabbit.runner.shared.resources.shift_login_validation_retake_cta
import com.snabbit.runner.shared.resources.shift_login_validation_title
import com.snabbit.runner.shared.resources.shift_login_validation_unknown
import com.snabbit.runner.shared.resources.shift_login_validation_uniform_not_detected
import org.jetbrains.compose.resources.stringResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * User-facing copy for the shift-login flow.
 *
 * Same two-tier i18n as [com.snabbit.runner.shared.core.camera.ui.CameraStrings]:
 * the **fallbacks** live in `composeResources` and are resolved by
 * [rememberShiftLoginStrings]; the host may **override** any label at runtime with
 * the app's server-driven i18n value by passing a named argument.
 */
data class ShiftLoginStrings(
    val screenTitle: String,
    val screenSubtitle: String,
    val introTitle: String,
    val introGoodCaption: String,
    val introBadHeader: String,
    val introCta: String,
    val cameraAlignmentHint: String,
    val successLabel: String,
    val errorGenericTitle: String,
    val errorNoConnection: String,
    val errorUnauthorized: String,
    val errorServer: String,
    val errorUnknown: String,
    val errorDismiss: String,
    val validationTitle: String,
    val validationRetakeCta: String,
    val sheetCloseContentDescription: String,
    // Per-code validation lines — resolved via [validationLine].
    val validationUniformNotDetected: String,
    val validationFaceMismatch: String,
    val validationFaceNotDetected: String,
    val validationBikeNotDetected: String,
    val validationHelmetNotDetected: String,
    val validationUnknown: String,
) {
    /** Copy for each [SelfieValidationCode]. */
    fun validationLine(code: SelfieValidationCode): String = when (code) {
        SelfieValidationCode.UniformNotDetected -> validationUniformNotDetected
        SelfieValidationCode.FaceMismatch -> validationFaceMismatch
        SelfieValidationCode.FaceNotDetected -> validationFaceNotDetected
        SelfieValidationCode.BikeNotDetected -> validationBikeNotDetected
        SelfieValidationCode.HelmetNotDetected -> validationHelmetNotDetected
        SelfieValidationCode.Unknown -> validationUnknown
    }

    /**
     * Resolve a domain [ShiftLoginError] to its user-facing message. `Unknown`
     * prefers the server's own message when present (dynamic backend copy), else
     * falls back to [errorUnknown]. `Validation` is surfaced as its own phase, not
     * this Error path — mapped defensively.
     */
    fun messageFor(error: ShiftLoginError): String = when (error) {
        ShiftLoginError.NoConnection -> errorNoConnection
        ShiftLoginError.Unauthorized -> errorUnauthorized
        ShiftLoginError.Server -> errorServer
        is ShiftLoginError.Unknown -> error.serverMessage?.takeUnless { it.isBlank() } ?: errorUnknown
        is ShiftLoginError.Validation -> errorUnknown
    }
}

/**
 * [ShiftLoginStrings] with every label defaulted to its `composeResources`
 * fallback. Pass a named argument to override just that label with a server-driven
 * value.
 */
@Composable
fun rememberShiftLoginStrings(
    screenTitle: String = stringResource(Res.string.shift_login_screen_title),
    screenSubtitle: String = stringResource(Res.string.shift_login_screen_subtitle),
    introTitle: String = stringResource(Res.string.shift_login_intro_title),
    introGoodCaption: String = stringResource(Res.string.shift_login_intro_good_caption),
    introBadHeader: String = stringResource(Res.string.shift_login_intro_bad_header),
    introCta: String = stringResource(Res.string.shift_login_intro_cta),
    cameraAlignmentHint: String = stringResource(Res.string.shift_login_camera_alignment_hint),
    successLabel: String = stringResource(Res.string.shift_login_success_label),
    errorGenericTitle: String = stringResource(Res.string.shift_login_error_generic_title),
    errorNoConnection: String = stringResource(Res.string.shift_login_error_no_connection),
    errorUnauthorized: String = stringResource(Res.string.shift_login_error_unauthorized),
    errorServer: String = stringResource(Res.string.shift_login_error_server),
    errorUnknown: String = stringResource(Res.string.shift_login_error_unknown),
    errorDismiss: String = stringResource(Res.string.shift_login_error_dismiss),
    validationTitle: String = stringResource(Res.string.shift_login_validation_title),
    validationRetakeCta: String = stringResource(Res.string.shift_login_validation_retake_cta),
    sheetCloseContentDescription: String = stringResource(Res.string.shift_login_sheet_close),
    validationUniformNotDetected: String = stringResource(Res.string.shift_login_validation_uniform_not_detected),
    validationFaceMismatch: String = stringResource(Res.string.shift_login_validation_face_mismatch),
    validationFaceNotDetected: String = stringResource(Res.string.shift_login_validation_face_not_detected),
    validationBikeNotDetected: String = stringResource(Res.string.shift_login_validation_bike_not_detected),
    validationHelmetNotDetected: String = stringResource(Res.string.shift_login_validation_helmet_not_detected),
    validationUnknown: String = stringResource(Res.string.shift_login_validation_unknown),
): ShiftLoginStrings = remember(
    screenTitle, screenSubtitle, introTitle, introGoodCaption, introBadHeader, introCta,
    cameraAlignmentHint, successLabel, errorGenericTitle, errorNoConnection, errorUnauthorized,
    errorServer, errorUnknown, errorDismiss, validationTitle, validationRetakeCta,
    sheetCloseContentDescription, validationUniformNotDetected, validationFaceMismatch,
    validationFaceNotDetected, validationBikeNotDetected, validationHelmetNotDetected,
    validationUnknown,
) {
    ShiftLoginStrings(
        screenTitle = screenTitle,
        screenSubtitle = screenSubtitle,
        introTitle = introTitle,
        introGoodCaption = introGoodCaption,
        introBadHeader = introBadHeader,
        introCta = introCta,
        cameraAlignmentHint = cameraAlignmentHint,
        successLabel = successLabel,
        errorGenericTitle = errorGenericTitle,
        errorNoConnection = errorNoConnection,
        errorUnauthorized = errorUnauthorized,
        errorServer = errorServer,
        errorUnknown = errorUnknown,
        errorDismiss = errorDismiss,
        validationTitle = validationTitle,
        validationRetakeCta = validationRetakeCta,
        sheetCloseContentDescription = sheetCloseContentDescription,
        validationUniformNotDetected = validationUniformNotDetected,
        validationFaceMismatch = validationFaceMismatch,
        validationFaceNotDetected = validationFaceNotDetected,
        validationBikeNotDetected = validationBikeNotDetected,
        validationHelmetNotDetected = validationHelmetNotDetected,
        validationUnknown = validationUnknown,
    )
}.localized(getKoin().get())

/**
 * Overlays the server-driven i18n map onto these [ShiftLoginStrings] (baked into
 * [rememberShiftLoginStrings]); absent keys fall back to the composeResources
 * English. Most keys follow the PM localization catalog (dotted namespace); the
 * selfie-rejection reason lines + Retake CTA deliberately reuse the Flutter
 * `SelfieError` sheet's flat keys so both surfaces resolve the same catalog copy.
 */
fun ShiftLoginStrings.localized(store: LocalizationStore): ShiftLoginStrings = copy(
    screenTitle = store.getMessage("login_capture.title", screenTitle),
    screenSubtitle = store.getMessage("login_capture.subtitle", screenSubtitle),
    introTitle = store.getMessage("login_guide.title", introTitle),
    introGoodCaption = store.getMessage("login_guide.take_clean_selfie", introGoodCaption),
    introBadHeader = store.getMessage("login_guide.do_not_like_this", introBadHeader),
    introCta = store.getMessage("login_guide.cta_ok", introCta),
    cameraAlignmentHint = store.getMessage("login_capture.align_face_logo", cameraAlignmentHint),
    successLabel = store.getMessage("login_success.title", successLabel),
    errorGenericTitle = store.getMessage("login_error.generic_title", errorGenericTitle),
    errorNoConnection = store.getMessage("login_error.no_connection", errorNoConnection),
    errorUnauthorized = store.getMessage("login_error.unauthorized", errorUnauthorized),
    errorServer = store.getMessage("login_error.server", errorServer),
    errorUnknown = store.getMessage("login_error.unknown", errorUnknown),
    errorDismiss = store.getMessage("login_error.cta_ok", errorDismiss),
    validationTitle = store.getMessage("login_validation.title", validationTitle),
    // Retake CTA + the per-code reason lines reuse the Flutter `SelfieError` sheet's
    // flat catalog keys (`retake_photo`, `uniform_not_detected`, …) — those are the
    // entries the server localization map actually carries (the dotted `login_validation.*`
    // namespace has no server copy), so this path localizes identically to Dart.
    validationRetakeCta = store.getMessage("retake_photo", validationRetakeCta),
    sheetCloseContentDescription =
        store.getMessage("login_capture.close", sheetCloseContentDescription),
    validationUniformNotDetected =
        store.getMessage("uniform_not_detected", validationUniformNotDetected),
    validationFaceMismatch =
        store.getMessage("face_mismatch", validationFaceMismatch),
    validationFaceNotDetected =
        store.getMessage("face_not_detected", validationFaceNotDetected),
    validationBikeNotDetected =
        store.getMessage("bike_not_detected", validationBikeNotDetected),
    validationHelmetNotDetected =
        store.getMessage("helmet_not_detected", validationHelmetNotDetected),
    // KMP-only fallback (Dart's SelfieError renders nothing for an unrecognized code);
    // no server key, so it always shows the bundled English.
    validationUnknown = store.getMessage("login_validation.unknown", validationUnknown),
)
