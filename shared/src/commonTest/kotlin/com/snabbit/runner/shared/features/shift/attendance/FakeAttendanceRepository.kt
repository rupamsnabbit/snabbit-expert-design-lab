package com.snabbit.runner.shared.features.shift.attendance

import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.attendance.domain.repository.AttendanceRepository
import com.snabbit.runner.shared.core.result.Result

/**
 * Test fake for [AttendanceRepository]. Default: every call returns
 * `Result.Ok(Unit)`. Push canned responses via [enqueue] (FIFO); when the
 * queue is empty, falls back to the default success. Records each invocation
 * in [calls] for assertion.
 */
class FakeAttendanceRepository : AttendanceRepository {
    data class Call(val op: Op, val present: Boolean, val shiftDateIst: String? = null)
    enum class Op { MarkProvisional, ChangeAttendance }

    private val responses: ArrayDeque<Result<PostActionOutcome?, RunnerActionError>> = ArrayDeque()
    val calls: MutableList<Call> = mutableListOf()

    fun enqueue(result: Result<PostActionOutcome?, RunnerActionError>) {
        responses.addLast(result)
    }

    override suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, RunnerActionError> {
        calls += Call(Op.MarkProvisional, present)
        return responses.removeFirstOrNull() ?: Result.Ok(null)
    }

    override suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, RunnerActionError> {
        calls += Call(Op.ChangeAttendance, present, shiftDateIst)
        return responses.removeFirstOrNull() ?: Result.Ok(null)
    }
}
