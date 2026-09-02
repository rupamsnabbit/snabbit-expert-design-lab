package com.snabbit.runner.shared.features.tiering.domain.model

/**
 * The tiering-relevant slice of the runner profile (`runners/me`), mirroring the
 * Flutter `UserProfile` tiering fields. Decoded in the data layer from the
 * profile raw JSON (the profile DTO doesn't model these).
 *
 * [isTieringEnabled] is precomputed in the data layer — the runner's tier
 * effective date is on/before today (device-local). The drawer tier row shows
 * only when it is true; the intro banner hides once [hasViewedIntro].
 *
 * [serviceId] / [isSuspended] back the eligibility half of the Flutter
 * `shouldShowTiering` gate (tiering surfaces only for `serviceId == 1`, not
 * suspended).
 */
data class TieringProfile(
    val tier: Tier? = null,
    val hasViewedIntro: Boolean = false,
    val isTieringEnabled: Boolean = false,
    val serviceId: Int? = null,
    val isSuspended: Boolean = false,
)
