package com.snabbit.runner.shared.features.periodleave.data.remote.dto

import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for `GET api/v1/runners/me/period_leave/availability`.
 *
 * Field names mirror Dart's `PeriodLeaveAvailability.fromJson` — only the
 * snake_case variants are decoded here; the camelCase aliases Dart accepts
 * are historic and not seen in production payloads.
 */
@Serializable
internal data class PeriodLeaveAvailabilityDto(
    @SerialName("max_period_leaves") val maxPeriodLeaves: Int = 0,
    @SerialName("period_leaves_taken") val periodLeavesTaken: Int = 0,
    @SerialName("available") val available: Boolean? = null,
) {
    fun toDomain(): PeriodLeaveAvailability = PeriodLeaveAvailability(
        maxPeriodLeaves = maxPeriodLeaves,
        periodLeavesTaken = periodLeavesTaken,
        availableFromBackend = available,
    )
}
