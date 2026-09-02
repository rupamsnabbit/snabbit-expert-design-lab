package com.snabbit.runner.shared.features.shift.attendance.data.repository

import com.snabbit.runner.shared.features.shift.attendance.data.FakeAttendanceRemoteDataSource
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class AttendanceRepositoryImplTest {

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

    @Test fun markProvisional_okPasses() = runTest {
        val remote = FakeAttendanceRemoteDataSource()
        val repo = AttendanceRepositoryImpl(remote)

        val result = repo.markProvisional(true)

        assertIs<Result.Ok<com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome?>>(result)
        assertEquals(true, remote.calls.single().present)
    }

    @Test fun changeAttendance_callsRemote_withShiftDate() = runTest {
        val remote = FakeAttendanceRemoteDataSource()
        val repo = AttendanceRepositoryImpl(remote)

        repo.changeAttendance(false, shiftDateIst = "2026-02-07")

        assertEquals(FakeAttendanceRemoteDataSource.Op.ChangeAttendance, remote.calls.single().op)
        assertEquals(false, remote.calls.single().present)
    }

    @Test fun transportError_mapsToNoConnection() = runTest {
        val remote = FakeAttendanceRemoteDataSource().apply { enqueue(Result.Err(transport())) }

        val result = AttendanceRepositoryImpl(remote).markProvisional(true)

        val err = assertIs<Result.Err<RunnerActionError>>(result)
        assertIs<RunnerActionError.NoConnection>(err.error)
    }

    @Test fun http401_mapsToUnauthorized() = runTest {
        val remote = FakeAttendanceRemoteDataSource().apply { enqueue(Result.Err(http(401))) }

        val err = assertIs<Result.Err<RunnerActionError>>(
            AttendanceRepositoryImpl(remote).markProvisional(true),
        )
        assertIs<RunnerActionError.Unauthorized>(err.error)
    }

    @Test fun http403_mapsToUnauthorized() = runTest {
        val remote = FakeAttendanceRemoteDataSource().apply { enqueue(Result.Err(http(403))) }

        val err = assertIs<Result.Err<RunnerActionError>>(
            AttendanceRepositoryImpl(remote).markProvisional(true),
        )
        assertIs<RunnerActionError.Unauthorized>(err.error)
    }

    @Test fun http500_mapsToServer() = runTest {
        val remote = FakeAttendanceRemoteDataSource().apply { enqueue(Result.Err(http(503))) }

        val err = assertIs<Result.Err<RunnerActionError>>(
            AttendanceRepositoryImpl(remote).changeAttendance(true, "2026-02-07"),
        )
        assertIs<RunnerActionError.Server>(err.error)
    }

    @Test fun http422_mapsToUnknown_carriesStatusCode() = runTest {
        val remote = FakeAttendanceRemoteDataSource().apply { enqueue(Result.Err(http(422))) }

        val err = assertIs<Result.Err<RunnerActionError>>(
            AttendanceRepositoryImpl(remote).changeAttendance(true, "2026-02-07"),
        )
        val unknown = assertIs<RunnerActionError.Unknown>(err.error)
        assertEquals(422, unknown.statusCode)
    }
}
