package com.snabbit.runner.shared.features.pan.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitBaseUrl
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.pan.data.remote.dto.PanUpdateRequestDto
import io.ktor.http.HttpMethod
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [PanRemoteDataSource] — `POST verification/pan/update` on the
 * **onboarding host** (`NetworkConfig.onboardingUrl`, a different base than the
 * main API), via the shared [SnabbitHttpClient]. Auth + tracing headers come from
 * the client's interceptor chain. The 2xx **body** is passed up: the backend can
 * reject an invalid PAN with `200` + a non-empty `errors[]`, so the repository — not
 * this layer — decides success vs. failure and extracts the message.
 */
internal class PanRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : PanRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun updatePan(panNumber: String): Result<String, NetworkError> {
        val body = json.encodeToString(PanUpdateRequestDto(panNumber = panNumber))
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/$PAN_PATH", body = body, base = SnabbitBaseUrl.Onboarding),
        )
        return when (result) {
            // Pass the 2xx body up: a 200 can still carry a non-empty `errors[]`
            // (invalid PAN), so the repository decides success vs. failure.
            is Result.Ok -> Result.Ok(result.value.body)
            is Result.Err -> Result.Err(result.error)
        }
    }

    private companion object {
        const val PAN_PATH = "api/v1/verification/pan/update"
    }
}
