package com.snabbit.runner.shared.features.kavach.shield.data.remote

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * `GET api/v1/runners/me` — shield slice only. `safety_shield` sits at the JSON root (sibling of
 * `user`; verified user_profile.dart:213/879/1008). `ignoreUnknownKeys` drops the rest of the
 * (large) runner profile — Kavach needs only this block.
 */
@Serializable
data class RunnerMeDto(
    @SerialName("safety_shield") val safetyShield: SafetyShieldDto? = null,
)

@Serializable
data class SafetyShieldDto(
    val enabled: Boolean = false,
    // null != false: a null decision still needs the consent prompt (parity with Dart consentGiven).
    @SerialName("consent_given") val consentGiven: Boolean? = null,
    @SerialName("consent_at") val consentAt: String? = null,
)
