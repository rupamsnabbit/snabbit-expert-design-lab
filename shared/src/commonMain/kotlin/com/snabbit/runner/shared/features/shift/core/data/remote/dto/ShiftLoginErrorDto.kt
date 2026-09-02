package com.snabbit.runner.shared.features.shift.core.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * Mirror of the BE's error envelope for the shift-login endpoint. The wire
 * shape (see Dart `custom_error.dart:16` mapping `code` and `selfie_preview.dart:333`
 * comparing it to `AppStrings.retakeSelfie == "SELFIE_VALIDATION_ERROR"`):
 *
 * ```
 * { "message": "…", "errors": [ { "code": "SELFIE_VALIDATION_ERROR",
 *                                  "message": "…",
 *                                  "data": ["uniform_not_detected", …] } ] }
 * ```
 *
 * `data` is intentionally a [JsonElement] — the BE has shipped both
 * `{"codes": [...]}` and a bare `[...]`; the parser handles both shapes.
 */
@Serializable
internal data class ShiftLoginErrorEnvelope(
    val message: String? = null,
    val errors: List<ShiftLoginErrorItem> = emptyList(),
)

@Serializable
internal data class ShiftLoginErrorItem(
    @SerialName("code") val code: String? = null,
    val message: String? = null,
    val data: JsonElement? = null,
)
