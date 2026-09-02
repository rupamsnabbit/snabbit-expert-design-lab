package com.snabbit.runner.shared.features.shift.attendance.data

import com.snabbit.runner.shared.features.shift.attendance.data.remote.AttendanceRemoteDataSource
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.core.result.Result

/**
 * Test fake for [AttendanceRemoteDataSource]. Default behavior returns
 * `Result.Ok(Unit)` so the repository's success path can be tested without
 * setup. Use [enqueue] to push canned responses (FIFO) and assert on [calls].
 */
internal class FakeAttendanceRemoteDataSource : AttendanceRemoteDataSource {
    data class Call(val op: Op, val present: Boolean)
    enum class Op { MarkProvisional, ChangeAttendance }

    private val responses: ArrayDeque<Result<PostActionOutcome?, NetworkError>> = ArrayDeque()
    val calls: MutableList<Call> = mutableListOf()

    fun enqueue(result: Result<PostActionOutcome?, NetworkError>) {
        responses.addLast(result)
    }

    override suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, NetworkError> {
        calls += Call(Op.MarkProvisional, present)
        return responses.removeFirstOrNull() ?: Result.Ok(null)
    }

    override suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, NetworkError> {
        calls += Call(Op.ChangeAttendance, present)
        return responses.removeFirstOrNull() ?: Result.Ok(null)
    }
}
