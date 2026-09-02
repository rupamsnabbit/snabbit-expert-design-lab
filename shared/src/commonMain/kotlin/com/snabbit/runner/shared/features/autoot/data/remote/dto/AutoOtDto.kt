package com.snabbit.runner.shared.features.autoot.data.remote.dto

import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtStatusChip
import com.snabbit.runner.shared.features.autoot.domain.model.OtType
import com.snabbit.runner.shared.features.autoot.domain.model.ShiftDetails
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape of the backend `auto_ot` object. Used in two places:
 *  - the START_OT response body (`AutoOtRemoteDataSource.requestStartOt`), and
 *  - the `widget_data["auto_ot"]` slice of the current-state envelope
 *    (decoded by `AutoOtCoordinator`).
 *
 * `@SerialName`s mirror Flutter `AutoOtDetails.fromJson`. Always decode with a
 * lenient, unknown-key-ignoring `Json` (the envelope's long field tail).
 */
@Serializable
internal data class AutoOtDto(
    @SerialName("request_id") val requestId: Int? = null,
    @SerialName("ot_type") val otType: String? = null,
    @SerialName("regular_shift") val regularShift: ShiftDetailsDto? = null,
    @SerialName("ot_shift") val otShift: ShiftDetailsDto? = null,
    @SerialName("expiry_duration") val expiryDuration: Int? = null,
    @SerialName("status") val status: AutoOtStatusDto? = null,
) {
    fun toDomain(): AutoOtDetails = AutoOtDetails(
        requestId = requestId,
        otType = OtType.fromKey(otType),
        regularShift = regularShift?.toDomain(),
        otShift = otShift?.toDomain(),
        expiryDurationMinutes = expiryDuration,
        status = status?.toDomain(),
    )
}

/** `duration` decoded as Double to tolerate BE `int | float` (Flutter `anyValueToInt`). */
@Serializable
internal data class ShiftDetailsDto(
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("end_time") val endTime: String? = null,
    @SerialName("ming") val ming: Double? = null,
    @SerialName("duration") val duration: Double? = null,
) {
    fun toDomain(): ShiftDetails = ShiftDetails(
        startTimeIso = startTime,
        endTimeIso = endTime,
        ming = ming,
        durationHours = duration?.toInt(),
    )
}

@Serializable
internal data class AutoOtStatusDto(
    @SerialName("icon") val icon: String? = null,
    @SerialName("title") val title: String? = null,
    @SerialName("bg_color") val bgColor: String? = null,
    @SerialName("text_color") val textColor: String? = null,
) {
    fun toDomain(): AutoOtStatusChip = AutoOtStatusChip(
        icon = icon,
        title = title,
        bgColorHex = bgColor,
        textColorHex = textColor,
    )
}
