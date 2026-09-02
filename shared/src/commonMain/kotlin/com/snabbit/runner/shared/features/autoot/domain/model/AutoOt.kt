package com.snabbit.runner.shared.features.autoot.domain.model

/**
 * Auto-OT (Auto Overtime) domain models — a 1:1 port of Flutter
 * `lib/models/auto_ot/auto_ot_models.dart`, kept pure (no serialization; the
 * DTO layer maps wire JSON → these).
 *
 * Timings are carried as raw ISO-8601 strings and formatted as wall-clock in
 * `AutoOtFormat` — India-only app, so no timezone math is needed in commonMain.
 * This mirrors how `features/shift` `Shift` carries BE-preformatted label strings.
 */

/**
 * Post-shift overtime vs pre-shift early-start. Mirrors Flutter `OtType`
 * (`enums.dart:943`); [wireValue] is the BE `ot_type` string. The entry names
 * (`EndOt` / `StartOt`) double as the analytics `ot_type` value (Flutter parity).
 */
enum class OtType(val wireValue: String) {
    EndOt("END_OT"),
    StartOt("START_OT"),
    ;

    companion object {
        /** Flutter `OtType.fromKey` — unknown / absent → [EndOt] (back-compat default). */
        fun fromKey(key: String?): OtType = entries.firstOrNull { it.wireValue == key } ?: EndOt
    }
}

/**
 * Reason posted to the reject endpoint as `rejection_reason`. [apiValue] matches
 * Flutter `AutoOtDenyReason.toString()`.
 */
enum class AutoOtDenyReason(val apiValue: String) {
    REJECTED("REJECTED"),
    CANCELLED_DUE_TO_JOB_ASSIGNMENT("CANCELLED_DUE_TO_JOB_ASSIGNMENT"),
    DISMISSED("DISMISSED"),
}

/**
 * Shift timing + earnings.
 *  - [startTimeIso] / [endTimeIso] ← `start_time` / `end_time` (ISO-8601)
 *  - [ming] ← `ming` (minimum-guarantee earnings)
 *  - [durationHours] ← `duration` (extra hours; OT shift only)
 */
data class ShiftDetails(
    val startTimeIso: String?,
    val endTimeIso: String?,
    val ming: Double?,
    val durationHours: Int?,
)

/**
 * Optional server-driven status chip (e.g. "Only for today"). Colors are raw hex
 * strings (`bg_color` / `text_color`), resolved to DS colors at the UI edge.
 */
data class AutoOtStatusChip(
    val icon: String?,
    val title: String?,
    val bgColorHex: String?,
    val textColorHex: String?,
)

/**
 * A full Auto-OT offer. [requestId] identifies the request for accept/reject;
 * [expiryDurationMinutes] ← `expiry_duration` drives the client-side expiry timer.
 */
data class AutoOtDetails(
    val requestId: Int?,
    val otType: OtType,
    val regularShift: ShiftDetails?,
    val otShift: ShiftDetails?,
    val expiryDurationMinutes: Int?,
    val status: AutoOtStatusChip?,
) {
    /**
     * The offer is presentable only with an id AND both shifts — mirrors the Flutter
     * `initializeFromCurrentState` guard (`regularShift == null || otShift == null → return`).
     */
    val isComplete: Boolean
        get() = requestId != null && regularShift != null && otShift != null
}
