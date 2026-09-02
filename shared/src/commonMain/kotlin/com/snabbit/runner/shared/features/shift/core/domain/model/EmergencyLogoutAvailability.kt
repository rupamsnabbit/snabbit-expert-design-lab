package com.snabbit.runner.shared.features.shift.core.domain.model

import kotlin.math.max

/**
 * Domain view of a runner's emergency-logout entitlement. Mirrors the Dart
 * `emergency_logout/availability` payload — remaining gamification fields
 * (sheet warnings, post-action outcome) are intentionally not surfaced here.
 *
 * [remaining] clamps to zero. [available] is `remaining > 0` — backend has
 * no explicit availability flag (unlike period leave); the UI gates purely
 * on the count.
 *
 * [earningLossAmount] is the whole-rupee loss shown on the "Lose ₹X"
 * consequence tile (ECPO-753); null (absent or non-positive on the wire)
 * hides the tile — Dart parity.
 */
data class EmergencyLogoutAvailability(
    val maxEmergencyLogouts: Int,
    val emergencyLogoutsTaken: Int,
    val earningLossAmount: Int? = null,
) {
    val remaining: Int get() = max(0, maxEmergencyLogouts - emergencyLogoutsTaken)

    val available: Boolean get() = remaining > 0
}
