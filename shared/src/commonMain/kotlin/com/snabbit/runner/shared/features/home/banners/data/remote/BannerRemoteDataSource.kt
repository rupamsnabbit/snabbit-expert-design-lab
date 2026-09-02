package com.snabbit.runner.shared.features.home.banners.data.remote

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.banners.data.remote.dto.HomeBannersResponseDto
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Thin remote contract for the home-banners endpoint. Transport-only: returns
 * raw wire DTOs — the repository owns row validation and domain mapping.
 */
internal interface BannerRemoteDataSource {
    /** `GET api/v1/runners/me/home_banners` — banners plus the badge count. */
    suspend fun fetchHomeBanners(): Result<HomeBannersResponseDto, NetworkError>
}

/**
 * Production [BannerRemoteDataSource] — talks to the home-banners endpoint via
 * the shared [SnabbitHttpClient]. Auth + tracing headers are applied by the
 * client's interceptor chain; mirrors `SuspendedRemoteDataSourceImpl`.
 *
 * A 2xx body that fails to decode maps to a synthetic [NetworkError.HttpError]
 * so the caller's single Err path covers it (banners degrade to the fallback).
 */
internal class BannerRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : BannerRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun fetchHomeBanners(): Result<HomeBannersResponseDto, NetworkError> {
        return when (val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$HOME_BANNERS_PATH"),
        )) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<HomeBannersResponseDto>(result.value.body))
            } catch (e: SerializationException) {
                Result.Err(
                    NetworkError.HttpError(
                        statusCode = result.value.statusCode,
                        body = e.message.orEmpty(),
                        errorType = AppErrorType.OTHER_ERROR,
                        requestId = result.value.requestId,
                        durationMs = result.value.durationMs,
                    ),
                )
            }
            is Result.Err -> Result.Err(result.error)
        }
    }

    private companion object {
        const val HOME_BANNERS_PATH = "api/v1/runners/me/home_banners"
    }
}
