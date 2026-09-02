package com.snabbit.runner.shared.features.blocklist.data.repository

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import io.ktor.http.HttpMethod
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer

/**
 * Production [BlockListRepository] — talks to the runner preferences endpoint via the KMP
 * [SnabbitHttpClient] (mirrors [com.snabbit.runner.shared.features.language.data.LanguageDataSourceImpl]):
 *  - `GET api/v1/runners/me/preferences` — the blocked-customer entries.
 *  - `PUT api/v1/runners/me/preferences` — clears a customer's `pref_type` to unblock.
 *
 * The list endpoint returns a top-level JSON array of preference objects (nested customer / job); a
 * private DTO deserialises them and [toDomain] flattens each to a [BlockedCustomer]. Auth (Bearer) +
 * tracing + `Content-Type: application/json` are applied by the client's interceptor chain; this only
 * builds the requests against the pushed base URL. A failure maps to a typed
 * [BlockListNetworkException] (HTTP errors reported as non-fatals first — transport errors are already
 * reported by `NetworkExceptionPlugin`, so reporting again would double-count).
 */
class BlockListRepositoryImpl(
    private val httpClient: SnabbitHttpClient,
    private val crashReporter: CrashReporter,
) : BlockListRepository {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override suspend fun getBlockedCustomers(): List<BlockedCustomer> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$PREFERENCES_PATH"),
        )
        return when (result) {
            is Result.Ok -> runCatching {
                json.decodeFromString(ListSerializer(BlockedPreferenceDto.serializer()), result.value.body)
                    .mapNotNull { it.toDomain() }
            }.getOrElse { decodeError ->
                // A 2xx with a non-array/malformed body throws here — past reportAndWrap (Err-only), so
                // it would never be logged. Report it as a non-fatal, then rethrow so the caller still
                // surfaces its generic load error (mirrors isMaxCustomersBlocked's runCatching).
                crashReporter.report(decodeError, mapOf("op" to "getBlockedCustomers", "status" to "decode"))
                throw decodeError
            }
            is Result.Err -> throw reportAndWrap("getBlockedCustomers", result.error)
        }
    }

    override suspend fun unblock(customerId: Int, jobId: Int?) {
        // Match the Flutter unblock payload: an EXPLICIT `pref_type: null` clears the BLACKLISTED
        // preference (omitting it would leave the pref unchanged), plus the customer and — when
        // known — the originating job. Built by hand so the null is emitted while `job_id` is sent
        // only when present.
        val body = buildJsonObject {
            put("pref_type", JsonNull)
            put("customer_id", customerId)
            if (jobId != null) put("job_id", jobId)
        }.toString()
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Put, url = "/$PREFERENCES_PATH", body = body),
        )
        if (result is Result.Err) throw reportAndWrap("unblock", result.error)
    }

    override suspend fun block(customerId: Int, jobId: Int?) {
        // Match the Flutter `blockCustomer`: pref_type = BLACKLISTED + the customer (+ job when known).
        val body = buildJsonObject {
            put("pref_type", BLACKLISTED_PREF_TYPE)
            put("customer_id", customerId)
            if (jobId != null) put("job_id", jobId)
        }.toString()
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Put, url = "/$PREFERENCES_PATH", body = body),
        )
        if (result is Result.Err) {
            val error = result.error
            // At the block cap — an expected branch (the caller surfaces the "unblock to block" flow),
            // not a failure to report as a non-fatal. Mirrors the Flutter MAX_CUSTOMERS_BLOCKED handling.
            if (error is NetworkError.HttpError && error.isMaxCustomersBlocked()) {
                throw MaxCustomersBlockedException()
            }
            throw reportAndWrap("block", error)
        }
    }

    /** True when the error body carries the server's `MAX_CUSTOMERS_BLOCKED` code (`{errors:[{code}]}`). */
    private fun NetworkError.HttpError.isMaxCustomersBlocked(): Boolean = runCatching {
        json.decodeFromString(ErrorEnvelopeDto.serializer(), body)
            .errors.orEmpty().any { it.code == MAX_CUSTOMERS_BLOCKED_CODE }
    }.getOrDefault(false)

    private fun reportAndWrap(op: String, error: NetworkError): BlockListNetworkException {
        val exception = BlockListNetworkException(error)
        if (error is NetworkError.HttpError) {
            crashReporter.report(exception, mapOf("op" to op, "status" to error.statusCode.toString()))
        }
        return exception
    }

    private companion object {
        const val PREFERENCES_PATH = "api/v1/runners/me/preferences"
        const val BLACKLISTED_PREF_TYPE = "BLACKLISTED"
        const val MAX_CUSTOMERS_BLOCKED_CODE = "MAX_CUSTOMERS_BLOCKED"
    }
}

/**
 * Raised when a block-list network call fails (HTTP or transport). [BlockListViewModel] catches any
 * [Throwable] and surfaces a generic message, so a typed wrapper is enough — [error] is kept for logging.
 */
class BlockListNetworkException(
    val error: NetworkError,
) : Exception("Block list network call failed: $error")

/**
 * Raised by [BlockListRepository.block] when the runner is already at the block cap (server
 * `MAX_CUSTOMERS_BLOCKED`). An expected branch — the caller surfaces the "unblock to block" flow —
 * so it is deliberately NOT reported as a crash non-fatal.
 */
class MaxCustomersBlockedException : Exception("Runner is at the maximum blocked-customers limit")
