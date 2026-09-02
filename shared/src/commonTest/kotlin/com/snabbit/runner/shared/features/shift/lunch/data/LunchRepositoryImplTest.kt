package com.snabbit.runner.shared.features.shift.lunch.data

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.shift.lunch.data.remote.LunchRemoteDataSource
import com.snabbit.runner.shared.features.shift.lunch.data.repository.LunchRepositoryImpl
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Verifies the error-mapping seam: [NetworkError] (transport vs HTTP status
 * buckets) → [RunnerActionError], for all three break actions. The remote
 * DataSource is stubbed; HTTP transport itself is covered elsewhere.
 */
class LunchRepositoryImplTest {

    /** Stub remote returning the same canned result for every method. */
    private class FakeRemote(
        private val response: Result<Unit, NetworkError>,
    ) : LunchRemoteDataSource {
        override suspend fun acceptLunch() = response
        override suspend fun denyLunch() = response
        override suspend fun endBreak(lat: Double?, lng: Double?) = response
    }

    private fun repo(response: Result<Unit, NetworkError>) =
        LunchRepositoryImpl(remote = FakeRemote(response))

    @Test fun ok_returnsOk_forAllActions() = runTest {
        val r = repo(Result.Ok(Unit))
        assertTrue(r.acceptLunch() is Result.Ok)
        assertTrue(r.denyLunch() is Result.Ok)
        assertTrue(r.endBreak(1.0, 2.0) is Result.Ok)
    }

    @Test fun transportError_mapsToNoConnection() = runTest {
        val err = (repo(Result.Err(transport())).acceptLunch() as Result.Err).error
        assertEquals(RunnerActionError.NoConnection, err)
    }

    @Test fun http401_mapsToUnauthorized() = runTest {
        val err = (repo(Result.Err(http(401))).denyLunch() as Result.Err).error
        assertEquals(RunnerActionError.Unauthorized, err)
    }

    @Test fun http403_mapsToUnauthorized() = runTest {
        val err = (repo(Result.Err(http(403))).endBreak(null, null) as Result.Err).error
        assertEquals(RunnerActionError.Unauthorized, err)
    }

    @Test fun http500_mapsToServer() = runTest {
        val err = (repo(Result.Err(http(500))).acceptLunch() as Result.Err).error
        assertEquals(RunnerActionError.Server, err)
    }

    @Test fun otherHttp_mapsToUnknown_withStatus() = runTest {
        val err = (repo(Result.Err(http(409))).endBreak(1.0, 2.0) as Result.Err).error
        assertEquals(RunnerActionError.Unknown(409), err)
    }

    // --- helpers ---

    private fun transport() = NetworkError.TransportError(
        errorType = AppErrorType.NO_INTERNET, requestId = "rid", durationMs = 0,
    )

    private fun http(code: Int) = NetworkError.HttpError(
        statusCode = code, body = "",
        errorType = if (code in 500..599) AppErrorType.SERVER_DOWN else AppErrorType.INVALID_REQUEST,
        requestId = "rid", durationMs = 0,
    )
}
