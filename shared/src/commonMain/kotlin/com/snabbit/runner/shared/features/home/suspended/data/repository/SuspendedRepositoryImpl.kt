package com.snabbit.runner.shared.features.home.suspended.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.suspended.data.remote.SuspendedRemoteDataSource
import com.snabbit.runner.shared.features.home.suspended.data.remote.dto.UnsuspendDeniedDto
import com.snabbit.runner.shared.features.home.suspended.data.remote.dto.UnsuspendFailedDto
import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult
import com.snabbit.runner.shared.features.home.suspended.domain.repository.SuspendedRepository
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Bridges the data-layer [SuspendedRemoteDataSource] to the domain
 * [SuspendedRepository]. Owns the status mapping that mirrors Dart's
 * `RunnerSuspended._onComeBackToWorkTapped`:
 *  - **200** (`Result.Ok`) or **409** → [UnsuspendResult.Reactivated]
 *    (409 = reactivation already requested; Dart treats it as success).
 *  - **400** → decode `{status, message}` → [UnsuspendResult.Denied]; a
 *    malformed body falls back to `"unknown"` for each field so the UI still
 *    locks the button (parity with Dart's `?? 'unknown'`).
 *  - anything else / transport → [UnsuspendResult.Failed] with the status code
 *    when we have one (null for a transport failure).
 */
internal class SuspendedRepositoryImpl(
    private val remote: SuspendedRemoteDataSource,
) : SuspendedRepository {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun unsuspend(): UnsuspendResult =
        when (val r = remote.unsuspend()) {
            is Result.Ok -> UnsuspendResult.Reactivated(statusCode = OK)
            is Result.Err -> r.error.toUnsuspendResult()
        }

    private fun NetworkError.toUnsuspendResult(): UnsuspendResult = when (this) {
        is NetworkError.TransportError -> UnsuspendResult.Failed(statusCode = null)
        is NetworkError.HttpError -> when (statusCode) {
            CONFLICT -> UnsuspendResult.Reactivated(statusCode = CONFLICT)
            BAD_REQUEST -> parseDenied(body)
            else -> UnsuspendResult.Failed(statusCode = statusCode, message = parseFailedMessage(body))
        }
    }

    /** Decode the 400 body; a malformed payload still denies with `"unknown"`
     *  fields so the button locks exactly as Dart does. */
    private fun parseDenied(body: String): UnsuspendResult.Denied {
        val dto = try {
            json.decodeFromString<UnsuspendDeniedDto>(body)
        } catch (_: SerializationException) {
            null
        }
        return UnsuspendResult.Denied(
            reason = dto?.status ?: UNKNOWN,
            message = dto?.message ?: UNKNOWN,
        )
    }

    /** Non-400 failure body: Dart shows `message` ?? `detail` when present, else the
     *  generic string. Returns null on a malformed/empty body (→ generic snackbar). */
    private fun parseFailedMessage(body: String): String? {
        val dto = try {
            json.decodeFromString<UnsuspendFailedDto>(body)
        } catch (_: SerializationException) {
            null
        }
        return dto?.message?.takeIf { it.isNotBlank() } ?: dto?.detail?.takeIf { it.isNotBlank() }
    }

    private companion object {
        const val OK = 200
        const val BAD_REQUEST = 400
        const val CONFLICT = 409
        const val UNKNOWN = "unknown"
    }
}
