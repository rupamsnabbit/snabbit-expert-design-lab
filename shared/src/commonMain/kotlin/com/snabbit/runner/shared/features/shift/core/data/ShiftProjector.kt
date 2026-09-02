package com.snabbit.runner.shared.features.shift.core.data

import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.shift.core.domain.model.Hotspot
import com.snabbit.runner.shared.features.shift.core.domain.model.Shift
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftDay
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Typed read model the Home VM consumes. Decodes the four `RUNNER_ATTENDANCE_*`
 * widget envelopes into a typed [Shift]; other widgets emit `null`.
 *
 * ponytail: concrete class, no interface — matches `coreModule`. When BE ships
 * `GET /shifts/today`, rewrite this body; cards/VM/mapper unchanged.
 */
class ShiftProjector(
    private val store: RunnerStateStore,
    scope: CoroutineScope,
    private val logger: Logger,
) {
    private val _state = MutableStateFlow<Shift?>(null)
    val state: StateFlow<Shift?> = _state.asStateFlow()

    /**
     * Lifecycle phase derived from the latest widget envelope. Drives the
     * Home archetype switch (Pink hero ↔ Map sheet) in `HomeViewModel`.
     * Post-login widgets (`RUNNER_WAIT_HOTSPOT` for now; extend as more
     * post-login screens get Compose mappings) flip to SearchingForJobs.
     */
    private val _phase = MutableStateFlow(ShiftPhase.PreShift)
    val phase: StateFlow<ShiftPhase> = _phase.asStateFlow()

    /**
     * False until the store delivers its first real `current_state` envelope,
     * then latched true. Drives the Home first-load shimmer: [state]/[phase]
     * are `StateFlow`s seeded with defaults (`null` / PreShift), so a collector
     * can't tell "seeded default" from "real data" — this flag can. Keyed off
     * ANY envelope (not a mapped [Shift]) so a first envelope that maps to a
     * null Shift still counts as loaded, not stuck shimmering.
     */
    private val _hasLoaded = MutableStateFlow(false)
    val hasLoaded: StateFlow<Boolean> = _hasLoaded.asStateFlow()

    init {
        scope.launch {
            store.state.collect {
                // `toShift` reads `widget_data` through `.jsonPrimitive` helpers, which
                // THROW on a field that arrives as an object/array instead of a scalar.
                // Unguarded, one wrong-typed field escapes the collector and kills it —
                // shift state stops updating for the rest of the session (frozen home),
                // silently. `RunnerStateStore` protects the envelope; this protects the
                // fields inside it. Last good state stands.
                try {
                    _state.value = toShift(it)
                    _phase.value = toPhase(it?.widgetName)
                } catch (e: CancellationException) {
                    throw e
                } catch (t: Throwable) {
                    logger.e(TAG, "projection failed for widget `${it?.widgetName}`; keeping last good state", t)
                }
                if (it != null) _hasLoaded.value = true
            }
        }
    }

    private fun toPhase(widgetName: String?): ShiftPhase = when (widgetName) {
        "RUNNER_WAIT_HOTSPOT" -> ShiftPhase.SearchingForJobs
        // PA_BEFORE_LOGOUT and RUNNER_LOGOUT share the same map archetype:
        // the floating Logout pill is visible underneath in both. The
        // difference is the auto-opened MarkTomorrowAttendance sheet that
        // blocks interaction on PA_BEFORE_LOGOUT until attendance is marked.
        "PA_BEFORE_LOGOUT", "RUNNER_LOGOUT" -> ShiftPhase.Logout
        else -> ShiftPhase.PreShift
    }

    fun requestRefresh() = store.requestRefresh()

    /** Feature #4: arm the engine's post-action fallback after a shift action. */
    fun onPostAction(action: String) = store.onPostAction(action)

    private fun toShift(e: RunnerState?): Shift? {
        val name = e?.widgetName ?: return null
        val d = e.widgetData ?: return null
        return when (name) {
            "RUNNER_ATTENDANCE_TOMORROW" -> Shift(
                attendance = AttendanceStatus.Pending,
                optimisticAttendance = null,
                today = null,
                tomorrow = parseDay(d),
                canChangeAttendance = false,
                noShowRedCards = 0,
                hotspot = parseHotspotOrNull(d),
            )
            "RUNNER_ATTENDANCE_TODAY" -> Shift(
                attendance = AttendanceStatus.Pending,
                optimisticAttendance = null,
                today = parseDay(d),
                tomorrow = null,
                canChangeAttendance = false,
                noShowRedCards = 0,
                hotspot = parseHotspotOrNull(d),
            )
            "RUNNER_ATTENDANCE_CONFIRMED" -> Shift(
                attendance = AttendanceStatus.Present,
                optimisticAttendance = null,
                today = parseDay(d),
                tomorrow = null,
                canChangeAttendance = d.bool("change_atn"),
                noShowRedCards = 0,
                // CONFIRMED is *tomorrow's* provisional-present state — Dart's
                // `attendance_confirmed.dart:168` headline is hardcoded
                // "Tomorrow's attendance marked as". Flag it so the change flow
                // drops the today-only FALSE_ATTENDANCE penalty + Login CTA.
                isProvisional = true,
                hotspot = parseHotspotOrNull(d),
            )
            "RUNNER_ATTENDANCE_ABSENT" -> Shift(
                attendance = absentStatusFrom(d.str("attendance_type")),
                optimisticAttendance = null,
                today = parseDay(d),
                tomorrow = parseTomorrowFromAbsent(d),
                canChangeAttendance = d.bool("change_atn"),
                noShowRedCards = d.int("no_show_red_card_count"),
                // ABSENT is dual-mode — Dart `attendance_absent.dart:124` switches
                // "Tomorrow's"/"Today's" copy on `type == "TOMORROW"`. Only the
                // next-day case is provisional (no FALSE_ATTENDANCE penalty).
                isProvisional = d.str("type") == "TOMORROW",
                hotspot = parseHotspotOrNull(d),
            )
            "RUNNER_LOGIN_HOTSPOT" -> Shift(
                attendance = AttendanceStatus.Present, // implied: login phase is post-attendance
                optimisticAttendance = null,
                today = parseDayOrNull(d),
                tomorrow = null,
                // Mirrors Flutter `job_login.dart:271` — runner can still flip
                // attendance from the login screen when the server permits it.
                canChangeAttendance = d.bool("change_atn"),
                noShowRedCards = 0,
                hotspot = parseHotspotOrNull(d),
            )
            "PA_BEFORE_LOGOUT" -> Shift(
                // Same map archetype as RUNNER_LOGOUT (the Logout pill is
                // visible behind the auto-opening attendance sheet) — the
                // VM flips `tomorrowAttendanceRequired` to true so the
                // MarkTomorrowAttendance sheet auto-mounts on top.
                attendance = AttendanceStatus.Pending,
                optimisticAttendance = null,
                today = null,
                // PA_BEFORE_LOGOUT keeps TOMORROW's date in `tomorrow_date` /
                // `tomorrow_shift_time` (today's `date` / `shift_time` are
                // for the live shift window). Mirror Flutter
                // `provisional_attendance_before_logout_provider.dart:62`.
                // Same flat-field shape as RUNNER_ATTENDANCE_ABSENT so the
                // helper is shared.
                tomorrow = parseTomorrowFromAbsent(d),
                canChangeAttendance = false,
                noShowRedCards = 0,
                tomorrowAttendanceRequired = true,
                // No explicit `shift_end_time` on this envelope — derive the
                // end portion from `shift_time` ("07:50 pm - 08:00 pm" →
                // "08:00 pm") so the Logout pill underneath still reads
                // sensibly while the sheet is open.
                shiftEndLabel = shiftEndFromShiftTime(d.strOrNull("shift_time")),
                hotspot = parseHotspotOrNull(d),
            )
            "RUNNER_WAIT_HOTSPOT" -> Shift(
                // Post-login, pre-job: runner is "waiting at the hotspot" for
                // a job to land. Attendance is implicitly Present (the login
                // step already cleared it). Carries the hotspot envelope so
                // [bodyCardsFrom] can emit [HomeCard.HotspotMap] with the
                // floating "Searching for jobs nearby" widget.
                attendance = AttendanceStatus.Present,
                optimisticAttendance = null,
                today = parseDayOrNull(d),
                tomorrow = null,
                canChangeAttendance = false,
                noShowRedCards = 0,
                hotspot = parseHotspotOrNull(d),
                // ECPO-819: BE flips `show_logout_warning_widgets` true from
                // shift end − 30 min and ships `shift_end_time` alongside —
                // mirrors the old app's reminder on `wait_for_job.dart:264`.
                // Meridiem uppercased to match the shift-time header (ECPO-833 #11).
                shiftEndLabel = d.strOrNull("shift_end_time")?.let(::capitalizeMeridiem),
                showLogoutReminder = d.bool("show_logout_warning_widgets"),
            )
            "RUNNER_LOGOUT" -> Shift(
                // Post-shift wind-down. The Logout floating widget shows
                // `shift_end_time` from the envelope; hotspot is parsed so
                // the bg map stays anchored to the runner's hotspot.
                attendance = AttendanceStatus.Present,
                optimisticAttendance = null,
                today = parseDayOrNull(d),
                tomorrow = null,
                canChangeAttendance = false,
                noShowRedCards = 0,
                hotspot = parseHotspotOrNull(d),
                shiftEndLabel = d.strOrNull("shift_end_time")?.let(::capitalizeMeridiem),
            )
            else -> null
        }
    }

    /** `attendance_type` 3-way discriminator — `attendance_absent.dart:136, :326`. */
    private fun absentStatusFrom(type: String): AttendanceStatus = when (type) {
        "NO_SHOW" -> AttendanceStatus.NoShow
        "FALSE_ATTENDANCE" -> AttendanceStatus.FalseAttendance
        else -> AttendanceStatus.Absent // includes empty/missing → default Absent
    }

    /**
     * Figma 318-43671 — when BE adds the next-day shift to the absent
     * envelope, it follows the `PA_BEFORE_LOGOUT` flat-fields convention
     * (`provisional_attendance_before_logout_provider.dart:62`).
     */
    private fun parseTomorrowFromAbsent(d: JsonObject): ShiftDay? {
        val date = d.strOrNull("tomorrow_date") ?: return null
        return ShiftDay(
            dateLabel = commaAfterWeekday(date),
            shiftWindowLabel = capitalizeMeridiem(d.str("tomorrow_shift_time")),
            potentialEarnLabel = null,
            isSunday = false,
            startDateIst = d.strOrNull("tomorrow_start_date_ist"),
        )
    }

    /**
     * Decode hotspot fields off any envelope that ships them. Returns null
     * only when no name source is present — covers three BE field shapes:
     *  - `RUNNER_LOGIN_HOTSPOT` ships `address` (with `geo_address` as the
     *    fuller-form fallback).
     *  - `RUNNER_WAIT_HOTSPOT` ships `hotspot_name` instead (per Flutter
     *    `wait_for_job.dart:68, :258`).
     *
     * Called from every envelope that may carry hotspot data so downstream
     * cards stay visible across phase transitions.
     */
    private fun parseHotspotOrNull(d: JsonObject): Hotspot? {
        val displayName = d.strOrNull("address")?.takeIf { it.isNotBlank() }
            ?: d.strOrNull("geo_address")?.takeIf { it.isNotBlank() }
            ?: d.strOrNull("hotspot_name")?.takeIf { it.isNotBlank() }
            ?: return null
        return Hotspot(
            name = displayName,
            lat = d.doubleOrNull("lat"),
            lng = d.doubleOrNull("lng"),
            loginRadiusMeters = d.intOrNull("login_radius"),
            canLoginNow = d.bool("enable_login"),
        )
    }

    /** `RUNNER_LOGIN_HOTSPOT` carries `date`/`shift_time` at the same level;
     *  reuse [parseDay] when present, else null. */
    private fun parseDayOrNull(d: JsonObject): ShiftDay? =
        if (d["date"] != null) parseDay(d) else null

    /**
     * Derive the end-time label from a `shift_time` window string
     * (e.g. `"07:50 pm - 08:00 pm"` → `"08:00 pm"`). Used by
     * `PA_BEFORE_LOGOUT` which doesn't ship `shift_end_time` separately
     * (whereas `RUNNER_LOGOUT` does). Null on missing / malformed input.
     */
    private fun shiftEndFromShiftTime(shiftTime: String?): String? =
        shiftTime?.substringAfter(" - ", missingDelimiterValue = "")?.takeIf { it.isNotBlank() }

    private fun parseDay(d: JsonObject) = ShiftDay(
        dateLabel = commaAfterWeekday(d.str("date")),
        shiftWindowLabel = capitalizeMeridiem(d.str("shift_time")),
        // Both fields are server-side `float | None`; kotlinx `intOrNull` rejects
        // decimals, so parse as double. Prefer `earning_loss_amount` (the
        // payouts-rule snapshot path in `_get_ming_guaranteed`); fall back to
        // `ming_amount` (the older `get_ming_by_hotspot` path) when the new
        // path returns 0/null — observed on Sunday + atypical shift-hour combos
        // where the rule snapshot misses but the hotspot lookup still resolves.
        // Hide the row only when both are 0 ("You can earn ₹0" reads worse than no row).
        potentialEarnLabel = (
            d.doubleOrNull("earning_loss_amount")?.takeIf { it > 0 }
                ?: d.doubleOrNull("ming_amount")?.takeIf { it > 0 }
        )?.toInt()?.let { "₹$it" },
        isSunday = d.bool("is_next_working_day_sunday"),
        startDateIst = d.strOrNull("start_date_ist"),
    )

    private fun JsonObject.str(k: String) = this[k]?.takeIf { it !is JsonNull }?.jsonPrimitive?.content.orEmpty()
    private fun JsonObject.strOrNull(k: String) = this[k]?.takeIf { it !is JsonNull }?.jsonPrimitive?.content
    private fun JsonObject.bool(k: String) = this[k]?.jsonPrimitive?.booleanOrNull ?: false
    private fun JsonObject.int(k: String) = this[k]?.jsonPrimitive?.intOrNull ?: 0
    private fun JsonObject.intOrNull(k: String) = this[k]?.jsonPrimitive?.intOrNull
    private fun JsonObject.doubleOrNull(k: String) =
        this[k]?.takeIf { it !is JsonNull }?.jsonPrimitive?.content?.toDoubleOrNull()

    private companion object {
        const val TAG = "ShiftProjector"
    }
}

/**
 * Uppercase the meridiem in a shift-time window string so the card header reads
 * `"08:30 AM - 08:00 PM"` (Figma 87:25340 / H2-Bold — ECPO-833 #11). BE ships
 * it lowercase; the digits already render bold via `Heading2`, so only the
 * `am`/`pm` casing is corrected. No-meridiem / already-uppercase input passes
 * through unchanged.
 *
 * Anchored on the preceding digit (optionally one space) rather than a leading
 * word boundary — the compact `7am-12pm` form has the digit flush against the
 * meridiem (no boundary), so a `\bam\b` pattern silently missed it. The digit
 * anchor also keeps `am`/`pm` inside plain words (`program`, `spam`) untouched.
 */
internal fun capitalizeMeridiem(label: String): String =
    label.replace(Regex("(?i)(\\d\\s?)([ap]m)\\b")) { it.groupValues[1] + it.groupValues[2].uppercase() }

/**
 * Comma after the weekday in a date label — BE ships `"Monday 20th July"`, the
 * card header and the change-attendance sheet read `"Monday, 20th July"`.
 * Labels that already carry the comma, or that don't start with a weekday,
 * pass through unchanged.
 */
internal fun commaAfterWeekday(label: String): String =
    label.replace(WEEKDAY_PREFIX, "$1, ")

private val WEEKDAY_PREFIX =
    Regex("^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday) ")
