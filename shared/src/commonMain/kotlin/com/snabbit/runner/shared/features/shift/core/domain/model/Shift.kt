package com.snabbit.runner.shared.features.shift.core.domain.model

/**
 * One day's shift presentation labels — BE-pre-formatted strings.
 *
 * Field names mirror BE `widget_data` keys verified in
 * `lib/widgets/attendance_flow/provisional_attendance.dart`:
 *  - [dateLabel] ← `date`
 *  - [shiftWindowLabel] ← `shift_time`
 *  - [potentialEarnLabel] ← `earning_loss_amount` reframed as upside
 *    ("You can earn ₹X"). Same number, two framings — confirmed with design.
 *  - [isSunday] ← `is_next_working_day_sunday`
 */
data class ShiftDay(
    val dateLabel: String,
    val shiftWindowLabel: String,
    val potentialEarnLabel: String?,
    val isSunday: Boolean,
    /** Canonical IST shift date (`start_date_ist`) — the only field the
     *  change-attendance endpoint reads alongside `mark`. Carried through
     *  the model so the change-attendance call has it available; null when
     *  the envelope didn't ship it (provisional/tomorrow flows). */
    val startDateIst: String? = null,
)

/**
 * Resource-shaped read model of the runner's shift state.
 * Attendance-relevant fields only this PR; hotspot / lunch / job follow.
 *
 * [optimisticAttendance] preserves a client-side mark across server lag —
 * mirrors `runner_rt_data.dart:499`. UI reads [effectiveAttendance].
 */
data class Shift(
    val attendance: AttendanceStatus,
    val optimisticAttendance: AttendanceStatus?,
    val today: ShiftDay?,
    val tomorrow: ShiftDay?,
    val canChangeAttendance: Boolean,
    val noShowRedCards: Int,
    /** True when the [today] slot actually holds a **next-day / provisional**
     *  shift — server `RUNNER_ATTENDANCE_CONFIRMED`, or `RUNNER_ATTENDANCE_ABSENT`
     *  with `type == "TOMORROW"` — rather than today's live shift. Gates the
     *  today-only chrome off the change flow (FALSE_ATTENDANCE red-card penalty
     *  + Login CTA), matching Dart's separate `attendance_confirmed.dart` /
     *  tomorrow surfaces, which key off `PROVISIONAL_MARK_ABSENT` and never show
     *  FALSE_ATTENDANCE red cards or a Login button. */
    val isProvisional: Boolean = false,
    /** True when the server requires the runner to mark tomorrow's
     *  attendance before logout (decoded from the `PA_BEFORE_LOGOUT`
     *  widget envelope). Consumers use it to auto-open the
     *  MarkTomorrowAttendance sheet. */
    val tomorrowAttendanceRequired: Boolean = false,
    /** Login hotspot details from `RUNNER_LOGIN_HOTSPOT` (`runner_rt_data.dart:694`).
     *  Non-null = runner is in the shift-login state (post-attendance, pre-login). */
    val hotspot: Hotspot? = null,
    /** End-of-shift clock label from `RUNNER_LOGOUT.widget_data.shift_end_time`
     *  (e.g. `"6:00PM"`). Powers the "Shift ends at {time}" copy on the
     *  Logout floating widget (Figma 1582:9128). */
    val shiftEndLabel: String? = null,
    /** True from shift end − 30 min (`RUNNER_WAIT_HOTSPOT.widget_data.
     *  show_logout_warning_widgets`, BE `runner/service.py`). Drives the
     *  pre-logout reminder pill — the Logout widget with a disabled CTA —
     *  while the runner is still in the searching-for-jobs phase (ECPO-819). */
    val showLogoutReminder: Boolean = false,
) {
    val effectiveAttendance: AttendanceStatus get() = optimisticAttendance ?: attendance
}

/**
 * Today's attendance value. `Pending` is UI-only (today widget exists,
 * server hasn't received a mark yet); the rest map from `attendance_type`
 * on `RUNNER_ATTENDANCE_ABSENT.widget_data` (`attendance_absent.dart:136, :326`).
 * `Present` is set by `RUNNER_ATTENDANCE_CONFIRMED`.
 */
enum class AttendanceStatus { Pending, Present, Absent, NoShow, FalseAttendance }

/**
 * Login hotspot — decoded from `RUNNER_LOGIN_HOTSPOT.widget_data`.
 *
 *  - [name] ← `address` (display name; `geo_address` is a fuller-form fallback).
 *  - [lat]/[lng]/[loginRadiusMeters] ← geofence inputs. "Reached" =
 *    GPS distance ≤ [loginRadiusMeters]. Computed at the platform layer
 *    (commonMain has no GPS); UI carries [HomeCard.Attendance] inputs that
 *    default to not-reached until plumbed.
 *  - [canLoginNow] ← `enable_login` — server's authority on whether the
 *    login action is permitted (login window open + prerequisites cleared).
 *    Gates the login CTA wherever it lives (TL/OTP card lands next slice).
 */
data class Hotspot(
    val name: String,
    val lat: Double?,
    val lng: Double?,
    val loginRadiusMeters: Int?,
    val canLoginNow: Boolean,
)
