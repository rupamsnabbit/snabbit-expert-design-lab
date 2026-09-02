package com.snabbit.runner.shared.features.shift.core.data.repository

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.data.GamificationParser
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.core.data.remote.ShiftRemoteDataSource
import com.snabbit.runner.shared.features.shift.core.data.remote.dto.ShiftLoginErrorEnvelope
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftLoginError
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

private const val RETAKE_CODE = "SELFIE_VALIDATION_ERROR"
private const val TAG = "ShiftRepository"

/** Cap the body echoed into logs — a gateway HTML error page can be huge. */
private const val BODY_SNIPPET = 200

/**
 * Bridges the data-layer [ShiftRemoteDataSource] to the domain [ShiftRepository]
 * contract. Each method has its own error mapping:
 *  - **login** collapses [NetworkError] into [ShiftLoginError]; specifically
 *    pulls validation codes out of a 4xx body when
 *    `errors[].code == "SELFIE_VALIDATION_ERROR"`.
 *  - **logout** collapses [NetworkError] into [RunnerActionError] via the
 *    generic status-code buckets — UI only needs them to pick a snackbar
 *    string + retry policy.
 */
internal class ShiftRepositoryImpl(
    private val remote: ShiftRemoteDataSource,
    private val logger: Logger,
) : ShiftRepository {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val gamificationParser = GamificationParser()

    /** Parse a response body to a [JsonObject] for gamification decoding; null on garbage. */
    private fun bodyObject(body: String): JsonObject? = try {
        json.parseToJsonElement(body) as? JsonObject
    } catch (_: Exception) {
        null
    }

    override suspend fun shiftLogin(
        selfiePath: String,
        lat: Double?,
        lng: Double?,
    ): Result<PostActionOutcome?, ShiftLoginError> =
        when (val r = remote.shiftLogin(selfiePath, lat, lng)) {
            is Result.Ok -> Result.Ok(gamificationParser.parsePostActionOutcome(bodyObject(r.value.body)))
            is Result.Err -> Result.Err(r.error.toLoginError())
        }

    override suspend fun shiftLogout(): Result<PostActionOutcome?, RunnerActionError> =
        when (val r = remote.shiftLogout()) {
            is Result.Ok -> Result.Ok(r.value)
            is Result.Err -> Result.Err(r.error.toLogoutError())
        }

    override suspend fun emergencyLogoutAvailability(): Result<EmergencyLogoutAvailability, RunnerActionError> =
        when (val r = remote.emergencyLogoutAvailability()) {
            is Result.Ok -> Result.Ok(r.value)
            is Result.Err -> Result.Err(r.error.toLogoutError())
        }

    override suspend fun emergencyLogout(periodLeave: Boolean): Result<PostActionOutcome?, RunnerActionError> =
        when (val r = remote.emergencyLogout(periodLeave = periodLeave)) {
            is Result.Ok -> Result.Ok(r.value)
            is Result.Err -> Result.Err(r.error.toLogoutError())
        }

    private fun NetworkError.toLoginError(): ShiftLoginError = when (this) {
        is NetworkError.TransportError -> ShiftLoginError.NoConnection
        is NetworkError.HttpError -> when (statusCode) {
            401, 403 -> ShiftLoginError.Unauthorized
            in 500..599 -> ShiftLoginError.Server
            in 400..499 -> parseFourXx(body, statusCode)
            else -> ShiftLoginError.Unknown(statusCode = statusCode)
        }
    }

    private fun NetworkError.toLogoutError(): RunnerActionError = when (this) {
        is NetworkError.TransportError -> RunnerActionError.NoConnection
        is NetworkError.HttpError -> when (statusCode) {
            401, 403 -> RunnerActionError.Unauthorized
            in 500..599 -> RunnerActionError.Server
            else -> RunnerActionError.Unknown(statusCode)
        }
    }

    /**
     * Decode the BE error envelope; if any entry carries the
     * `SELFIE_VALIDATION_ERROR` marker, surface the codes as
     * [ShiftLoginError.Validation]. Otherwise fall back to
     * [ShiftLoginError.Unknown] with the top-level message.
     */
    private fun parseFourXx(body: String, statusCode: Int): ShiftLoginError {
        val envelope = try {
            json.decodeFromString<ShiftLoginErrorEnvelope>(body)
        } catch (e: SerializationException) {
            // Logged, not swallowed. If the BE error envelope drifts — or an edge
            // returns a non-JSON 4xx (gateway HTML on a 429/413) — the runner just
            // sees a generic error; without this line there is no telemetry at all
            // and shift-login breakage is undiagnosable from the dashboard.
            logger.w(TAG, "shiftLogin $statusCode: error envelope not decodable: ${body.take(BODY_SNIPPET)}", e)
            return ShiftLoginError.Unknown(statusCode = statusCode)
        }
        val retake = envelope.errors.firstOrNull { it.code == RETAKE_CODE }
        return if (retake != null) {
            ShiftLoginError.Validation(codes = extractCodes(retake.data))
        } else {
            ShiftLoginError.Unknown(
                statusCode = statusCode,
                // The BE envelope carries the human message per error item
                // (`errors[].message`); the top-level `message` is legacy. Skip
                // blank item messages so they don't defeat the fallback chain.
                serverMessage = envelope.errors
                    .firstNotNullOfOrNull { it.message?.takeUnless(String::isBlank) }
                    ?: envelope.message,
            )
        }
    }

    /**
     * The BE has historically shipped two shapes for the codes payload:
     * `{"codes": ["a", "b"]}` and a bare `["a", "b"]`. Accept both — Dart's
     * `ResponseError` parser does the same. Unknown wire strings collapse to
     * [SelfieValidationCode.Unknown] (kept in the list so the UI count stays
     * accurate).
     */
    private fun extractCodes(data: JsonElement?): List<SelfieValidationCode> {
        val array: JsonArray = when (data) {
            is JsonArray -> data
            is JsonObject -> (data["codes"] as? JsonArray) ?: return emptyList()
            else -> return emptyList()
        }
        return array.mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            .map { SelfieValidationCode.fromWire(it) }
    }
}
