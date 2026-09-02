package com.snabbit.runner.shared.features.pan.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Request body for `POST verification/pan/update` — mirrors Dart's `{pan_number}`. */
@Serializable
internal data class PanUpdateRequestDto(
    @SerialName("pan_number") val panNumber: String,
)
