package com.snabbit.runner.shared.features.shift.core.data.remote.dto

import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for `GET api/v1/runners/me/emergency_logout/availability`.
 *
 * `earning_loss` drives the "Lose ₹X" consequence tile (ECPO-753) — Dart
 * parity: shown only when > 0. Remaining gamification fields
 * (`sheet_warnings`, post-action outcome) are still not decoded;
 * `ignoreUnknownKeys` on the Json instance keeps them out of our way.
 */
@Serializable
internal data class EmergencyLogoutAvailabilityDto(
    @SerialName("max_emergency_logouts") val maxEmergencyLogouts: Int = 0,
    @SerialName("emergency_logouts_taken") val emergencyLogoutsTaken: Int = 0,
    // Server-side `float | None` — parse as Double, expose as whole rupees.
    @SerialName("earning_loss") val earningLoss: Double? = null,
) {
    fun toDomain(): EmergencyLogoutAvailability = EmergencyLogoutAvailability(
        maxEmergencyLogouts = maxEmergencyLogouts,
        emergencyLogoutsTaken = emergencyLogoutsTaken,
        // Dart parity (`emergency_logout_confirmation.dart:143`): the tile
        // only renders for a positive amount, so 0/negative collapse to null.
        earningLossAmount = earningLoss?.takeIf { it > 0 }?.toInt(),
    )
}

/**
 * Request body for `POST api/v1/runners/me/emergency_logout`. Dart sends
 * `{"period_leave": bool}` — backend uses the flag to decide whether to
 * waive the red-card penalty.
 */
@Serializable
internal data class EmergencyLogoutRequestDto(
    @SerialName("period_leave") val periodLeave: Boolean,
)
