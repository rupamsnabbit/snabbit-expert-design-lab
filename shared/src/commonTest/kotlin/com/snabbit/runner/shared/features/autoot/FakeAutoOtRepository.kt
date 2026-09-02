package com.snabbit.runner.shared.features.autoot

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.repository.AutoOtRepository
import kotlinx.coroutines.CompletableDeferred

/** Deterministic fake for [AutoOtRepository] — records calls, returns canned results. */
internal class FakeAutoOtRepository : AutoOtRepository {
    val accepted: MutableList<Int> = mutableListOf()
    val rejected: MutableList<Pair<Int, AutoOtDenyReason>> = mutableListOf()
    var startOtCalls: Int = 0

    var acceptResult: Result<Unit, RunnerActionError> = Result.Ok(Unit)
    var rejectResult: Result<Unit, RunnerActionError> = Result.Ok(Unit)
    var startOtResult: Result<AutoOtDetails?, RunnerActionError> = Result.Ok(null)

    /** When set, [accept] suspends on this until the test completes it — lets a test fire the
     *  expiry timer while an accept is in flight (exercises the expiry/accept race guard). */
    var acceptGate: CompletableDeferred<Unit>? = null

    override suspend fun accept(requestId: Int): Result<Unit, RunnerActionError> {
        accepted += requestId
        acceptGate?.await()
        return acceptResult
    }

    override suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, RunnerActionError> {
        rejected += (requestId to reason)
        return rejectResult
    }

    override suspend fun requestStartOt(): Result<AutoOtDetails?, RunnerActionError> {
        startOtCalls++
        return startOtResult
    }
}
