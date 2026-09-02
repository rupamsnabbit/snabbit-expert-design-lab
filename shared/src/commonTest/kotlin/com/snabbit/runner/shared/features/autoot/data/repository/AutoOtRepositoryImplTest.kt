package com.snabbit.runner.shared.features.autoot.data.repository

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.data.FakeAutoOtRemoteDataSource
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class AutoOtRepositoryImplTest {

    private fun http(status: Int) = NetworkError.HttpError(
        statusCode = status,
        body = "",
        errorType = AppErrorType.OTHER_ERROR,
        requestId = "rid",
        durationMs = 0,
    )

    private fun transport() = NetworkError.TransportError(
        errorType = AppErrorType.OTHER_ERROR,
        requestId = "rid",
        durationMs = 0,
    )

    @Test fun accept_okPassesThrough_withRequestId() = runTest {
        val remote = FakeAutoOtRemoteDataSource()

        val result = AutoOtRepositoryImpl(remote).accept(requestId = 42)

        assertIs<Result.Ok<Unit>>(result)
        assertEquals(42, remote.calls.single().requestId)
    }

    @Test fun reject_forwardsRequestIdAndReason() = runTest {
        val remote = FakeAutoOtRemoteDataSource()

        AutoOtRepositoryImpl(remote).reject(7, AutoOtDenyReason.CANCELLED_DUE_TO_JOB_ASSIGNMENT)

        val call = remote.calls.single()
        assertEquals(7, call.requestId)
        assertEquals(AutoOtDenyReason.CANCELLED_DUE_TO_JOB_ASSIGNMENT, call.reason)
    }

    @Test fun transportError_mapsToNoConnection() = runTest {
        val remote = FakeAutoOtRemoteDataSource().apply { enqueueAccept(Result.Err(transport())) }

        val err = assertIs<Result.Err<RunnerActionError>>(AutoOtRepositoryImpl(remote).accept(1))
        assertIs<RunnerActionError.NoConnection>(err.error)
    }

    @Test fun http401_mapsToUnauthorized() = runTest {
        val remote = FakeAutoOtRemoteDataSource().apply { enqueueAccept(Result.Err(http(401))) }

        val err = assertIs<Result.Err<RunnerActionError>>(AutoOtRepositoryImpl(remote).accept(1))
        assertIs<RunnerActionError.Unauthorized>(err.error)
    }

    @Test fun http503_mapsToServer() = runTest {
        val remote = FakeAutoOtRemoteDataSource().apply { enqueueAccept(Result.Err(http(503))) }

        val err = assertIs<Result.Err<RunnerActionError>>(AutoOtRepositoryImpl(remote).accept(1))
        assertIs<RunnerActionError.Server>(err.error)
    }

    @Test fun http422_mapsToUnknown_carriesStatusCode() = runTest {
        val remote = FakeAutoOtRemoteDataSource().apply { enqueueReject(Result.Err(http(422))) }

        val err = assertIs<Result.Err<RunnerActionError>>(
            AutoOtRepositoryImpl(remote).reject(1, AutoOtDenyReason.REJECTED),
        )
        assertEquals(422, assertIs<RunnerActionError.Unknown>(err.error).statusCode)
    }
}
