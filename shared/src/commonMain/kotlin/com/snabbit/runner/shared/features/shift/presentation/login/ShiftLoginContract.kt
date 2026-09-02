package com.snabbit.runner.shared.features.shift.presentation.login

import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError

/**
 * Render state for the shift-login flow.
 *
 * Single axis [phase] — the screen has no hidden mode bits; bottom sheets
 * and overlays flow directly from the phase value.
 */
data class ShiftLoginUiState(
    val phase: ShiftLoginPhase = ShiftLoginPhase.IntroSheet,
)

/**
 * Phases for the shift-login flow:
 *
 *  - [IntroSheet] — entry. GPS fetch runs in parallel; OK CTA advances.
 *  - [Camera] — live capture (CameraFlow owns permission lifecycle and the shutter).
 *  - [Uploading] — multipart POST in flight (shows spinner over [capturedPath]).
 *  - [Success] — green overlay + "Login successful" over [capturedPath]; ticks ~1s
 *                then the VM emits [ShiftLoginUiEffect.Finish] with refresh=true.
 *  - [Validation] — BE returned `SELFIE_VALIDATION_ERROR`; full-screen current-vs-expected
 *                   comparison over [capturedPath] with a Retake CTA.
 *  - [Error] — any other failure surfaced via a dismiss-only sheet.
 */
sealed interface ShiftLoginPhase {
    data object IntroSheet : ShiftLoginPhase
    data object Camera : ShiftLoginPhase
    data class Uploading(val capturedPath: String) : ShiftLoginPhase
    data class Success(val capturedPath: String) : ShiftLoginPhase

    /**
     * BE rejected the selfie. [codes] drive the reason line(s); [capturedPath]
     * is the just-taken selfie, shown as the "your photo" (❌) side of the
     * current-vs-expected comparison against the correct-uniform example (✓).
     */
    data class Validation(
        val codes: List<SelfieValidationCode>,
        val capturedPath: String,
    ) : ShiftLoginPhase

    /** Any non-validation failure. Carries the domain error; the screen resolves
     *  it to copy via [ShiftLoginStrings.messageFor] so the VM holds no strings. */
    data class Error(val error: ShiftLoginError) : ShiftLoginPhase
}

/**
 * Every user action the shift-login screen can trigger. Camera-flow callbacks
 * come back to the VM as intents too so the state machine stays in one place.
 */
sealed interface ShiftLoginUiIntent {
    /** "OK" tapped on the intro sheet — or the sheet dismissed via X/scrim;
     *  both advance to [ShiftLoginPhase.Camera] (ECPO-829). */
    data object AcknowledgeIntro : ShiftLoginUiIntent

    /** Camera flow produced a result (photo, cancellation, or error). */
    data class CameraCompleted(val result: CameraResult) : ShiftLoginUiIntent

    /** Validation sheet's "Retake" CTA — back to Camera, same flow. */
    data object Retake : ShiftLoginUiIntent

    /** Dismiss the flow (error sheet, top-bar back). */
    data object Dismiss : ShiftLoginUiIntent

    /** Success overlay's auto-tick elapsed — emit Finish(refresh=true). */
    data object SuccessTickElapsed : ShiftLoginUiIntent
}

/**
 * One-shot side effects from [ShiftLoginViewModel]. Surfaced via
 * `effects: SharedFlow` so a re-subscription doesn't replay them.
 */
sealed interface ShiftLoginUiEffect {
    /**
     * The flow is done — host should pop back to Home. Refresh is no longer
     * coupled to dismiss: the VM fires the runner-state refresh callback on
     * upload-success (concurrent with the success-overlay dwell), so by the
     * time this effect lands the store has usually republished the
     * post-login envelope already.
     */
    data object Finish : ShiftLoginUiEffect
}

