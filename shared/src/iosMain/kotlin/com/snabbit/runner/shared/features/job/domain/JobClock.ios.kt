package com.snabbit.runner.shared.features.job.domain

import kotlinx.cinterop.ExperimentalForeignApi
import kotlin.math.roundToLong
import platform.Foundation.NSCalendar
import platform.Foundation.NSDate
import platform.Foundation.NSISO8601DateFormatWithFractionalSeconds
import platform.Foundation.NSISO8601DateFormatWithInternetDateTime
import platform.Foundation.NSISO8601DateFormatter
import platform.Foundation.dateByAddingTimeInterval
import platform.Foundation.timeIntervalSince1970

/**
 * iOS [JobClock] — `NSISO8601DateFormatter`. The backend sends timestamps BOTH with and without
 * fractional seconds (e.g. `2024-11-28T06:02:29.107097+05:30`), and a formatter's option set is
 * fixed, so we keep two: one with `.withFractionalSeconds`, one with the plain internet date-time
 * form, and try fractional first then fall back. Parse failures → null.
 *
 * NOTE: not compile-verified in this environment (the iOS target can't resolve
 * the `koin-core-iosarm64` KLIB against the local Kotlin-Native prebuilt — an
 * ABI skew unrelated to this code). Kept minimal/standard for that reason.
 */
@OptIn(ExperimentalForeignApi::class)
actual fun systemJobClock(): JobClock = object : JobClock {
    // Allocated once (this clock is a Koin single); NSISO8601DateFormatter isn't documented
    // thread-safe, and all callers run on the ViewModel scope, so single-thread use holds.
    private val isoFractional = NSISO8601DateFormatter().apply {
        formatOptions = NSISO8601DateFormatWithInternetDateTime or NSISO8601DateFormatWithFractionalSeconds
    }
    private val isoPlain = NSISO8601DateFormatter()

    override fun nowMillis(): Long = (NSDate().timeIntervalSince1970 * 1000.0).roundToLong()

    override fun parseEpochMillis(iso: String): Long? {
        // Fractional first (superset), then the plain form for timestamps without a fraction.
        val date = isoFractional.dateFromString(iso) ?: isoPlain.dateFromString(iso) ?: return null
        return (date.timeIntervalSince1970 * 1000.0).roundToLong()
    }

    override fun epochForLocalTimeToday(minutesOfDay: Int): Long {
        val startOfDay = NSCalendar.currentCalendar.startOfDayForDate(NSDate())
        val deadline = startOfDay.dateByAddingTimeInterval((minutesOfDay * 60).toDouble())
        return (deadline.timeIntervalSince1970 * 1000.0).roundToLong()
    }
}
