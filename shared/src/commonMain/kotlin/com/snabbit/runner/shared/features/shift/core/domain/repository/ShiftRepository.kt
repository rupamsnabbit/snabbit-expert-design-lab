package com.snabbit.runner.shared.features.shift.core.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError

/**
 * Domain port for runner shift-lifecycle actions. Lives in `domain` so use
 * cases never reach into the data layer; the production implementation in
 * `data/repository/` translates the data-layer `NetworkError` into domain
 * error types (rich [ShiftLoginError] for login because the BE returns
 * structured selfie-validation codes; generic [RunnerActionError] for the
 * empty-body shift logout and the two emergency-logout calls).
 */
interface ShiftRepository {
    /**
     * Upload [selfiePath] as a multipart `file` part to
     * `POST /api/v1/runners/me/shift/login?lat=&lng=`. Both [lat] and [lng]
     * may be null when the device's location is unavailable — the call site
     * (and Dart parity) treats this as "send without coords" rather than a
     * hard error.
     */
    suspend fun shiftLogin(
        selfiePath: String,
        lat: Double?,
        lng: Double?,
    ): Result<PostActionOutcome?, ShiftLoginError>

    /**
     * End the runner's current shift. Backend transitions to
     * `RUNNER_SEE_YOU_TOMORROW` on success — caller refreshes
     * `current_state` to pick up the new widget envelope.
     */
    suspend fun shiftLogout(): Result<PostActionOutcome?, RunnerActionError>

    /**
     * Read the runner's emergency-logout entitlement. Gamification fields
     * (sheet warnings, earning loss) are not included — they ship as a
     * separate PR.
     */
    suspend fun emergencyLogoutAvailability(): Result<EmergencyLogoutAvailability, RunnerActionError>

    /**
     * Emergency-end the runner's current shift. When [periodLeave] is true,
     * backend waives the red-card penalty by deducting one period leave
     * instead — caller is responsible for verifying eligibility BEFORE the
     * call (period-leave remaining > 0). Caller refreshes `current_state`
     * post-success.
     *
     * Returns the decoded gamification [PostActionOutcome] from the response
     * body when present (drives the reward/penalty popup or the waiver sheet),
     * or null when the response carries none.
     */
    suspend fun emergencyLogout(periodLeave: Boolean): Result<PostActionOutcome?, RunnerActionError>
}
