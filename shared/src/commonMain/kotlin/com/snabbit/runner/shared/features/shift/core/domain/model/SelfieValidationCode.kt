package com.snabbit.runner.shared.features.shift.core.domain.model

/**
 * BE-side validation outcomes for the shift-login selfie. The server lists
 * one or more of these codes inside `errors[].data` when it rejects with
 * `code == "SELFIE_VALIDATION_ERROR"`; the UI groups them into the
 * `ValidationBody` current-vs-expected comparison.
 *
 * Wire values mirror Dart's `selfie_preview.dart:332-337`.
 */
enum class SelfieValidationCode {
    UniformNotDetected,
    FaceMismatch,
    FaceNotDetected,
    BikeNotDetected,
    HelmetNotDetected,
    Unknown;

    companion object {
        fun fromWire(code: String): SelfieValidationCode = when (code) {
            "uniform_not_detected" -> UniformNotDetected
            "face_mismatch" -> FaceMismatch
            "face_not_detected" -> FaceNotDetected
            "bike_not_detected" -> BikeNotDetected
            "helmet_not_detected" -> HelmetNotDetected
            else -> Unknown
        }
    }
}
