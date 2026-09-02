package com.snabbit.runner.shared.features.home.suspended

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.suspended.data.remote.SuspendedRemoteDataSource
import com.snabbit.runner.shared.features.home.suspended.data.repository.SuspendedRepositoryImpl
import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

/**
 * Verifies the unsuspend status mapping seam — NetworkError / HTTP status →
 * [UnsuspendResult] — mirroring Dart's `RunnerSuspended._onComeBackToWorkTapped`
 * (200/409 success, 400 denied-with-body, else failed). The remote DataSource is
 * stubbed; HTTP transport itself is covered by the network-layer tests.
 */
class SuspendedRepositoryImplTest {

    private class FakeRemote(
        private val response: Result<Unit, NetworkError>,
    ) : SuspendedRemoteDataSource {
        override suspend fun unsuspend(): Result<Unit, NetworkError> = response
    }

    private fun repo(response: Result<Unit, NetworkError>) =
        SuspendedRepositoryImpl(remote = FakeRemote(response))

    @Test fun ok200_isReactivated() = runTest {
        assertEquals(UnsuspendResult.Reactivated(statusCode = 200), repo(Result.Ok(Unit)).unsuspend())
    }

    @Test fun http409_isReactivated() = runTest {
        assertEquals(UnsuspendResult.Reactivated(statusCode = 409), repo(Result.Err(http(409, """{}"""))).unsuspend())
    }

    @Test fun http400_parsesReasonAndMessage() = runTest {
        val body = """{"status":"already_active","message":"You are not suspended"}"""
        val r = assertIs<UnsuspendResult.Denied>(repo(Result.Err(http(400, body))).unsuspend())
        assertEquals("already_active", r.reason)
        assertEquals("You are not suspended", r.message)
    }

    @Test fun http400_malformedBody_deniesWithUnknown() = runTest {
        val r = assertIs<UnsuspendResult.Denied>(repo(Result.Err(http(400, "not json"))).unsuspend())
        assertEquals("unknown", r.reason)
        assertEquals("unknown", r.message)
    }

    @Test fun http400_missingFields_deniesWithUnknown() = runTest {
        val r = assertIs<UnsuspendResult.Denied>(repo(Result.Err(http(400, """{}"""))).unsuspend())
        assertEquals("unknown", r.reason)
        assertEquals("unknown", r.message)
    }

    @Test fun http500_isFailedWithStatus() = runTest {
        val r = assertIs<UnsuspendResult.Failed>(repo(Result.Err(http(500, ""))).unsuspend())
        assertEquals(500, r.statusCode)
        assertEquals(null, r.message) // empty body → no server message
    }

    @Test fun http500_bodyMessage_carriesServerMessage() = runTest {
        val r = assertIs<UnsuspendResult.Failed>(
            repo(Result.Err(http(500, """{"message":"Service unavailable"}"""))).unsuspend(),
        )
        assertEquals("Service unavailable", r.message)
    }

    @Test fun http500_bodyDetailFallback_carriesDetail() = runTest {
        val r = assertIs<UnsuspendResult.Failed>(
            repo(Result.Err(http(500, """{"detail":"upstream timeout"}"""))).unsuspend(),
        )
        assertEquals("upstream timeout", r.message) // message absent → detail used
    }

    @Test fun otherHttp_isFailedWithStatus() = runTest {
        val r = assertIs<UnsuspendResult.Failed>(repo(Result.Err(http(401, ""))).unsuspend())
        assertEquals(401, r.statusCode)
    }

    @Test fun transportError_isFailedWithNullStatus() = runTest {
        val r = assertIs<UnsuspendResult.Failed>(repo(Result.Err(transport())).unsuspend())
        assertEquals(null, r.statusCode)
    }

    // --- helpers ---

    private fun transport() = NetworkError.TransportError(
        errorType = AppErrorType.NO_INTERNET, requestId = "rid", durationMs = 0,
    )

    private fun http(code: Int, body: String) = NetworkError.HttpError(
        statusCode = code, body = body,
        errorType = if (code in 500..599) AppErrorType.SERVER_DOWN else AppErrorType.INVALID_REQUEST,
        requestId = "rid", durationMs = 0,
    )
}
