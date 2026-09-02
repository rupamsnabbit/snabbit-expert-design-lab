package com.snabbit.runner.shared.core.location

import kotlin.math.roundToInt

/**
 * Human label for a distance in metres:
 *  - < 1 km → integer metres ("`300 m`")
 *  - ≥ 1 km → one-decimal kilometres ("`3.2 km`")
 *
 * Rounds to the nearest metre / 0.1 km. Mirrors the Dart-side hotspot
 * distance display (`{int} m` vs `{x.x} km`).
 */
fun formatDistance(meters: Double): String {
    // Round to metres FIRST, then pick the unit. Branching on the raw double
    // rendered 999.5–999.9 m as "1000 m" — it passed the `< 1000` check, then
    // rounded up to 1000 — instead of "1.0 km".
    val m = meters.roundToInt()
    if (m < 1_000) return "$m m"
    val tenths = (m / 100.0).roundToInt()
    val whole = tenths / 10
    val frac = tenths % 10
    return "$whole.$frac km"
}
