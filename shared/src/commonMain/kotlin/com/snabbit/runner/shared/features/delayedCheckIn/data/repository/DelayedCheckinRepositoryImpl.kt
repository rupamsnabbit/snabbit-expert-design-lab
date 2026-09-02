package com.snabbit.runner.shared.features.job.delayedcheckin.data.repository

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.DelayedCheckinRemoteDataSource
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto.DispositionRequestDto
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto.HelplineResponseDto
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository.DelayedCheckinRepository
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Maps [DelayedCheckinRemoteDataSource]'s transport-level [Result] onto the
 * domain [DelayedCheckinRepository] contract and nothing else — no
 * crash-reporting, no retries, no caching. `Result.Ok` decodes the body
 * ([submitDisposition] surfaces the ack's optional server-driven `message`);
 * `Result.Err` passes the [NetworkError] straight through.
 */
class DelayedCheckinRepositoryImpl(
    private val remoteDataSource: DelayedCheckinRemoteDataSource,
) : DelayedCheckinRepository {

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun submitDisposition(
        runnerJobId: Int,
        jobId: Int,
        runnerId: Int,
        dispositionTag: String,
        dispositionMessage: String,
        ameyoSupport: Boolean,
    ): Result<String?, NetworkError> {
        val result = remoteDataSource.submitDisposition(
            runnerJobId = runnerJobId,
            ameyoSupport = ameyoSupport,
            body = DispositionRequestDto(
                jobId = jobId,
                runnerId = runnerId,
                dispositionTag = dispositionTag,
                dispositionMessage = dispositionMessage,
            ),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(extractAckMessage(result.value))
            is Result.Err -> Result.Err(result.error)
        }
    }

    /**
     * The ack's optional server-driven confirmation copy — Dart parity:
     * `response?.data?['message']` in `job_support_bottom_sheet.dart`'s
     * submit path. Absent/malformed body is simply "no message" (the 2xx
     * already succeeded); the caller falls back to its default copy.
     */
    private fun extractAckMessage(response: SuccessResponse): String? =
        runCatching {
            (json.parseToJsonElement(response.body) as? JsonObject)
                ?.get("message")
                ?.let { (it as? JsonPrimitive)?.contentOrNull }
                ?.takeIf { it.isNotBlank() }
        }.getOrNull()

    override suspend fun getHelpline(widgetType: String): Result<String?, NetworkError> {
        val result = remoteDataSource.getHelpline(widgetType)
        return when (result) {
            is Result.Ok -> decodeHelplineBody(result.value)
            is Result.Err -> Result.Err(result.error)
        }
    }

    /**
     * A malformed 2xx body must not escape this Result-typed signature as a
     * thrown [SerializationException]. Mapped onto the existing
     * [NetworkError.HttpError] case rather than a new hierarchy: the server
     * DID respond — with an unusable body — so the truthful
     * statusCode/body/requestId are preserved for diagnostics, and
     * `errorType` is [AppErrorType.OTHER_ERROR] (the failure is neither the
     * caller's input being invalid nor the server being down).
     */
    private fun decodeHelplineBody(response: SuccessResponse): Result<String?, NetworkError> =
        try {
            Result.Ok(json.decodeFromString<HelplineResponseDto>(response.body).phoneNumber)
        } catch (e: SerializationException) {
            Result.Err(
                NetworkError.HttpError(
                    statusCode = response.statusCode,
                    body = response.body,
                    errorType = AppErrorType.OTHER_ERROR,
                    requestId = response.requestId,
                    durationMs = response.durationMs,
                ),
            )
        }
}
