package com.snabbit.runner.shared.features.job.data.repository

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkConfig
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.network.resolveUrl
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.data.remote.JobActionRemoteDataSourceImpl
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import io.ktor.http.HttpMethod
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Unit coverage for [JobActionRepositoryImpl] wired to a real
 * [com.snabbit.runner.shared.features.job.data.remote.JobActionRemoteDataSourceImpl] — exercises URL
 * construction, request bodies (mirroring `lib/services/job_http.dart`), and NetworkError→[JobActionError]
 * mapping through the same stack production uses. Backed by a fake [SnabbitHttpClient] (no real Ktor).
 */
class JobActionRepositoryImplTest {

    private val noopReporter = CrashReporter { _, _ -> }

    private fun repo(
        client: SnabbitHttpClient,
        crashReporter: CrashReporter = noopReporter,
    ) = JobActionRepositoryImpl(
        remote = JobActionRemoteDataSourceImpl(client),
        crashReporter = crashReporter,
    )

    @Test
    fun acceptJob_postsAcceptJobPath_withJobIdAndLocation() = runTest {
        val client = FakeHttpClient(Result.Ok(success("")))

        assertEquals(Result.Ok(Unit), repo(client).acceptJob(739, JobLocation(1.0, 2.0)))

        assertEquals(HttpMethod.Post, client.lastRequest?.method)
        assertEquals(
            "https://test.snabbit.com/api/v1/jobs/739/accept_job",
            client.lastRequest?.url,
        )
        assertEquals(
            """{"job_id":739,"location":{"lat":1.0,"lng":2.0}}""",
            client.lastRequest?.body,
        )
    }

    @Test
    fun denyJob_omitsLocation_whenNull() = runTest {
        val client = FakeHttpClient(Result.Ok(success("")))

        repo(client).denyJob(739, null)

        assertEquals(
            "https://test.snabbit.com/api/v1/jobs/739/deny_job",
            client.lastRequest?.url,
        )
        assertEquals("""{"job_id":739}""", client.lastRequest?.body)
    }

    @Test
    fun checkArrival_postsCheckArrival_jobIdOnly() = runTest {
        val client = FakeHttpClient(Result.Ok(success("")))

        repo(client).checkArrival(739)

        assertEquals(
            "https://test.snabbit.com/api/v1/jobs/739/check_arrival",
            client.lastRequest?.url,
        )
        assertEquals("""{"job_id":739}""", client.lastRequest?.body)
    }

    @Test
    fun acceptJob_409Reassigned_mapsReassigned_andDoesNotReport() = runTest {
        // 409 = job reassigned to another expert: an expected race surfaced to the user, not a bug,
        // so it must NOT be reported as a non-fatal (avoids Crashlytics noise).
        val err = NetworkError.HttpError(409, "gone", AppErrorType.OTHER_ERROR, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        val result = repo(FakeHttpClient(Result.Err(err)), reporter).acceptJob(739, null)

        assertEquals(Result.Err(JobActionError.Reassigned), result)
        assertTrue(reported.isEmpty())
    }

    @Test
    fun acceptJob_409WithCustomError_surfacesServerMessage() = runTest {
        // ECPO #8: a CustomError body (errors[0].message) is surfaced verbatim instead of the
        // hardcoded "reassigned" copy; still a 409, so it stays unreported.
        val body = """{"errors":[{"code":"JOB_TAKEN","message":"This job is no longer available."}]}"""
        val err = NetworkError.HttpError(409, body, AppErrorType.OTHER_ERROR, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        val result = repo(FakeHttpClient(Result.Err(err)), reporter).acceptJob(739, null)

        assertEquals(Result.Err(JobActionError.Server("This job is no longer available.")), result)
        assertTrue(reported.isEmpty())
    }

    @Test
    fun acceptJob_serverError_mapsGeneric_andIsReported() = runTest {
        val err = NetworkError.HttpError(500, "boom", AppErrorType.SERVER_DOWN, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        val result = repo(FakeHttpClient(Result.Err(err)), reporter).acceptJob(739, null)

        assertEquals(Result.Err(JobActionError.Generic), result)
        assertEquals(1, reported.size)
        assertEquals("acceptJob", reported.single().second["op"])
        assertEquals("500", reported.single().second["status"])
    }

    @Test
    fun acceptJob_transportError_mapsNetwork_andDoesNotReport() = runTest {
        // Transport failures used to collapse into Generic alongside real 4xx/5xx rejections, which
        // is why `is_network_error` could only ever be reported as false. They now carry their own
        // variant (and the AppErrorType) so "never reached the backend" is separable downstream.
        // Still not crash-reported here — NetworkExceptionPlugin already reports transport throwables.
        val err = NetworkError.TransportError(AppErrorType.NO_INTERNET, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        val result = repo(FakeHttpClient(Result.Err(err)), reporter).acceptJob(739, null)

        assertEquals(Result.Err(JobActionError.Network(AppErrorType.NO_INTERNET)), result)
        assertTrue(reported.isEmpty())
    }

    @Test
    fun acceptJob_httpErrorWithoutMessage_stillMapsGeneric() = runTest {
        // Guard the split: a rejected request with no usable body must NOT drift into Network just
        // because it also has no message — Generic still means "the backend answered, badly".
        val err = NetworkError.HttpError(500, "", AppErrorType.SERVER_DOWN, "rid", 1L)

        val result = repo(FakeHttpClient(Result.Err(err))).acceptJob(739, null)

        assertEquals(Result.Err(JobActionError.Generic), result)
    }

    @Test
    fun checkInWithoutOtp_postsStartJob_withPhoneLocationAccuracy() = runTest {
        val client = FakeHttpClient(Result.Ok(success("")))

        repo(client).checkInWithoutOtp(739, "9876543210", JobLocation(1.0, 2.0), 25)

        assertEquals(
            "https://test.snabbit.com/api/v1/jobs/739/start_job",
            client.lastRequest?.url,
        )
        assertEquals(
            """{"customer_phone_no":"9876543210","location":{"lat":1.0,"lng":2.0},"accuracy_meters":25}""",
            client.lastRequest?.body,
        )
    }

    @Test
    fun checkInWithoutOtp_locationFailure_mapsCheckInLocation() = runTest {
        val body = """{"errors":[{"data":{"failure_type":"LOCATION"}}]}"""
        val err = NetworkError.HttpError(400, body, AppErrorType.INVALID_REQUEST, "rid", 1L)

        val result = repo(FakeHttpClient(Result.Err(err))).checkInWithoutOtp(739, "9876543210", null, null)

        assertEquals(Result.Err(JobActionError.CheckInLocation), result)
    }

    @Test
    fun checkInWithoutOtp_phoneNumberFailure_mapsCheckInPhoneMismatch() = runTest {
        val body = """{"errors":[{"data":{"failure_type":"PHONE_NUMBER"}}]}"""
        val err = NetworkError.HttpError(400, body, AppErrorType.INVALID_REQUEST, "rid", 1L)

        val result = repo(FakeHttpClient(Result.Err(err))).checkInWithoutOtp(739, "9876543210", null, null)

        assertEquals(Result.Err(JobActionError.CheckInPhoneMismatch), result)
    }

    @Test
    fun checkInWithoutOtp_nonJsonBody_mapsGeneric() = runTest {
        val err = NetworkError.HttpError(400, "gone", AppErrorType.INVALID_REQUEST, "rid", 1L)

        val result = repo(FakeHttpClient(Result.Err(err))).checkInWithoutOtp(739, "9876543210", null, null)

        assertEquals(Result.Err(JobActionError.Generic), result)
    }

    @Test
    fun checkInWithoutOtp_absentOrUnknownFailureType_mapsGeneric() = runTest {
        // Valid JSON, but no `data.failure_type` (and an unknown value in a second error) → Generic.
        val body = """{"errors":[{"code":"X"},{"data":{"failure_type":"SOMETHING_ELSE"}}]}"""
        val err = NetworkError.HttpError(400, body, AppErrorType.INVALID_REQUEST, "rid", 1L)

        val result = repo(FakeHttpClient(Result.Err(err))).checkInWithoutOtp(739, "9876543210", null, null)

        assertEquals(Result.Err(JobActionError.Generic), result)
    }

    private fun success(body: String) = SuccessResponse(
        statusCode = 200,
        body = body,
        headers = emptyMap(),
        requestId = "rid",
        durationMs = 1L,
    )

    private class FakeHttpClient(
        private val result: Result<SuccessResponse, NetworkError>,
        private val baseUrl: String = "https://test.snabbit.com/",
    ) : SnabbitHttpClient {
        var lastRequest: SnabbitRequest? = null

        override suspend fun execute(
            request: SnabbitRequest,
        ): Result<SuccessResponse, NetworkError> {
            lastRequest = request.copy(
                url = request.resolveUrl(NetworkConfig(baseUrl = baseUrl, versionCode = "1")),
            )
            return result
        }

        override fun close() {}
    }
}
