package com.snabbit.runner.shared.features.shift.attendance.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome

/**
 * Domain port for the runner's attendance write actions. Lives in `domain` so
 * use cases never reach into the data layer; the production implementation in
 * `data/repository/` translates the data-layer `NetworkError` into
 * [RunnerActionError].
 */
interface AttendanceRepository {
    suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, RunnerActionError>
    /**
     * Flip current-day attendance. [shiftDateIst] is the `start_date_ist` the
     * server returned in the envelope — required alongside `mark` (Dart's
     * `JobHttp.changeAttendance` always sends both). Omitting it makes the
     * backend silently no-op the request.
     */
    suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, RunnerActionError>
}
