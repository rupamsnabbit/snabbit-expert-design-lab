package com.snabbit.runner.shared.features.job.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Device location attached to job-action payloads (`accept_job`, `deny_job`,
 * `start_job`, `check_out`). `@Serializable` so it doubles as the request-body
 * field. Supplied by [LocationProvider] (host GPS) — `commonMain` can't read GPS.
 */
@Serializable
data class JobLocation(
    @SerialName("lat") val lat: Double,
    @SerialName("lng") val lng: Double,
)

/**
 * One row of the payout breakdown (`payout_info.breakdown[]`). Mirrors the
 * Flutter `PayoutLine` (`lib/models/payout/payout_info.dart`): the label is an
 * i18n [labelKey] with a server [labelDefault] fallback (`title.{key,default_text}`),
 * with an optional [pillText] duration chip (`pill_text`), a server [iconUrl]
 * (`icon_url`, e.g. the monsoon-bonus icon) and a [subtitle] second line
 * (`subtitle.default_text`). All three are optional and render only when present.
 */
data class PayoutBreakdownLine(
    val labelKey: String,
    val labelDefault: String?,
    val pillText: String?,
    val iconUrl: String?,
    val subtitle: String?,
    val amount: Int?,
)

/**
 * Parsed `payout_info`. The check-in line is NOT in [lines] — it's derived from
 * [checkInAmount] + [checkInTimeIso] (matching the Flutter card) and rendered as
 * the highlighted "Check In by <time>" row.
 */
data class JobPayout(
    val totalEarning: Int?,
    val lines: List<PayoutBreakdownLine>,
    val checkInAmount: Int?,
    val checkInTimeIso: String?,
)

/** Expert (cleaning) vs Cook job — drives the New-Job header glyph only. */
enum class JobCategory {
    Expert,
    Cook,
    ;

    companion object {
        /** The logged-in runner's profile `service_id` that denotes a Cook. */
        const val COOK_SERVICE_ID = 2

        /**
         * Resolves the header category from the runner's profile [serviceId]. Returns null when
         * [serviceId] is unknown (extra not supplied), so callers can fall back to the
         * envelope-derived category.
         */
        fun forServiceId(serviceId: Int?): JobCategory? = when (serviceId) {
            null -> null
            COOK_SERVICE_ID -> Cook
            else -> Expert
        }
    }
}

/**
 * The slice of a `RUNNER_NEW_JOB` `widget_data` the New-Job screen needs. Built
 * by `toJob`; amounts/flags are read tolerantly (string-or-number, missing
 * → null/false) like the Flutter `anyValueToInt`.
 */
data class NewJobModel(
    val jobId: Int?,
    val isDeniable: Boolean,
    val isLastHourJob: Boolean,
    val showDeallocationWarning: Boolean,
    val notifiedAtIso: String?,
    val timerDurationSec: Int,
    val denyRate: Int?,
    val lossAmount: Int?,
    val address: String?,
    val geoAddress: String?,
    val isLongDistance: Boolean,
    val category: JobCategory,
    val payout: JobPayout?,
)
