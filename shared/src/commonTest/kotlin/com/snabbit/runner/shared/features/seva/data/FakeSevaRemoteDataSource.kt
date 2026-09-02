package com.snabbit.runner.shared.features.seva.data

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.seva.data.remote.SevaRemoteDataSource
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint

/**
 * Test fake for [SevaRemoteDataSource]. Default: `Result.Ok(emptyList())`. Push
 * canned responses via [enqueue] (FIFO); records each call in [calls].
 */
internal class FakeSevaRemoteDataSource : SevaRemoteDataSource {
    data class Call(val lat: Double, val lng: Double, val radius: Int, val type: String)

    val calls: MutableList<Call> = mutableListOf()
    private val responses: ArrayDeque<Result<List<SevaPoint>, NetworkError>> = ArrayDeque()

    fun enqueue(result: Result<List<SevaPoint>, NetworkError>) {
        responses.addLast(result)
    }

    override suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int,
        type: String,
    ): Result<List<SevaPoint>, NetworkError> {
        calls += Call(lat, lng, radius, type)
        return responses.removeFirstOrNull() ?: Result.Ok(emptyList())
    }
}
