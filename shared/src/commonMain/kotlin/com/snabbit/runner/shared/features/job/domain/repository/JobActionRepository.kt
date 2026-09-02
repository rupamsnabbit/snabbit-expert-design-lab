package com.snabbit.runner.shared.features.job.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobLocation

/**
 * Domain port for the job lifecycle actions the runner takes (accept / deny / check-in /
 * check-out / rate). Each call returns [Result.Ok] on success or [Result.Err] with a domain
 * [JobActionError] — it never throws for an HTTP or transport failure. Success is envelope-driven:
 * the caller refreshes `current_state` to advance the lifecycle.
 *
 * The production implementation in `data/repository/JobActionRepositoryImpl` translates
 * data-layer `NetworkError` into the domain error sealed type. Test doubles fake this interface
 * directly (see `FakeJobActionRepository`).
 */
interface JobActionRepository {
    /** Accept the offered job. */
    suspend fun acceptJob(jobId: Int, location: JobLocation?): Result<Unit, JobActionError>

    /** Deny the offered job. */
    suspend fun denyJob(jobId: Int, location: JobLocation?): Result<Unit, JobActionError>

    /** Mark the runner as arrived at the customer location (no-OTP check-in). */
    suspend fun checkArrival(jobId: Int): Result<Unit, JobActionError>

    /**
     * OTP check-in: start the job with the customer-shared OTP.
     *
     * **[location] is deliberately null at the production call sites** — an absent location makes
     * the backend skip its 25 m check-in geofence (product decision, see PR #596). Passing a
     * location here silently re-enables that geofence; don't do it without product sign-off.
     */
    suspend fun startJob(jobId: Int, otp: String?, location: JobLocation?): Result<Unit, JobActionError>

    /**
     * Phone-fallback check-in: the customer's booking phone number is verified in place of an OTP.
     * Backend surfaces failure_type `LOCATION` (→ [JobActionError.CheckInLocation]) or `PHONE_NUMBER`
     * (→ [JobActionError.CheckInPhoneMismatch]) when the runner is too far or the phone doesn't match.
     *
     * **Same geofence warning as [startJob]:** [location] is deliberately null at the production
     * call sites — passing one silently re-enables the backend's 25 m check-in geofence.
     */
    suspend fun checkInWithoutOtp(
        jobId: Int,
        customerPhone: String,
        location: JobLocation?,
        accuracyMeters: Int?,
    ): Result<Unit, JobActionError>

    /** End the job (`check_out`). */
    suspend fun checkout(
        jobId: Int,
        location: JobLocation?,
        otp: String?,
        cashCollected: Boolean?,
    ): Result<Unit, JobActionError>

    /** Post the runner's 1..5 rating of the customer at completion. */
    suspend fun rateCustomer(jobId: Int, rating: Int, location: JobLocation?): Result<Unit, JobActionError>

    /**
     * Fetch the selectable post-checkout house tasks for [jobId] (backend `task_collection`). Parse
     * failures / a non-array body collapse to [JobActionError.Generic].
     */
    suspend fun fetchHouseTasks(jobId: Int): Result<List<HouseTask>, JobActionError>

    /** Submit the house-task [keys] the runner marked done at checkout (`update_task_collection`). */
    suspend fun submitHouseTasks(jobId: Int, keys: List<String>): Result<Unit, JobActionError>
}
