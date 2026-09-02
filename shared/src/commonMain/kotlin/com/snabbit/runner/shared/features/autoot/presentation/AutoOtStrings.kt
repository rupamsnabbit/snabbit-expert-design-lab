package com.snabbit.runner.shared.features.autoot.presentation

/**
 * User-facing copy for the Auto-OT sheets — English fallbacks mirroring the Flutter
 * `lib/widgets/auto_ot/` strings, restyled to the new design language. Injected so
 * the composables stay DI-free (matches `HomeStrings` / `SupportStrings`).
 *
 * ponytail: the Flutter flow varies a few strings by `OtType` ("…today" vs "…tomorrow");
 * kept single-form here for v1 — reintroduce the suffix when the final copy lands.
 */
data class AutoOtStrings(
    // Offer
    val offerTitlePrefix: String = "Take an OT shift and",
    val offerTitleHighlight: String = "earn more",
    val currentShiftLabel: String = "Current shift",
    val minGLabel: String = "Min G",
    val newMinGLabel: String = "New Min G",
    val selectOtShiftLabel: String = "Select OT shift",
    val confirmOtCta: String = "Confirm OT",
    // Confirm
    val confirmTitle: String = "Confirm your overtime shift",
    val newShiftTimingLabel: String = "New shift timing",
    val confirmCta: String = "Confirm",
    // Loading
    val loadingLabel: String = "Please wait…",
    // Success (no CTA — the sheet ✕ dismisses this terminal state)
    val successTitle: String = "Congrats!",
    val successSubtitle: String = "Overtime confirmed",
    // Expired
    val expiredTitle: String = "Sorry, you were late",
    val expiredSubtitle: String = "Request expired",
    val expiredCta: String = "OK",
    // Failure (shared error + retry)
    val failureTitle: String = "Something went wrong",
    val failureSubtitle: String = "We couldn’t confirm your overtime shift. Please try again.",
    val retryCta: String = "Try again",
    // OT option card — "Work {n} hours extra"; the "{n} hours" segment is emphasised (Figma 226:29605).
    val workExtraPrefix: String = "Work ",
    val workExtraSuffix: String = " extra",
) {
    /** The emphasised middle segment: "{n} hours" (Flutter `ot_shift.dart`). */
    fun workExtraHours(hours: Int?): String = "${hours ?: 0} hours"
}
