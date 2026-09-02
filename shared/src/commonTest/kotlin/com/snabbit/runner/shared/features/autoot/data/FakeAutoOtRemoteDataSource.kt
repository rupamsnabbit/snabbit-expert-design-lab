package com.snabbit.runner.shared.features.autoot.data

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.autoot.data.remote.AutoOtRemoteDataSource
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails

/**
 * Deterministic fake for [AutoOtRemoteDataSource] — records [calls] and returns
 * canned results (FIFO via `enqueue*`; defaults to success / no-offer). Mirrors
 * `FakeAttendanceRemoteDataSource`.
 */
internal class FakeAutoOtRemoteDataSource : AutoOtRemoteDataSource {
    data class Call(val op: Op, val requestId: Int?, val reason: AutoOtDenyReason?)
    enum class Op { Accept, Reject, RequestStartOt }

    val calls: MutableList<Call> = mutableListOf()
    var startOtResult: Result<AutoOtDetails?, NetworkError> = Result.Ok(null)

    private val acceptResponses: ArrayDeque<Result<Unit, NetworkError>> = ArrayDeque()
    private val rejectResponses: ArrayDeque<Result<Unit, NetworkError>> = ArrayDeque()

    fun enqueueAccept(result: Result<Unit, NetworkError>) { acceptResponses.addLast(result) }
    fun enqueueReject(result: Result<Unit, NetworkError>) { rejectResponses.addLast(result) }

    override suspend fun accept(requestId: Int): Result<Unit, NetworkError> {
        calls += Call(Op.Accept, requestId, null)
        return acceptResponses.removeFirstOrNull() ?: Result.Ok(Unit)
    }

    override suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, NetworkError> {
        calls += Call(Op.Reject, requestId, reason)
        return rejectResponses.removeFirstOrNull() ?: Result.Ok(Unit)
    }

    override suspend fun requestStartOt(): Result<AutoOtDetails?, NetworkError> {
        calls += Call(Op.RequestStartOt, null, null)
        return startOtResult
    }
}
