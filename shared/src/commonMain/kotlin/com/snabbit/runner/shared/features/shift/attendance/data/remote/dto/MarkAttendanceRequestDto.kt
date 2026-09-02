package com.snabbit.runner.shared.features.shift.attendance.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for the provisional-attendance endpoint. Only `mark` is sent;
 * Dart's `provisional_attendance.dart:253` posts exactly `{"mark": true}`.
 */
@Serializable
internal data class MarkProvisionalRequestDto(
    @SerialName("mark") val mark: Boolean,
)

/**
 * Wire shape for the current-day change-attendance endpoint. Always carries
 * `shift_date` alongside `mark`; the server silently no-ops the request when
 * `shift_date` is missing (verified against Dart's
 * `attendance_confirmed.dart:59` and `attendance_absent.dart:230`).
 */
@Serializable
internal data class ChangeAttendanceRequestDto(
    @SerialName("mark") val mark: Boolean,
    @SerialName("shift_date") val shiftDate: String,
)
