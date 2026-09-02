package com.snabbit.runner.shared.features.job.data.repository

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.data.remote.JobActionRemoteDataSource
import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Bridges the data-layer [JobActionRemoteDataSource] to the domain [JobActionRepository]
 * contract. Every remote result flows through [toActionError], in priority order:
 *  - `errors[0].data.failure_type=LOCATION` → [JobActionError.CheckInLocation].
 *  - `errors[0].data.failure_type=PHONE_NUMBER` → [JobActionError.CheckInPhoneMismatch].
 *  - a server CustomError `errors[0].message` → [JobActionError.Server] (shown verbatim, ECPO #8).
 *  - 409 with no message → [JobActionError.Reassigned] (expected: the job was picked up by another
 *    expert; a normal race surfaced to the user, not a bug — skipped in crash reporting).
 *  - anything else → [JobActionError.Generic].
 *
 * HTTP errors (except 409) are reported to Crashlytics as non-fatals; transport errors are
 * skipped because `NetworkExceptionPlugin` already reports those. PII-safe: the raw response
 * body is never interpolated into the crash-report message.
 */
internal class JobActionRepositoryImpl(
    private val remote: JobActionRemoteDataSource,
    private val crashReporter: CrashReporter,
) : JobActionRepository {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun acceptJob(jobId: Int, location: JobLocation?) =
        remote.acceptJob(jobId, location).mapErr("acceptJob")

    override suspend fun denyJob(jobId: Int, location: JobLocation?) =
        remote.denyJob(jobId, location).mapErr("denyJob")

    override suspend fun checkArrival(jobId: Int) =
        remote.checkArrival(jobId).mapErr("checkArrival")

    override suspend fun startJob(jobId: Int, otp: String?, location: JobLocation?) =
        remote.startJob(jobId, otp, location).mapErr("startJob")

    override suspend fun checkInWithoutOtp(
        jobId: Int,
        customerPhone: String,
        location: JobLocation?,
        accuracyMeters: Int?,
    ) = remote.checkInWithoutOtp(jobId, customerPhone, location, accuracyMeters).mapErr("checkInWithoutOtp")

    override suspend fun checkout(
        jobId: Int,
        location: JobLocation?,
        otp: String?,
        cashCollected: Boolean?,
    ) = remote.checkout(jobId, location, otp, cashCollected).mapErr("checkout")

    override suspend fun rateCustomer(jobId: Int, rating: Int, location: JobLocation?) =
        remote.rateCustomer(jobId, rating, location).mapErr("rateCustomer")

    override suspend fun fetchHouseTasks(jobId: Int): Result<List<HouseTask>, JobActionError> =
        when (val result = remote.fetchTaskCollection(jobId)) {
            is Result.Ok -> parseHouseTasks(result.value)
            is Result.Err -> {
                report("fetchHouseTasks", result.error)
                Result.Err(toActionError(result.error))
            }
        }

    override suspend fun submitHouseTasks(jobId: Int, keys: List<String>): Result<Unit, JobActionError> =
        remote.submitTaskCollection(jobId, encodeTaskCollection(keys)).mapErr("submitHouseTasks")

    /**
     * Parses the `task_collection` body — a bare JSON array `[{key, asset_link}]` — into [HouseTask]s.
     * Drops entries with a null/blank key; a non-array body or a decode failure collapses to
     * [JobActionError.Generic] (mirrors the tolerant Flutter `HouseTask.fromJson`).
     */
    private fun parseHouseTasks(body: String): Result<List<HouseTask>, JobActionError> = try {
        val array = json.parseToJsonElement(body) as? JsonArray
            ?: return Result.Err(JobActionError.Generic)
        val tasks = array.mapNotNull { element ->
            val obj = element as? JsonObject ?: return@mapNotNull null
            val key = (obj["key"] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            HouseTask(key = key, imageUrl = (obj["asset_link"] as? JsonPrimitive)?.contentOrNull)
        }
        Result.Ok(tasks)
    } catch (e: SerializationException) {
        Result.Err(JobActionError.Generic)
    }

    /** Encodes the `update_task_collection` body — keys only: `{job_task_collection:[{key}]}`. */
    private fun encodeTaskCollection(keys: List<String>): String =
        json.encodeToString(TaskCollectionBody(keys.map { TaskCollectionKey(it) }))

    private fun Result<Unit, NetworkError>.mapErr(op: String): Result<Unit, JobActionError> = when (this) {
        is Result.Ok -> Result.Ok(Unit)
        is Result.Err -> {
            report(op, error)
            Result.Err(toActionError(error))
        }
    }

    private fun toActionError(error: NetworkError): JobActionError {
        // Parse the error body's errors[0] once and hand it to both extractors below.
        val firstError = parseFirstError(error)
        // Check-in failures carry a specific failure_type and drive dedicated UI — highest priority.
        when (checkInFailureOf(firstError)) {
            CheckInFailure.Location -> return JobActionError.CheckInLocation
            CheckInFailure.PhoneNumber -> return JobActionError.CheckInPhoneMismatch
            null -> Unit
        }
        // Otherwise prefer the server's CustomError copy (errors[0].message) so the user sees the
        // backend message instead of a hardcoded string (ECPO #8); fall back to Reassigned for a 409
        // race (its body carries no message) and Generic for everything else.
        serverMessageOf(firstError)?.let { return JobActionError.Server(it) }
        // A transport failure never reached the backend at all — keep it distinguishable from a
        // rejected request so `is_network_error` telemetry is truthful (it used to be hardcoded
        // false). User-facing copy is unchanged: `messageFor` still maps this to the generic toast.
        if (error is NetworkError.TransportError) return JobActionError.Network(error.errorType)
        return if (error is NetworkError.HttpError && error.statusCode == 409) {
            JobActionError.Reassigned
        } else {
            JobActionError.Generic
        }
    }

    private fun report(op: String, error: NetworkError) {
        if (error is NetworkError.HttpError && error.statusCode != 409) {
            crashReporter.report(
                JobActionReportException("Job action failed: HTTP ${error.statusCode}"),
                mapOf("op" to op, "status" to error.statusCode.toString()),
            )
        }
    }

    /** `errors[0]` of an HTTP error body, parsed once, or null when absent / not JSON. */
    private fun parseFirstError(error: NetworkError): JsonObject? {
        val body = (error as? NetworkError.HttpError)?.body ?: return null
        return try {
            val root = json.parseToJsonElement(body) as? JsonObject ?: return null
            (root["errors"] as? JsonArray)?.firstOrNull() as? JsonObject
        } catch (e: SerializationException) {
            null
        }
    }

    /** The check-in `failure_type` (`errors[0].data.failure_type`) mapped to a [CheckInFailure]. */
    private fun checkInFailureOf(firstError: JsonObject?): CheckInFailure? {
        val data = firstError?.get("data") as? JsonObject ?: return null
        val failureType = (data["failure_type"] as? JsonPrimitive)?.contentOrNull
        return CheckInFailure.fromKey(failureType)
    }

    /** The server's CustomError message (`errors[0].message`), or null when absent / blank. */
    private fun serverMessageOf(firstError: JsonObject?): String? =
        (firstError?.get("message") as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
}

/** Non-fatal carrier for Crashlytics reporting only — never surfaced to callers (they get [JobActionError]). */
private class JobActionReportException(message: String) : Exception(message)

/* ── update_task_collection request body (mirrors the Flutter HouseTask.toMap(): keys only) ──────── */

@Serializable
private data class TaskCollectionBody(
    @SerialName("job_task_collection") val jobTaskCollection: List<TaskCollectionKey>,
)

@Serializable
private data class TaskCollectionKey(
    @SerialName("key") val key: String,
)

/**
 * The `failure_type` a `start_job` error can carry (`errors[0].data.failure_type`), mirroring the
 * Flutter `check_in_without_otp` `FailureType`. A wire-level detail: [JobActionRepositoryImpl] parses
 * it and maps to the domain [JobActionError] the caller sees.
 */
internal enum class CheckInFailure(val key: String) {
    /** Runner is not at the job location — maps to [JobActionError.CheckInLocation]. */
    Location("LOCATION"),

    /** Entered phone number doesn't match the booking — maps to [JobActionError.CheckInPhoneMismatch]. */
    PhoneNumber("PHONE_NUMBER");

    companion object {
        /** Maps a wire `failure_type` value to a [CheckInFailure], or null if absent/unrecognised. */
        fun fromKey(key: String?): CheckInFailure? = entries.firstOrNull { it.key == key }
    }
}
