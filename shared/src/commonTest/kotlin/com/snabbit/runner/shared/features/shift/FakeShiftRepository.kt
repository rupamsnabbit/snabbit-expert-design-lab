package com.snabbit.runner.shared.features.shift

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository

/**
 * Test fake for [ShiftRepository]. Default: every call returns `Result.Ok(Unit)`
 * (or, for `emergencyLogoutAvailability`, a default availability with 1 of 1
 * logouts left). Per-method response queues keep different domain error types
 * straight; push canned responses via [enqueueLogin] / [enqueueLogout] /
 * [enqueueEmergencyLogout] / [enqueueEmergencyLogoutAvailability] (FIFO).
 * Records each invocation in [calls] for assertion.
 */
class FakeShiftRepository : ShiftRepository {

    sealed interface Call {
        data class Login(val selfiePath: String, val lat: Double?, val lng: Double?) : Call
        data object Logout : Call
        data object EmergencyLogoutAvailability : Call
        data class EmergencyLogout(val periodLeave: Boolean) : Call
    }

    private val loginResponses: ArrayDeque<Result<PostActionOutcome?, ShiftLoginError>> = ArrayDeque()
    private val logoutResponses: ArrayDeque<Result<PostActionOutcome?, RunnerActionError>> = ArrayDeque()
    private val emergencyLogoutResponses:
        ArrayDeque<Result<PostActionOutcome?, RunnerActionError>> = ArrayDeque()
    private val emergencyAvailabilityResponses:
        ArrayDeque<Result<EmergencyLogoutAvailability, RunnerActionError>> = ArrayDeque()
    val calls: MutableList<Call> = mutableListOf()

    /** Typed view of [calls] for tests that only care about the login arm. */
    val loginCalls: List<Call.Login> get() = calls.filterIsInstance<Call.Login>()

    /** Typed view of [calls] for tests that only care about the emergency-logout arm. */
    val emergencyLogoutCalls: List<Call.EmergencyLogout>
        get() = calls.filterIsInstance<Call.EmergencyLogout>()

    fun enqueueLogin(result: Result<PostActionOutcome?, ShiftLoginError>) {
        loginResponses.addLast(result)
    }

    fun enqueueLogout(result: Result<PostActionOutcome?, RunnerActionError>) {
        logoutResponses.addLast(result)
    }

    fun enqueueEmergencyLogout(result: Result<PostActionOutcome?, RunnerActionError>) {
        emergencyLogoutResponses.addLast(result)
    }

    fun enqueueEmergencyLogoutAvailability(
        result: Result<EmergencyLogoutAvailability, RunnerActionError>,
    ) {
        emergencyAvailabilityResponses.addLast(result)
    }

    override suspend fun shiftLogin(
        selfiePath: String,
        lat: Double?,
        lng: Double?,
    ): Result<PostActionOutcome?, ShiftLoginError> {
        calls += Call.Login(selfiePath, lat, lng)
        return loginResponses.removeFirstOrNull() ?: Result.Ok(null)
    }

    override suspend fun shiftLogout(): Result<PostActionOutcome?, RunnerActionError> {
        calls += Call.Logout
        return logoutResponses.removeFirstOrNull() ?: Result.Ok(null)
    }

    override suspend fun emergencyLogoutAvailability(): Result<EmergencyLogoutAvailability, RunnerActionError> {
        calls += Call.EmergencyLogoutAvailability
        return emergencyAvailabilityResponses.removeFirstOrNull()
            ?: Result.Ok(EmergencyLogoutAvailability(maxEmergencyLogouts = 1, emergencyLogoutsTaken = 0))
    }

    override suspend fun emergencyLogout(periodLeave: Boolean): Result<PostActionOutcome?, RunnerActionError> {
        calls += Call.EmergencyLogout(periodLeave)
        return emergencyLogoutResponses.removeFirstOrNull() ?: Result.Ok(null)
    }
}
