package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.job.domain.isoInstantIstMinutes

/** Indian-rupee display, e.g. `150` → "₹150" (null → "₹0"). */
internal fun formatRupees(amount: Int?): String = "₹${amount ?: 0}"

/** Seconds → "m:ss" (e.g. 83 → "1:23"). Negatives clamp to "0:00". */
internal fun formatMmSs(totalSeconds: Int): String {
    val s = totalSeconds.coerceAtLeast(0)
    return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
}

/**
 * `2026-06-27T19:45:00+05:30` (or the equivalent `…T14:15:00Z`) → "7:45 PM", rendered in IST.
 * Offset-aware via [isoInstantIstMinutes] (shared with the check-in countdown): the ISO zone
 * (`Z` / `±HH:MM` / `±HHMM`, or none → assumed already IST) is applied, then shown in IST (UTC+05:30).
 * So an IST-offset payload and the equivalent UTC payload render the SAME wall-clock — the display no
 * longer breaks if the backend sends UTC. Only the time-of-day is used (the date is irrelevant for a
 * clock label). Null / malformed → null.
 */
internal fun formatIsoClockTime(iso: String?): String? {
    val minutesOfDay = isoInstantIstMinutes(iso) ?: return null
    val hour = minutesOfDay / 60
    val minute = minutesOfDay % 60
    val period = if (hour < 12) "AM" else "PM"
    val hour12 = if (hour % 12 == 0) 12 else hour % 12
    return "$hour12:${minute.toString().padStart(2, '0')} $period"
}
