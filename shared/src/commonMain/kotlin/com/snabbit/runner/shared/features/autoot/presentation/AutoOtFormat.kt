package com.snabbit.runner.shared.features.autoot.presentation

/**
 * Pure display formatters for Auto-OT. Deliberately self-contained in commonMain
 * (no platform formatter, no cross-feature dependency): the clock + rupee helpers
 * mirror `features/job/presentation/JobFormat` and Flutter
 * `formatTimeRange` / `formatIndianCurrency`, duplicated (a few lines each) so the
 * feature doesn't pull a dependency on the whole `job` feature.
 */

/**
 * `"8 AM - 7 PM"` from two ISO datetimes; `""` when either is missing / malformed.
 * Mirrors Flutter `AutoOtProvider.formatTimeRange` — strips a whole-hour `:00`.
 */
internal fun formatTimeRange(startTimeIso: String?, endTimeIso: String?): String {
    val start = clockTime(startTimeIso)?.replace(":00", "") ?: return ""
    val end = clockTime(endTimeIso)?.replace(":00", "") ?: return ""
    return "$start - $end"
}

/**
 * Indian-grouped rupees, mirroring Flutter `formatIndianCurrency` (en_IN, `₹`,
 * 0 decimals): `750 → "₹750"`, `1750 → "₹1,750"`, `1234567 → "₹12,34,567"`.
 * null → `""` (Flutter returns empty for a null amount).
 */
internal fun formatOtRupees(amount: Int?): String {
    amount ?: return ""
    return "₹" + groupIndian(amount)
}

/**
 * `"2026-02-07T19:45:00+05:30"` → `"7:45 PM"`, reading the ISO's own wall-clock
 * hour (India-only app; no timezone conversion). null / malformed → null.
 */
private fun clockTime(iso: String?): String? {
    if (iso == null) return null
    val t = iso.indexOf('T')
    if (t < 0 || iso.length < t + 6 || iso[t + 3] != ':') return null
    val hour = iso.substring(t + 1, t + 3).toIntOrNull() ?: return null
    val minute = iso.substring(t + 4, t + 6).toIntOrNull() ?: return null
    if (hour !in 0..23 || minute !in 0..59) return null
    val period = if (hour < 12) "AM" else "PM"
    val hour12 = if (hour % 12 == 0) 12 else hour % 12
    return "$hour12:${minute.toString().padStart(2, '0')} $period"
}

/** en_IN digit grouping: last 3 digits, then pairs (e.g. `1234567` → `12,34,567`). */
private fun groupIndian(value: Int): String {
    val sign = if (value < 0) "-" else ""
    val digits = value.toString().trimStart('-')
    if (digits.length <= 3) return sign + digits
    val lastThree = digits.substring(digits.length - 3)
    val rest = digits.substring(0, digits.length - 3)
    val groups = mutableListOf<String>()
    var i = rest.length
    while (i > 0) {
        val start = maxOf(0, i - 2)
        groups.add(0, rest.substring(start, i))
        i = start
    }
    return sign + groups.joinToString(",") + "," + lastThree
}
