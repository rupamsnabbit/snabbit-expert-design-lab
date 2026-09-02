package com.snabbit.runner.shared.core.network.interceptors

import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.storage.StoreManager
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.http.HttpHeaders

/**
 * Injects identity/session headers (§3.1):
 *  - `Authorization: Bearer <token>` when a token is set on [storeManager].
 *  - `Session-Id: <value>` when the incoming [SnabbitRequest] carries one.
 *
 * The token is resolved via [resolveToken] *before* the (non-suspending) Ktor
 * request builder runs, because on a cold start (e.g. an overlay Accept from a
 * force-killed process) a request can outrace credential hydration — a plain
 * snapshot would be null and the request would go out unauthenticated. See
 * [StoreManager.awaitToken].
 */
class AuthInterceptor(private val storeManager: StoreManager) {

    /** Suspends until the token is hydrated, then returns it (null if logged out). */
    suspend fun resolveToken(): String? = storeManager.awaitToken()

    fun applyTo(builder: HttpRequestBuilder, request: SnabbitRequest, token: String?) {
        token?.let {
            builder.headers.append(HttpHeaders.Authorization, "Bearer $it")
        }
        request.sessionId?.let { sessionId ->
            builder.headers.append("Session-Id", sessionId)
        }
    }
}
