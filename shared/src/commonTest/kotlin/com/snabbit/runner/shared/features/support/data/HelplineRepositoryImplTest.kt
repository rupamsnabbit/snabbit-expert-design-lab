package com.snabbit.runner.shared.features.support.data

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkConfig
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.network.resolveUrl
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Unit coverage for [HelplineRepositoryImpl] — mirrors the Flutter `SupportPopup` +
 * `launchDialer`: returns the fetched `ph_no`, and degrades to the RC SOS number on an
 * HTTP error, a 2xx body it can't parse, or a blank `ph_no`. Backed by a fake
 * [SnabbitHttpClient] (no real Ktor). `type=PRIMARY` is appended to the URL.
 */
class HelplineRepositoryImplTest {

    private val sosFallback = "+910000000000" // sentinel distinct from any API number

    private fun repo(
        client: SnabbitHttpClient,
        crashReporter: CrashReporter = CrashReporter { _, _ -> },
    ) = HelplineRepositoryImpl(
        httpClient = client,
        remoteConfig = FakeRemoteConfig(sos = sosFallback),
        crashReporter = crashReporter,
    )

    @Test
    fun helplineNumber_returnsPhNo_andHitsHelplinePathWithPrimaryType() = runTest {
        val client = FakeHttpClient(Result.Ok(success("""{"ph_no":"+911234500000"}""")))

        val number = repo(client).helplineNumber()

        assertEquals("+911234500000", number)
        assertEquals(
            "https://test.snabbit.com/api/v1/runners/me/helpline?type=PRIMARY",
            client.lastRequest?.url,
        )
    }

    @Test
    fun helplineNumber_appendsCustomType() = runTest {
        val client = FakeHttpClient(Result.Ok(success("""{"ph_no":"+911111100000"}""")))

        repo(client).helplineNumber(type = "RUNNER_JOB_IN_PROGRESS")

        assertEquals(
            "https://test.snabbit.com/api/v1/runners/me/helpline?type=RUNNER_JOB_IN_PROGRESS",
            client.lastRequest?.url,
        )
    }

    @Test
    fun helplineNumber_blankPhNo_fallsBackToSos() = runTest {
        val client = FakeHttpClient(Result.Ok(success("""{"ph_no":""}""")))

        assertEquals(sosFallback, repo(client).helplineNumber())
    }

    @Test
    fun helplineNumber_missingPhNo_fallsBackToSos() = runTest {
        val client = FakeHttpClient(Result.Ok(success("""{"other":"x"}""")))

        assertEquals(sosFallback, repo(client).helplineNumber())
    }

    @Test
    fun helplineNumber_httpError_fallsBackToSos_withoutReporting() = runTest {
        val reporter = RecordingReporter()
        val client = FakeHttpClient(
            Result.Err(
                NetworkError.HttpError(
                    statusCode = 500,
                    body = "boom",
                    errorType = AppErrorType.OTHER_ERROR,
                    requestId = "rid",
                    durationMs = 1L,
                ),
            ),
        )

        assertEquals(sosFallback, repo(client, reporter).helplineNumber())
        // Transport/HTTP errors are already reported by NetworkExceptionPlugin — don't double-report.
        assertTrue(reporter.count == 0)
    }

    @Test
    fun helplineNumber_unparseable2xx_fallsBackToSos_andReports() = runTest {
        val reporter = RecordingReporter()
        val client = FakeHttpClient(Result.Ok(success("not-json")))

        assertEquals(sosFallback, repo(client, reporter).helplineNumber())
        // A 2xx body our schema can't parse is a schema drift worth a non-fatal.
        assertTrue(reporter.count == 1)
    }

    // ── fakes ────────────────────────────────────────────────────────────────

    private class FakeRemoteConfig(private val sos: String) : RemoteConfigGateway {
        override fun getBool(key: String, default: Boolean) = default
        override fun getString(key: String, default: String) =
            if (key == HelplineRepository.RC_SOS_FALLBACK) sos else default
    }

    private class RecordingReporter : CrashReporter {
        var count = 0
            private set

        override fun report(throwable: Throwable, meta: Map<String, String>) {
            count++
        }
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
