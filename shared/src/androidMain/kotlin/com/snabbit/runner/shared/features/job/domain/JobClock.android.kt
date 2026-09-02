package com.snabbit.runner.shared.features.job.domain

import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId

/**
 * Android [JobClock] — `java.time` (already used elsewhere in `:shared`, e.g.
 * `PlatformModule`'s `NowIso`). [OffsetDateTime.parse] handles the offset form
 * (`…+05:30`); [Instant.parse] handles the `Z` form. Parse failures → null
 * (the ViewModel then falls back to a mount-relative countdown).
 */
actual fun systemJobClock(): JobClock = object : JobClock {
    override fun nowMillis(): Long = System.currentTimeMillis()

    override fun parseEpochMillis(iso: String): Long? = try {
        OffsetDateTime.parse(iso).toInstant().toEpochMilli()
    } catch (_: Exception) {
        try {
            Instant.parse(iso).toEpochMilli()
        } catch (_: Exception) {
            null
        }
    }

    override fun epochForLocalTimeToday(minutesOfDay: Int): Long {
        val zone = ZoneId.systemDefault()
        return LocalDate.now(zone)
            .atStartOfDay(zone)
            .plusMinutes(minutesOfDay.toLong())
            .toInstant()
            .toEpochMilli()
    }
}
