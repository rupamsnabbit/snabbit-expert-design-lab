package com.snabbit.runner.shared.features.shift.lunch.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError

/**
 * Domain port for the in-shift break write-actions. A peer of `ShiftRepository`
 * inside the shift module (breaks are a shift-lifecycle concern) — kept separate
 * so the selfie-heavy login/logout contract stays focused.
 *
 * All three endpoints return no structured validation body, so failures collapse
 * to the generic [RunnerActionError] status buckets (same mapping
 * `ShiftRepositoryImpl.toLogoutError` uses) — the UI only needs them to pick a
 * snackbar string + retry policy.
 */
interface LunchRepository {
    /** `POST api/v1/runners/me/lunch/accept` — runner accepts the break offer. */
    suspend fun acceptLunch(): Result<Unit, RunnerActionError>

    /** `POST api/v1/runners/me/lunch/deny` — runner declines the break offer. */
    suspend fun denyLunch(): Result<Unit, RunnerActionError>

    /**
     * `POST api/v1/runners/me/break/end` — runner ends the active break.
     * Coords are attached when available ([lat]/[lng] non-null); a denied /
     * disabled / timed-out GPS fix sends without them rather than blocking the
     * action (Flutter `LunchHttp.runnersMeBreakEnd` parity).
     */
    suspend fun endBreak(lat: Double?, lng: Double?): Result<Unit, RunnerActionError>
}
