package com.snabbit.runner.shared.features.job.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Thin remote contract for job lifecycle actions. Returns the core [Result] type
 * so failures are values, not exceptions — [com.snabbit.runner.shared.features.job.data.repository.JobActionRepositoryImpl]
 * collapses the [NetworkError] into the domain [com.snabbit.runner.shared.features.job.domain.model.JobActionError].
 * Paths/bodies mirror the Flutter `JobHttp` (`lib/services/job_http.dart`).
 *
 * `suspend` + main-safe. Test doubles fake the repository, not this.
 */
internal interface JobActionRemoteDataSource {
    /** `POST api/v1/jobs/{jobId}/accept_job` — body `{job_id, location?}`. */
    suspend fun acceptJob(jobId: Int, location: JobLocation?): Result<Unit, NetworkError>

    /** `POST api/v1/jobs/{jobId}/deny_job` — body `{job_id, location?}`. */
    suspend fun denyJob(jobId: Int, location: JobLocation?): Result<Unit, NetworkError>

    /** `POST api/v1/jobs/{jobId}/check_arrival` — body `{job_id}` (mark arrival / no-OTP check-in). */
    suspend fun checkArrival(jobId: Int): Result<Unit, NetworkError>

    /** `POST api/v1/jobs/{jobId}/start_job` — body `{job_id, otp?, location?}` (OTP check-in). */
    suspend fun startJob(jobId: Int, otp: String?, location: JobLocation?): Result<Unit, NetworkError>

    /**
     * `POST api/v1/jobs/{jobId}/start_job` — body `{customer_phone_no, location?, accuracy_meters?}`
     * (no-OTP check-in: the customer's booking phone is verified in place of an OTP). Same endpoint
     * as [startJob] but a phone-number body — the backend branches on the fields.
     */
    suspend fun checkInWithoutOtp(
        jobId: Int,
        customerPhone: String,
        location: JobLocation?,
        accuracyMeters: Int?,
    ): Result<Unit, NetworkError>

    /** `POST api/v1/jobs/{jobId}/check_out` — body `{cash_collected?, checkout_otp?, location?}`. */
    suspend fun checkout(
        jobId: Int,
        location: JobLocation?,
        otp: String?,
        cashCollected: Boolean?,
    ): Result<Unit, NetworkError>

    /**
     * `POST api/v1/jobs/{jobId}/update_customer_rating` — body `{customer_rating, location?}`
     * (the runner rates the customer 1..5).
     */
    suspend fun rateCustomer(jobId: Int, rating: Int, location: JobLocation?): Result<Unit, NetworkError>

    /**
     * `GET api/v1/jobs/kmp/task_collection?job_id=` — the runner's selectable post-checkout house tasks
     * (KMP-specific endpoint). Returns the raw response body (a bare JSON array `[{key, asset_link}]`)
     * for the repository to parse.
     */
    suspend fun fetchTaskCollection(jobId: Int): Result<String, NetworkError>

    /**
     * `POST api/v1/jobs/{jobId}/update_task_collection` — [body] is the already-encoded
     * `{job_task_collection:[{key}]}` payload (built by the repository).
     */
    suspend fun submitTaskCollection(jobId: Int, body: String): Result<Unit, NetworkError>
}

/**
 * Production [JobActionRemoteDataSource] — posts the job lifecycle actions via the KMP
 * [SnabbitHttpClient]. Auth (Bearer) + tracing + `Content-Type: application/json` are applied
 * by the client's interceptor chain. `explicitNulls = false` omits null optional body fields,
 * matching the Flutter payloads (e.g. a missing location).
 */
internal class JobActionRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : JobActionRemoteDataSource {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }

    override suspend fun acceptJob(jobId: Int, location: JobLocation?) =
        post(jobId, "accept_job", json.encodeToString(JobIdLocationBody(jobId, location)))

    override suspend fun denyJob(jobId: Int, location: JobLocation?) =
        post(jobId, "deny_job", json.encodeToString(JobIdLocationBody(jobId, location)))

    override suspend fun checkArrival(jobId: Int) =
        post(jobId, "check_arrival", json.encodeToString(JobIdBody(jobId)))

    override suspend fun startJob(jobId: Int, otp: String?, location: JobLocation?) =
        post(jobId, "start_job", json.encodeToString(StartJobBody(jobId, otp, location)))

    override suspend fun checkInWithoutOtp(
        jobId: Int,
        customerPhone: String,
        location: JobLocation?,
        accuracyMeters: Int?,
    ) = post(
        jobId,
        "start_job",
        json.encodeToString(CheckInWithoutOtpBody(customerPhone, location, accuracyMeters)),
    )

    override suspend fun checkout(
        jobId: Int,
        location: JobLocation?,
        otp: String?,
        cashCollected: Boolean?,
    ) = post(jobId, "check_out", json.encodeToString(CheckoutBody(cashCollected, otp, location)))

    override suspend fun rateCustomer(jobId: Int, rating: Int, location: JobLocation?) =
        post(jobId, "update_customer_rating", json.encodeToString(RateCustomerBody(rating, location)))

    override suspend fun fetchTaskCollection(jobId: Int): Result<String, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "/api/v1/jobs/kmp/task_collection",
                query = mapOf("job_id" to jobId.toString()),
            ),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(result.value.body)
            is Result.Err -> Result.Err(result.error)
        }
    }

    override suspend fun submitTaskCollection(jobId: Int, body: String) =
        post(jobId, "update_task_collection", body)

    private suspend fun post(jobId: Int, action: String, body: String): Result<Unit, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "/api/v1/jobs/$jobId/$action",
                body = body,
            ),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> Result.Err(result.error)
        }
    }
}

/* ── Request bodies (mirror lib/services/job_http.dart) ──────────────────── */

@Serializable
private data class JobIdLocationBody(
    @SerialName("job_id") val jobId: Int,
    @SerialName("location") val location: JobLocation? = null,
)

@Serializable
private data class JobIdBody(
    @SerialName("job_id") val jobId: Int,
)

@Serializable
private data class StartJobBody(
    @SerialName("job_id") val jobId: Int,
    @SerialName("otp") val otp: String? = null,
    @SerialName("location") val location: JobLocation? = null,
)

@Serializable
private data class CheckInWithoutOtpBody(
    @SerialName("customer_phone_no") val customerPhoneNo: String,
    @SerialName("location") val location: JobLocation? = null,
    @SerialName("accuracy_meters") val accuracyMeters: Int? = null,
)

@Serializable
private data class CheckoutBody(
    @SerialName("cash_collected") val cashCollected: Boolean? = null,
    @SerialName("checkout_otp") val checkoutOtp: String? = null,
    @SerialName("location") val location: JobLocation? = null,
)

@Serializable
private data class RateCustomerBody(
    @SerialName("customer_rating") val customerRating: Int,
    @SerialName("location") val location: JobLocation? = null,
)
