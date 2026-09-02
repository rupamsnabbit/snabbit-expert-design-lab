package com.snabbit.runner.shared.features.home.suspended.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod

/**
 * Thin remote contract for the runner-unsuspend endpoint. Returns the raw
 * [Result] of the HTTP call — the repository owns the status mapping (200/409 →
 * reactivated, 400 → denied-with-body, else → failed) because those buckets are
 * domain decisions, not transport ones.
 *
 * The 2xx body is discarded; the repository only needs the status code, and on
 * a 400 it reads the error body off [NetworkError.HttpError].
 */
internal interface SuspendedRemoteDataSource {
    /** `POST api/v1/runners/me/unsuspend` with an empty body. */
    suspend fun unsuspend(): Result<Unit, NetworkError>
}

/**
 * Production [SuspendedRemoteDataSource] — talks to the unsuspend endpoint via
 * the shared [SnabbitHttpClient]. Auth + tracing + `Content-Type` are applied
 * by the client's interceptor chain; the empty `{}` body mirrors Dart's
 * `RunnerHttp.unsuspend()` (`data: {}`).
 */
internal class SuspendedRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : SuspendedRemoteDataSource {

    override suspend fun unsuspend(): Result<Unit, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/$UNSUSPEND_PATH", body = "{}"),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> Result.Err(result.error)
        }
    }

    private companion object {
        const val UNSUSPEND_PATH = "api/v1/runners/me/unsuspend"
    }
}
