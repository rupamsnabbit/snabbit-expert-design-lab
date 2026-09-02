package com.snabbit.runner.shared.features.shift.core.data

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.shift.core.data.remote.ShiftRemoteDataSource
import com.snabbit.runner.shared.features.shift.core.data.repository.ShiftRepositoryImpl
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Verifies the error-mapping seam: NetworkError + the BE's `retakeSelfie`
 * envelope shapes → [ShiftLoginError] cases. The remote DataSource is
 * stubbed; HTTP transport itself is covered separately by
 * SnabbitHttpClientMultipartTest.
 */
class ShiftRepositoryImplTest {

    private class FakeRemote(
        private val response: Result<SuccessResponse, NetworkError>,
    ) : ShiftRemoteDataSource {
        override suspend fun shiftLogin(
            selfiePath: String,
            lat: Double?,
            lng: Double?,
        ) = response
        // Unused by these tests — logout / emergency-logout error mapping is
        // covered by their own per-VM tests.
        override suspend fun shiftLogout():
            Result<com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome?, NetworkError> =
            Result.Ok(null)
        override suspend fun emergencyLogoutAvailability():
            Result<com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability, NetworkError> =
            Result.Ok(
                com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability(
                    maxEmergencyLogouts = 0,
                    emergencyLogoutsTaken = 0,
                ),
            )
        override suspend fun emergencyLogout(periodLeave: Boolean):
            Result<com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome?, NetworkError> =
            Result.Ok(null)
    }

    private fun repo(
        response: Result<SuccessResponse, NetworkError>,
        logger: Logger = FakeLogger(),
    ) = ShiftRepositoryImpl(remote = FakeRemote(response), logger = logger)

    @Test fun ok200_returnsOk() = runTest {
        val r = repo(Result.Ok(success("""{}"""))).shiftLogin("path", 1.0, 2.0)
        assertTrue(r is Result.Ok)
    }

    @Test fun transportError_mapsToNoConnection() = runTest {
        val r = repo(Result.Err(transport())).shiftLogin("path", null, null)
        assertEquals(ShiftLoginError.NoConnection, (r as Result.Err).error)
    }

    @Test fun http401_mapsToUnauthorized() = runTest {
        val r = repo(Result.Err(http(401, ""))).shiftLogin("path", null, null)
        assertEquals(ShiftLoginError.Unauthorized, (r as Result.Err).error)
    }

    @Test fun http500_mapsToServer() = runTest {
        val r = repo(Result.Err(http(500, ""))).shiftLogin("path", null, null)
        assertEquals(ShiftLoginError.Server, (r as Result.Err).error)
    }

    @Test fun retakeSelfie_objectShape_parsesCodes() = runTest {
        val body = """
            {"errors":[{"code":"SELFIE_VALIDATION_ERROR",
                        "data":{"codes":["uniform_not_detected","face_mismatch"]}}]}
        """.trimIndent()
        val r = repo(Result.Err(http(422, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Validation>((r as Result.Err).error)
        assertEquals(
            listOf(SelfieValidationCode.UniformNotDetected, SelfieValidationCode.FaceMismatch),
            err.codes,
        )
    }

    @Test fun retakeSelfie_arrayShape_parsesCodes() = runTest {
        val body = """
            {"errors":[{"code":"SELFIE_VALIDATION_ERROR",
                        "data":["face_not_detected","helmet_not_detected"]}]}
        """.trimIndent()
        val r = repo(Result.Err(http(422, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Validation>((r as Result.Err).error)
        assertEquals(
            listOf(SelfieValidationCode.FaceNotDetected, SelfieValidationCode.HelmetNotDetected),
            err.codes,
        )
    }

    @Test fun other4xx_mapsToUnknown_withServerMessage() = runTest {
        val body = """{"message":"go away","errors":[]}"""
        val r = repo(Result.Err(http(400, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals(400, err.statusCode)
        assertEquals("go away", err.serverMessage)
    }

    /**
     * The real BE envelope (maestro `CustomException` handler) carries the human
     * message per error item — `{"errors":[{code,title,message,…}]}` — with no
     * top-level `message`. That per-item message must win over the fallback.
     */
    @Test fun other4xx_perItemMessage_winsOverTopLevel() = runTest {
        val body = """{"errors":[{"code":"SHIFT_ERROR","title":"Shift Error","message":"You cannot login before your shift starts"}]}"""
        val r = repo(Result.Err(http(400, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals(400, err.statusCode)
        assertEquals("You cannot login before your shift starts", err.serverMessage)
    }

    /** A blank item message must not defeat the fallback chain. */
    @Test fun other4xx_blankItemMessage_fallsBackToTopLevel() = runTest {
        val body = """{"message":"real msg","errors":[{"code":"X","message":""}]}"""
        val r = repo(Result.Err(http(400, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals("real msg", err.serverMessage)
    }

    /** The first non-blank item message wins even when `errors[0]` has none. */
    @Test fun other4xx_laterItemMessage_used() = runTest {
        val body = """{"errors":[{"code":"X"},{"code":"Y","message":"second item msg"}]}"""
        val r = repo(Result.Err(http(400, body))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals("second item msg", err.serverMessage)
    }

    @Test fun malformed4xxBody_mapsToUnknown_noServerMessage() = runTest {
        val r = repo(Result.Err(http(409, "not json"))).shiftLogin("path", null, null)
        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals(409, err.statusCode)
    }

    /**
     * Regression: the `SerializationException` was caught with `catch (_)` and
     * dropped. A drifted BE envelope — or a non-JSON 4xx (a gateway's HTML 429/413) —
     * left the runner with a generic error and ZERO telemetry, making shift-login
     * breakage undiagnosable. It's mapped to Unknown as before, but logged now.
     */
    @Test fun undecodable4xxBody_mapsToUnknown_andLogs() = runTest {
        val logger = FakeLogger()
        val r = repo(Result.Err(http(429, "<html>Too Many Requests</html>")), logger)
            .shiftLogin("path", null, null)

        val err = assertIs<ShiftLoginError.Unknown>((r as Result.Err).error)
        assertEquals(429, err.statusCode)
        assertTrue(
            logger.entries.any {
                it.level == FakeLogger.Level.WARN && it.throwable != null
            },
            "parse failure must be logged with the throwable, not swallowed",
        )
    }

    // --- helpers ---

    private fun success(body: String) = SuccessResponse(
        statusCode = 200, body = body, headers = emptyMap(),
        requestId = "rid", durationMs = 0,
    )

    private fun transport() = NetworkError.TransportError(
        errorType = AppErrorType.NO_INTERNET, requestId = "rid", durationMs = 0,
    )

    private fun http(code: Int, body: String) = NetworkError.HttpError(
        statusCode = code, body = body,
        errorType = if (code in 500..599) AppErrorType.SERVER_DOWN else AppErrorType.INVALID_REQUEST,
        requestId = "rid", durationMs = 0,
    )
}
