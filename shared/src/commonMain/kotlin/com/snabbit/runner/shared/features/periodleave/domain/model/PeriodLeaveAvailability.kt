package com.snabbit.runner.shared.features.periodleave.domain.model

import kotlin.math.max

/**
 * Domain view of a runner's period-leave entitlement. Mirrors the Dart
 * `PeriodLeaveAvailability` model so behaviour stays identical across stacks
 * during the strangler migration:
 *  - [remaining] clamps to zero (BE can send `taken > max` historically),
 *  - [available] honours an explicit backend flag and falls back to
 *    `remaining > 0` when the flag is null.
 *
 * Reused by emergency-logout and attendance — period leave isn't owned by
 * either feature, hence its own module.
 */
data class PeriodLeaveAvailability(
    val maxPeriodLeaves: Int,
    val periodLeavesTaken: Int,
    val availableFromBackend: Boolean? = null,
) {
    val remaining: Int get() = max(0, maxPeriodLeaves - periodLeavesTaken)

    val available: Boolean get() = availableFromBackend ?: (remaining > 0)
}
