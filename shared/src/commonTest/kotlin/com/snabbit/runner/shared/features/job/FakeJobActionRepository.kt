package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import kotlinx.coroutines.CompletableDeferred

/**
 * Test [JobActionRepository]. Records calls; set [acceptError] / [denyError] / … to make the
 * respective action return [Result.Err] with that [JobActionError] (null → [Result.Ok]).
 */
class FakeJobActionRepository(
    var acceptError: JobActionError? = null,
    var denyError: JobActionError? = null,
    var startJobError: JobActionError? = null,
    var checkInWithoutOtpError: JobActionError? = null,
    var checkoutError: JobActionError? = null,
    var rateCustomerError: JobActionError? = null,
    var fetchHouseTasksError: JobActionError? = null,
    var submitHouseTasksError: JobActionError? = null,
    /** Tasks returned by [fetchHouseTasks] when [fetchHouseTasksError] is null. */
    var houseTasks: List<HouseTask> = emptyList(),
) : JobActionRepository {

    val acceptCalls = mutableListOf<Pair<Int, JobLocation?>>()
    val denyCalls = mutableListOf<Pair<Int, JobLocation?>>()
    val checkArrivalCalls = mutableListOf<Int>()
    val startJobCalls = mutableListOf<Triple<Int, String?, JobLocation?>>()
    val checkInWithoutOtpCalls = mutableListOf<Triple<Int, String, JobLocation?>>()
    val checkoutCalls = mutableListOf<Int>()

    /** (jobId, rating) passed to [rateCustomer], in order. */
    val rateCustomerCalls = mutableListOf<Pair<Int, Int>>()
    val fetchHouseTasksCalls = mutableListOf<Int>()

    /** (jobId, keys) passed to [submitHouseTasks], in order. */
    val submitHouseTasksCalls = mutableListOf<Pair<Int, List<String>>>()

    private fun result(error: JobActionError?): Result<Unit, JobActionError> =
        error?.let { Result.Err(it) } ?: Result.Ok(Unit)

    /**
     * When set, [acceptJob] suspends on it instead of returning — so a test can hold an accept
     * in flight and act on the ViewModel while the POST is still outstanding (cancel its scope,
     * re-tap, advance time). Complete it to let the accept finish normally.
     */
    var acceptGate: CompletableDeferred<Unit>? = null

    override suspend fun acceptJob(jobId: Int, location: JobLocation?): Result<Unit, JobActionError> {
        acceptCalls += jobId to location
        acceptGate?.await()
        return result(acceptError)
    }

    override suspend fun denyJob(jobId: Int, location: JobLocation?): Result<Unit, JobActionError> {
        denyCalls += jobId to location
        return result(denyError)
    }

    override suspend fun checkArrival(jobId: Int): Result<Unit, JobActionError> {
        checkArrivalCalls += jobId
        return Result.Ok(Unit)
    }

    override suspend fun startJob(jobId: Int, otp: String?, location: JobLocation?): Result<Unit, JobActionError> {
        startJobCalls += Triple(jobId, otp, location)
        return result(startJobError)
    }

    override suspend fun checkInWithoutOtp(
        jobId: Int,
        customerPhone: String,
        location: JobLocation?,
        accuracyMeters: Int?,
    ): Result<Unit, JobActionError> {
        checkInWithoutOtpCalls += Triple(jobId, customerPhone, location)
        return result(checkInWithoutOtpError)
    }

    override suspend fun checkout(
        jobId: Int,
        location: JobLocation?,
        otp: String?,
        cashCollected: Boolean?,
    ): Result<Unit, JobActionError> {
        checkoutCalls += jobId
        return result(checkoutError)
    }

    override suspend fun rateCustomer(jobId: Int, rating: Int, location: JobLocation?): Result<Unit, JobActionError> {
        rateCustomerCalls += jobId to rating
        return result(rateCustomerError)
    }

    override suspend fun fetchHouseTasks(jobId: Int): Result<List<HouseTask>, JobActionError> {
        fetchHouseTasksCalls += jobId
        return fetchHouseTasksError?.let { Result.Err(it) } ?: Result.Ok(houseTasks)
    }

    override suspend fun submitHouseTasks(jobId: Int, keys: List<String>): Result<Unit, JobActionError> {
        submitHouseTasksCalls += jobId to keys
        return result(submitHouseTasksError)
    }
}
