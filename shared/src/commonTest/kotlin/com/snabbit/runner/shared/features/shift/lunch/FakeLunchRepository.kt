package com.snabbit.runner.shared.features.shift.lunch

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.shift.lunch.domain.repository.LunchRepository

/**
 * Test fake for [LunchRepository]. Default: every call returns `Result.Ok(Unit)`.
 * Per-method response queues (FIFO) let tests stage specific outcomes via
 * [enqueueAccept] / [enqueueDeny] / [enqueueEndBreak]. Each invocation is
 * recorded in [calls] for assertion (end-break also records the coords passed).
 */
class FakeLunchRepository : LunchRepository {

    sealed interface Call {
        data object Accept : Call
        data object Deny : Call
        data class EndBreak(val lat: Double?, val lng: Double?) : Call
    }

    private val acceptResponses: ArrayDeque<Result<Unit, RunnerActionError>> = ArrayDeque()
    private val denyResponses: ArrayDeque<Result<Unit, RunnerActionError>> = ArrayDeque()
    private val endBreakResponses: ArrayDeque<Result<Unit, RunnerActionError>> = ArrayDeque()
    val calls: MutableList<Call> = mutableListOf()

    /** Typed view of [calls] for tests that only care about the end-break arm. */
    val endBreakCalls: List<Call.EndBreak> get() = calls.filterIsInstance<Call.EndBreak>()

    fun enqueueAccept(result: Result<Unit, RunnerActionError>) {
        acceptResponses.addLast(result)
    }

    fun enqueueDeny(result: Result<Unit, RunnerActionError>) {
        denyResponses.addLast(result)
    }

    fun enqueueEndBreak(result: Result<Unit, RunnerActionError>) {
        endBreakResponses.addLast(result)
    }

    override suspend fun acceptLunch(): Result<Unit, RunnerActionError> {
        calls += Call.Accept
        return acceptResponses.removeFirstOrNull() ?: Result.Ok(Unit)
    }

    override suspend fun denyLunch(): Result<Unit, RunnerActionError> {
        calls += Call.Deny
        return denyResponses.removeFirstOrNull() ?: Result.Ok(Unit)
    }

    override suspend fun endBreak(lat: Double?, lng: Double?): Result<Unit, RunnerActionError> {
        calls += Call.EndBreak(lat, lng)
        return endBreakResponses.removeFirstOrNull() ?: Result.Ok(Unit)
    }
}
