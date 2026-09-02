package com.snabbit.runner.shared.features.job.delayedcheckin.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto.DispositionRequestDto
import io.ktor.http.HttpMethod
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [DelayedCheckinRemoteDataSource] — talks to the runner_job
 * penalty endpoints via the KMP [SnabbitHttpClient]. Auth (Bearer) + tracing
 * + `Content-Type: application/json` are applied by the client's
 * interceptor chain; this only builds the requests against the pushed base
 * URL (mirrors `LanguageDataSourceImpl`'s calling convention).
 */
class DelayedCheckinRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : DelayedCheckinRemoteDataSource {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override suspend fun submitDisposition(
        runnerJobId: Int,
        ameyoSupport: Boolean,
        body: DispositionRequestDto,
    ): Result<SuccessResponse, NetworkError> {
        return httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "/api/v1/runner_job/penalty/$runnerJobId/disposition",
                query = mapOf(AMEYO_SUPPORT_PARAM to ameyoSupport.toString()),
                body = json.encodeToString(body),
            ),
        )
    }

    override suspend fun getHelpline(widgetType: String): Result<SuccessResponse, NetworkError> {
        return httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "/api/v1/runners/me/helpline",
                // Dart parity: a blank widget type OMITS the param (queryParameters: null
                // in `job_support_bottom_sheet.dart`) — never send an empty `?type=`.
                query = if (widgetType.isBlank()) emptyMap() else mapOf(HELPLINE_TYPE_PARAM to widgetType),
            ),
        )
    }

    private companion object {
        const val AMEYO_SUPPORT_PARAM = "ameyo_support"
        const val HELPLINE_TYPE_PARAM = "type"
    }
}
