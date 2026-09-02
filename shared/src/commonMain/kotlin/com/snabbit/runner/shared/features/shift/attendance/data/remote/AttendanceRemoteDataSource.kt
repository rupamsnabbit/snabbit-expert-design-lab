package com.snabbit.runner.shared.features.shift.attendance.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.gamification.data.GamificationParser
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.attendance.data.remote.dto.ChangeAttendanceRequestDto
import com.snabbit.runner.shared.features.shift.attendance.data.remote.dto.MarkProvisionalRequestDto
import io.ktor.http.HttpMethod
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Thin remote contract for the two attendance write endpoints. Returns the
 * core [Result] type so failures are values, not exceptions — the repository
 * layer collapses both into the domain error sealed type.
 */
internal interface AttendanceRemoteDataSource {
    suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, NetworkError>
    suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, NetworkError>
}

/**
 * Production [AttendanceRemoteDataSource] — talks to the runner attendance
 * endpoints via the shared [SnabbitHttpClient]:
 *  - `POST api/v1/runners/me/provisional_attendance/mark` — body `{"mark"}`
 *  - `POST api/v1/runners/me/attendance/mark` — body `{"mark","shift_date"}`
 *
 * The two endpoints take different bodies (Dart's change-attendance call
 * always sends `shift_date` from the envelope's `start_date_ist`; the
 * provisional call doesn't). Auth + tracing + `Content-Type: application/json`
 * are applied by the client's interceptor chain. Response bodies are ignored
 * — the next `current_state` envelope (via `RunnerStateChannel`) is the
 * canonical post-action state.
 */
internal class AttendanceRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : AttendanceRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val gamificationParser = GamificationParser()

    private fun parsePostActionOutcome(body: String): PostActionOutcome? = try {
        (json.parseToJsonElement(body) as? JsonObject)?.let { gamificationParser.parsePostActionOutcome(it) }
    } catch (_: Exception) {
        null
    }

    override suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, NetworkError> =
        post(PROVISIONAL_PATH, json.encodeToString(MarkProvisionalRequestDto(mark = present)))

    override suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, NetworkError> = post(
        CHANGE_PATH,
        json.encodeToString(ChangeAttendanceRequestDto(mark = present, shiftDate = shiftDateIst)),
    )

    private suspend fun post(path: String, body: String): Result<PostActionOutcome?, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/$path", body = body),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(parsePostActionOutcome(result.value.body))
            is Result.Err -> Result.Err(result.error)
        }
    }

    private companion object {
        const val PROVISIONAL_PATH = "api/v1/runners/me/provisional_attendance/mark"
        const val CHANGE_PATH = "api/v1/runners/me/attendance/mark"
    }
}
