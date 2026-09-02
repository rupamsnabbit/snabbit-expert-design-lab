package com.snabbit.runner.shared.features.periodleave

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.features.periodleave.data.remote.dto.PeriodLeaveAvailabilityDto
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Bridge-fed period-leave availability, pushed from the Flutter side (Dart owns the
 * single `period_leave/availability` fetch; KMP does not fetch it natively — that would
 * double the API load). Secondary data for the Profile header chip: `null` means
 * absent/unknown (chip hidden), so there is no error state — a failed push just keeps
 * the last value. The reverse-refresh lives on [RunnerProfileStore]; one request
 * re-fetches both `runners/me` and period-leave.
 */
class PeriodLeaveStore(private val logger: Logger) {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val _availability = MutableStateFlow<PeriodLeaveAvailability?>(null)

    /** Latest pushed availability, or null before the first push. Replays to new collectors. */
    val availability: StateFlow<PeriodLeaveAvailability?> = _availability.asStateFlow()

    /** Non-suspending peek — null if nothing has been pushed yet. */
    fun snapshot(): PeriodLeaveAvailability? = _availability.value

    /** Dart → KMP: the raw `period_leave/availability` body. A decode failure keeps the last value. */
    fun pushPeriodLeave(rawJson: String) {
        try {
            _availability.value = json.decodeFromString<PeriodLeaveAvailabilityDto>(rawJson).toDomain()
        } catch (e: Exception) {
            logger.e(TAG, "pushPeriodLeave decode failed; keeping last value", e)
        }
    }

    private companion object {
        const val TAG = "PeriodLeaveStore"
    }
}
