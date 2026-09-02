package com.snabbit.runner.shared.features.seva.data.repository

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.seva.data.FakeSevaRemoteDataSource
import com.snabbit.runner.shared.features.seva.domain.model.SevaKind
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class SevaRepositoryImplTest {

    private fun http(status: Int) = NetworkError.HttpError(
        statusCode = status, body = "", errorType = AppErrorType.OTHER_ERROR,
        requestId = "rid", durationMs = 0,
    )

    private fun transport() = NetworkError.TransportError(
        errorType = AppErrorType.OTHER_ERROR, requestId = "rid", durationMs = 0,
    )

    private val point = SevaPoint(
        id = "W1", name = "Loo", category = "Cafe", lat = 1.0, lng = 2.0,
        road = "Main St", distanceMeters = 100, kind = SevaKind.Washroom,
    )

    @Test fun ok_passesThroughList_andForwardsArgs() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Ok(listOf(point))) }
        val repo = SevaRepositoryImpl(remote)

        val result = repo.nearby(lat = 1.0, lng = 2.0, radius = 300, type = "resting")

        val ok = assertIs<Result.Ok<List<SevaPoint>>>(result)
        assertEquals(listOf(point), ok.value)
        val call = remote.calls.single()
        assertEquals(300, call.radius)
        assertEquals("resting", call.type)
    }

    @Test fun transportError_mapsToNoConnection() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Err(transport())) }

        val err = assertIs<Result.Err<RunnerActionError>>(SevaRepositoryImpl(remote).nearby(1.0, 2.0))
        assertIs<RunnerActionError.NoConnection>(err.error)
    }

    @Test fun http401_mapsToUnauthorized() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Err(http(401))) }

        val err = assertIs<Result.Err<RunnerActionError>>(SevaRepositoryImpl(remote).nearby(1.0, 2.0))
        assertIs<RunnerActionError.Unauthorized>(err.error)
    }

    @Test fun http403_mapsToUnauthorized() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Err(http(403))) }

        val err = assertIs<Result.Err<RunnerActionError>>(SevaRepositoryImpl(remote).nearby(1.0, 2.0))
        assertIs<RunnerActionError.Unauthorized>(err.error)
    }

    @Test fun http5xx_mapsToServer() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Err(http(503))) }

        val err = assertIs<Result.Err<RunnerActionError>>(SevaRepositoryImpl(remote).nearby(1.0, 2.0))
        assertIs<RunnerActionError.Server>(err.error)
    }

    @Test fun http422_mapsToUnknown_carriesStatusCode() = runTest {
        val remote = FakeSevaRemoteDataSource().apply { enqueue(Result.Err(http(422))) }

        val err = assertIs<Result.Err<RunnerActionError>>(SevaRepositoryImpl(remote).nearby(1.0, 2.0))
        val unknown = assertIs<RunnerActionError.Unknown>(err.error)
        assertEquals(422, unknown.statusCode)
    }
}
