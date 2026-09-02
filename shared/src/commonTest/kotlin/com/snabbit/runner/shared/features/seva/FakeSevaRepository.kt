package com.snabbit.runner.shared.features.seva

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import com.snabbit.runner.shared.features.seva.domain.repository.SevaRepository
import kotlinx.coroutines.CompletableDeferred

/**
 * Test fake for [SevaRepository]. Default: `Result.Ok(emptyList())`. Push canned
 * responses via [enqueue] (FIFO); records each call in [calls] for assertion.
 */
class FakeSevaRepository : SevaRepository {
    data class Call(val lat: Double, val lng: Double, val radius: Int, val type: String)

    val calls: MutableList<Call> = mutableListOf()
    private val responses: ArrayDeque<Result<List<SevaPoint>, RunnerActionError>> = ArrayDeque()
    private var gate: CompletableDeferred<Unit>? = null

    fun enqueue(result: Result<List<SevaPoint>, RunnerActionError>) {
        responses.addLast(result)
    }

    /** Parks every [nearby] call — after it's recorded in [calls] — until the
     *  returned deferred completes. Lets a test hold a fetch in flight to exercise
     *  the single-flight guard in [HomeViewModel]. */
    fun gateCalls(): CompletableDeferred<Unit> =
        CompletableDeferred<Unit>().also { gate = it }

    override suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int,
        type: String,
    ): Result<List<SevaPoint>, RunnerActionError> {
        calls += Call(lat, lng, radius, type)
        gate?.await()
        return responses.removeFirstOrNull() ?: Result.Ok(emptyList())
    }
}
