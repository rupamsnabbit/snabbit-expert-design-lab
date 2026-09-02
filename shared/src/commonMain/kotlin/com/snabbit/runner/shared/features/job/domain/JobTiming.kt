package com.snabbit.runner.shared.features.job.domain

import com.snabbit.runner.shared.features.job.domain.model.NewJobModel

data class Countdown(val remainingSeconds: Int, val totalSeconds: Int)

/**
 * [remainingSeconds] / [totalSeconds] drive the footer countdown + progress and are seeded from the
 * job's `start_time`. [isBonusForfeited] is a SEPARATE concern — the check-in *bonus* deadline
 * (`check_in_time`) has passed — tracked independently so the earnings card / instrumentation don't
 * flip at `start_time` (a job's start can pass while the bonus window is still open, and vice-versa).
 */
data class CheckInCountdown(val remainingSeconds: Int, val totalSeconds: Int, val isBonusForfeited: Boolean)

/** Pure countdown calculations for the job lifecycle, seeded once per envelope. */
object JobTiming {

    private const val HALF_DAY_MILLIS = 12L * 60 * 60 * 1000
    private const val DAY_MILLIS = 24L * 60 * 60 * 1000

    /** Accept window: notified_at (or now) + timer_duration; clamped to [0, total]. */
    fun acceptCountdown(model: NewJobModel, clock: JobClock): Countdown {
        val total = model.timerDurationSec
        val start = model.notifiedAtIso?.let { clock.parseEpochMillis(it) } ?: clock.nowMillis()
        val deadline = start + total * 1000L
        val remaining = ((deadline - clock.nowMillis()) / 1000L).coerceIn(0L, total.toLong()).toInt()
        return Countdown(remaining, total)
    }

    /**
     * Check-in countdown from the deadline's IST TIME-OF-DAY anchored to TODAY — NOT the timestamp's
     * absolute instant. The deadline's date is nominal/unreliable (the backend ships far-future
     * placeholder dates), so anchoring to the real date would count down days instead of hours; only the
     * time-of-day is meaningful. The time-of-day IS taken offset-aware ([isoInstantIstMinutes] applies
     * `Z` / `±HH:MM` and renders IST), so a UTC payload (e.g. `…T20:57:00Z` = 02:27 IST) is still handled
     * correctly — the earlier version read raw wall-clock and assumed IST, wrong by 5½ h for UTC.
     *
     * A today-anchor more than half a day in the past is really tomorrow's occurrence (a promise just
     * after midnight), so it rolls forward a day rather than reading as expired; a genuinely just-elapsed
     * deadline stays past. Counts to `start_time` (the job's scheduled start — matching the Flutter
     * check-in dial in `job_accepted.dart`), NOT `checkin_promise`; `start_time` in the check-in envelope
     * is a 12-hour wall-clock string ("10:00 am"), so it is parsed as such (an ISO `start_time` is also
     * tolerated), falling back to the bonus time. Remaining goes negative once past; window =
     * notified_at .. deadline (0 when unknown). Null when there is no parseable deadline.
     *
     * `isBonusForfeited` is computed separately from the BONUS deadline ([checkInBonusIso] =
     * `check_in_time`) — NOT the start_time countdown — so a start that has already elapsed doesn't
     * wrongly strike the still-earnable check-in bonus (and its instrumentation).
     */
    fun checkInCountdown(
        startTimeClock: String?,
        checkInBonusIso: String?,
        notifiedAtIso: String?,
        clock: JobClock,
    ): CheckInCountdown? {
        // Timer target = start_time (wall-clock "10:00 am"), then an ISO start_time, then the bonus
        // deadline so a missing/malformed start_time never leaves the runner with no countdown.
        val deadlineMinutes = clockTimeIstMinutes(startTimeClock)
            ?: isoInstantIstMinutes(startTimeClock)
            ?: isoInstantIstMinutes(checkInBonusIso)
            ?: return null
        var deadline = clock.epochForLocalTimeToday(deadlineMinutes)
        // A deadline whose today-anchor sits more than half a day behind now belongs to tomorrow
        // (promised just after midnight) — roll it forward so it counts down instead of reading past.
        val rolledToNextDay = deadline < clock.nowMillis() - HALF_DAY_MILLIS
        if (rolledToNextDay) deadline += DAY_MILLIS
        val remaining = ((deadline - clock.nowMillis()) / 1000L).toInt()
        val startMinutes = isoInstantIstMinutes(notifiedAtIso)
        // Match the roll on the deadline side so the notified_at .. deadline window spans midnight too.
        val deadlineForWindow = if (rolledToNextDay) deadlineMinutes + MINUTES_PER_DAY else deadlineMinutes
        val total = if (startMinutes != null && deadlineForWindow > startMinutes) {
            (deadlineForWindow - startMinutes) * 60
        } else {
            0
        }
        // Bonus-forfeit tracks the check-in BONUS deadline (check_in_time) on its own — decoupled
        // from the start_time countdown above. No bonus deadline → nothing to forfeit.
        val bonusForfeited = checkInBonusIso?.let { deadlinePast(it, clock) } ?: false
        return CheckInCountdown(remainingSeconds = remaining, totalSeconds = total, isBonusForfeited = bonusForfeited)
    }

    /** True iff [iso]'s IST time-of-day (anchored to today, same next-day roll as the countdown) is at/behind now. */
    private fun deadlinePast(iso: String, clock: JobClock): Boolean {
        val minutes = isoInstantIstMinutes(iso) ?: return false
        var deadline = clock.epochForLocalTimeToday(minutes)
        if (deadline < clock.nowMillis() - HALF_DAY_MILLIS) deadline += DAY_MILLIS
        return clock.nowMillis() >= deadline
    }

    /** Remaining to end_time (negative once past); total = duration·60. */
    fun inProgressCountdown(endTimeIso: String?, durationMinutes: Int?, clock: JobClock): Countdown {
        val total = ((durationMinutes ?: 0) * 60).coerceAtLeast(0)
        val remaining = endTimeIso
            ?.let { clock.parseEpochMillis(it) }
            ?.let { ((it - clock.nowMillis()) / 1000L).toInt() }
            ?: 0
        return Countdown(remaining, total)
    }
}

/** IST is UTC+05:30 with no DST, so a fixed offset renders the India-only app's local time. */
private const val IST_OFFSET_MINUTES = 5 * 60 + 30
private const val MINUTES_PER_DAY = 24 * 60

/**
 * Minutes-of-day (0..1439) in IST for the instant an ISO datetime denotes — the offset-aware analogue of
 * a bare wall-clock read. Reads the `HH:MM` after `T` and the trailing zone, converts to UTC, then to IST.
 * Zone forms: `Z`/`z` → 0, `±HH:MM` / `±HHMM` / `±HH`, or none → assumed already IST (offset-less strings
 * are left unchanged). Null when malformed. Lives in the domain so both the check-in countdown and the
 * `formatIsoClockTime` label share ONE offset-aware conversion; the DATE is intentionally ignored (see
 * [JobTiming.checkInCountdown]).
 */
internal fun isoInstantIstMinutes(iso: String?): Int? {
    if (iso == null) return null
    val t = iso.indexOf('T')
    if (t < 0 || iso.length < t + 6 || iso[t + 3] != ':') return null
    val hour = iso.substring(t + 1, t + 3).toIntOrNull() ?: return null
    val minute = iso.substring(t + 4, t + 6).toIntOrNull() ?: return null
    if (hour !in 0..23 || minute !in 0..59) return null
    val offsetMinutes = isoZoneOffsetMinutes(iso, t + 6) ?: return null
    val istMinutes = (hour * 60 + minute) - offsetMinutes + IST_OFFSET_MINUTES
    return ((istMinutes % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
}

/**
 * Minutes-of-day (0..1439) for a 12-hour wall-clock string like `"10:00 am"` / `"7:30 PM"` — the format
 * the check-in envelope's `start_time` uses (a bare IST time-of-day, NOT ISO; see `runner_rt_data.dart`
 * sample envelopes). Mirrors Flutter's `DateFormat("h:mm a")` parse in `job_accepted.dart`.
 * Case-insensitive am/pm, optional leading zero, single space before the meridiem. Null when malformed
 * (e.g. an ISO string, which has no am/pm suffix — the caller then tries [isoInstantIstMinutes]).
 */
internal fun clockTimeIstMinutes(clock: String?): Int? {
    if (clock == null) return null
    val s = clock.trim().lowercase()
    val isPm = s.endsWith("pm")
    if (!isPm && !s.endsWith("am")) return null
    val timePart = s.dropLast(2).trim()
    val colon = timePart.indexOf(':')
    if (colon <= 0) return null
    val hour12 = timePart.substring(0, colon).trim().toIntOrNull() ?: return null
    val minute = timePart.substring(colon + 1).trim().toIntOrNull() ?: return null
    if (hour12 !in 1..12 || minute !in 0..59) return null
    val hour24 = when {
        isPm && hour12 != 12 -> hour12 + 12 // 1..11 PM → 13..23
        !isPm && hour12 == 12 -> 0 // 12 AM → 00
        else -> hour12 // 12 PM stays 12; 1..11 AM unchanged
    }
    return hour24 * 60 + minute
}

/**
 * Zone offset (minutes east of UTC) parsed from [iso] starting at [from] (just past `HH:MM`): the first
 * `Z`/`z`/`+`/`-` marks it (`+05:30`, `+0530`, `-08:00`, `+05`); none found → IST (the offset-less
 * default). Malformed → null.
 */
private fun isoZoneOffsetMinutes(iso: String, from: Int): Int? {
    var i = from
    while (i < iso.length) {
        when (val c = iso[i]) {
            'Z', 'z' -> return 0
            '+', '-' -> {
                val digits = iso.substring(i + 1).replace(":", "")
                if (digits.length < 2) return null
                val oh = digits.substring(0, 2).toIntOrNull() ?: return null
                val om = if (digits.length >= 4) digits.substring(2, 4).toIntOrNull() ?: return null else 0
                if (oh !in 0..23 || om !in 0..59) return null
                return (if (c == '-') -1 else 1) * (oh * 60 + om)
            }
        }
        i++
    }
    return IST_OFFSET_MINUTES
}
