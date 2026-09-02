package com.snabbit.runner.shared.features.shift.core.data.remote

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.FormPart
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.gamification.data.GamificationParser
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.core.data.remote.dto.EmergencyLogoutAvailabilityDto
import com.snabbit.runner.shared.features.shift.core.data.remote.dto.EmergencyLogoutRequestDto
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Thin remote contract for the runner shift-lifecycle endpoints. Returns the
 * core [Result] type so failures are values, not exceptions — the repository
 * layer collapses the network failure into the domain error sealed type. The
 * login method returns the full [SuccessResponse] so the repository can also
 * read the `retakeSelfie` 4xx body; logout discards the body and returns Unit.
 */
internal interface ShiftRemoteDataSource {
    /** `POST api/v1/runners/me/shift/login?lat=&lng=` with a multipart `file`
     *  part. Coords are omitted from the query when null. */
    suspend fun shiftLogin(
        selfiePath: String,
        lat: Double?,
        lng: Double?,
    ): Result<SuccessResponse, NetworkError>

    /** `POST api/v1/runners/me/shift/logout` with an empty body. Backend
     *  transitions widget → `RUNNER_SEE_YOU_TOMORROW` on success; client
     *  re-polls `current_state` to pick it up. Decodes the gamification
     *  `post_action_outcome` from the response body (null when absent). */
    suspend fun shiftLogout(): Result<PostActionOutcome?, NetworkError>

    /** `GET api/v1/runners/me/emergency_logout/availability` — counts the
     *  runner's used vs allowed emergency logouts. Gamification fields in
     *  the response are ignored (separate PR). */
    suspend fun emergencyLogoutAvailability(): Result<EmergencyLogoutAvailability, NetworkError>

    /** `POST api/v1/runners/me/emergency_logout` with `{"period_leave": bool}`.
     *  Decodes the gamification `post_action_outcome` from the response body
     *  (null when absent); client also re-polls `current_state` afterwards. */
    suspend fun emergencyLogout(periodLeave: Boolean): Result<PostActionOutcome?, NetworkError>
}

/**
 * Production [ShiftRemoteDataSource] — talks to the runner shift-lifecycle
 * endpoints via the shared [SnabbitHttpClient]:
 *  - `POST api/v1/runners/me/shift/login?lat=&lng=` — multipart `file` part
 *  - `POST api/v1/runners/me/shift/logout` — empty body
 *
 * Auth + tracing + `Content-Type` are applied by the client's interceptor
 * chain. Response bodies are ignored for logout; login surfaces the full
 * response so the repository can read the `retakeSelfie` 4xx body.
 */
internal class ShiftRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
    // Defaults to the platform logger (== Koin's `single<Logger>`); DI/tests
    // need not pass it. Used to leave a breadcrumb on a malformed 2xx body.
    private val logger: Logger = defaultLogger(),
) : ShiftRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val gamificationParser = GamificationParser()

    override suspend fun shiftLogin(
        selfiePath: String,
        lat: Double?,
        lng: Double?,
    ): Result<SuccessResponse, NetworkError> {
        val query = buildMap {
            if (lat != null) put("lat", lat.toString())
            if (lng != null) put("lng", lng.toString())
        }
        return httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "/$LOGIN_PATH",
                query = query,
                formParts = listOf(
                    FormPart.File(
                        name = "file",
                        filePath = selfiePath,
                        filename = "selfie.jpg",
                        mimeType = "image/jpeg",
                    ),
                ),
            ),
        )
    }

    // Empty body — Dart's `JobHttp.runnerLogout()` sends `data ?? {}`.
    override suspend fun shiftLogout(): Result<PostActionOutcome?, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/$LOGOUT_PATH", body = "{}"),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(parsePostActionOutcome(result.value.body))
            is Result.Err -> Result.Err(result.error)
        }
    }

    override suspend fun emergencyLogoutAvailability(): Result<EmergencyLogoutAvailability, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$EMERGENCY_LOGOUT_AVAILABILITY_PATH"),
        )
        return when (result) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<EmergencyLogoutAvailabilityDto>(result.value.body).toDomain())
            } catch (e: SerializationException) {
                // Malformed 200 body: surface as a synthetic HttpError so the repo's
                // status-bucket mapping routes it to Unknown rather than crashing.
                logger.w(
                    TAG,
                    "emergency_logout/availability: unparseable 2xx body " +
                        "(requestId=${result.value.requestId})",
                    e,
                )
                Result.Err(
                    NetworkError.HttpError(
                        statusCode = result.value.statusCode,
                        body = result.value.body,
                        errorType = AppErrorType.OTHER_ERROR,
                        requestId = result.value.requestId,
                        durationMs = result.value.durationMs,
                    ),
                )
            }
            is Result.Err -> Result.Err(result.error)
        }
    }

    override suspend fun emergencyLogout(periodLeave: Boolean): Result<PostActionOutcome?, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "/$EMERGENCY_LOGOUT_PATH",
                body = json.encodeToString(EmergencyLogoutRequestDto(periodLeave = periodLeave)),
            ),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(parsePostActionOutcome(result.value.body))
            is Result.Err -> Result.Err(result.error)
        }
    }

    /**
     * Best-effort decode of the gamification `post_action_outcome` off the
     * emergency-logout response body. Never throws — a malformed / absent body
     * just yields null (the logout still succeeded).
     */
    private fun parsePostActionOutcome(body: String): PostActionOutcome? = try {
        val obj = json.parseToJsonElement(body) as? JsonObject
        obj?.let { gamificationParser.parsePostActionOutcome(it) }
    } catch (_: Exception) {
        null
    }

    private companion object {
        const val TAG = "ShiftRemoteDataSource"
        const val LOGIN_PATH = "api/v1/runners/me/shift/login"
        const val LOGOUT_PATH = "api/v1/runners/me/shift/logout"
        const val EMERGENCY_LOGOUT_PATH = "api/v1/runners/me/emergency_logout"
        const val EMERGENCY_LOGOUT_AVAILABILITY_PATH = "api/v1/runners/me/emergency_logout/availability"
    }
}
