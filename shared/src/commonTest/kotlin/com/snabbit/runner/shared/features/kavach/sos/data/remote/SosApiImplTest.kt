package com.snabbit.runner.shared.features.kavach.sos.data.remote

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.features.kavach.testPreflight
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkConfig
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.network.resolveUrl
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Verifies the exact E1–E4 paths, request bodies, and response parsing (backend contract). */
class SosApiImplTest {

    private val reporter = CrashReporter { _, _ -> }
    private fun ok(body: String) = Result.Ok(SuccessResponse(200, body, emptyMap(), "rid", 1L))

    private class FakeHttp(
        private val result: Result<SuccessResponse, NetworkError>,
        private val base: String = "https://test.snabbit.com/",
    ) : SnabbitHttpClient {
        var last: SnabbitRequest? = null
        override suspend fun execute(request: SnabbitRequest): Result<SuccessResponse, NetworkError> {
            last = request.copy(
                url = request.resolveUrl(NetworkConfig(baseUrl = base, versionCode = "1")),
            )
            return result
        }
        override fun close() {}
    }

    @Test
    fun initiate_postsBodyAndParsesSosId() = runTest {
        val http = FakeHttp(ok("""{"sos_id":42}"""))
        val id = SosApiImpl(http, reporter, testPreflight()).initiate(source = "ml", triggerType = "ml", jobId = 7)
        assertEquals(42, id)
        assertEquals("https://test.snabbit.com/api/v1/runners/me/sos/initiate", http.last?.url)
        assertEquals(HttpMethod.Post, http.last?.method)
        assertTrue(http.last?.body?.contains("\"source\":\"ml\"") == true)
        assertTrue(http.last?.body?.contains("\"job_id\":7") == true)
    }

    @Test
    fun initiate_omitsJobIdWhenNull() = runTest {
        val http = FakeHttp(ok("""{"sos_id":1}"""))
        SosApiImpl(http, reporter, testPreflight()).initiate(source = "manual", triggerType = "non_ml", jobId = null)
        assertEquals(false, http.last?.body?.contains("job_id"))
    }

    @Test
    fun resolve_postsUserActionAndParsesPhone() = runTest {
        val http = FakeHttp(ok("""{"ph_no":"999"}"""))
        val out = SosApiImpl(http, reporter, testPreflight()).resolve(sosId = 42, action = SosUserAction.CONFIRM)
        assertEquals("999", out.phoneNumber)
        assertTrue(out.delivered)
        assertEquals("https://test.snabbit.com/api/v1/runners/me/sos", http.last?.url)
        assertTrue(http.last?.body?.contains("\"user_action\":\"confirm\"") == true)
        assertTrue(http.last?.body?.contains("\"sos_id\":42") == true)
    }

    @Test
    fun resolve_httpError_isNotDelivered() = runTest {
        // A failed resolve used to be indistinguishable from a successful deny (both gave a null
        // phone), so the caller cleared local state for an SOS the backend still had open.
        val err = Result.Err(
            NetworkError.HttpError(statusCode = 500, body = "", errorType = AppErrorType.SERVER_DOWN, requestId = "r", durationMs = 1L),
        )
        val out = SosApiImpl(FakeHttp(err), reporter, testPreflight()).resolve(sosId = 42, action = SosUserAction.DENY)
        assertEquals(false, out.delivered)
    }

    @Test
    fun resolve_2xxWithoutPhone_isStillDelivered() = runTest {
        // ph_no is legitimately absent on a successful deny/dismiss — that must not read as failure.
        val out = SosApiImpl(FakeHttp(ok("{}")), reporter, testPreflight()).resolve(sosId = 1, action = SosUserAction.DENY)
        assertTrue(out.delivered)
        assertEquals(null, out.phoneNumber)
    }

    @Test
    fun active_missingHasActiveSos_returnsNull_soReconcileCannotClearLiveSos() = runTest {
        // Wrong-shape 200 (envelope change / proxy error page). With has_active_sos defaulted to
        // false this decoded as "no active SOS" and reconcile() wiped a live one.
        val http = FakeHttp(ok("""{"data":{"something":"else"}}"""))
        assertEquals(null, SosApiImpl(http, reporter, testPreflight()).active())
    }

    @Test
    fun active_explicitFalse_stillParses() = runTest {
        // The genuine "no active SOS" answer must still come through, else reconcile can never
        // recover a stale local SOS to idle.
        val http = FakeHttp(ok("""{"has_active_sos":false}"""))
        val s = SosApiImpl(http, reporter, testPreflight()).active()
        assertEquals(false, s?.hasActiveSos)
    }

    @Test
    fun active_getsAndParsesSnapshot() = runTest {
        val http = FakeHttp(ok("""{"has_active_sos":true,"sos":{"status":"pending","sos_id":5,"ph_no":"111"}}"""))
        val s = SosApiImpl(http, reporter, testPreflight()).active()
        assertEquals(true, s?.hasActiveSos)
        assertEquals("pending", s?.status)
        assertEquals(5, s?.sosId)
        assertEquals("111", s?.phoneNumber)
        assertEquals("https://test.snabbit.com/api/v1/runners/me/sos/active", http.last?.url)
        assertEquals(HttpMethod.Get, http.last?.method)
    }

    @Test
    fun callSosTeam_postsPhonePath() = runTest {
        val http = FakeHttp(ok(""))
        assertTrue(SosApiImpl(http, reporter, testPreflight()).callSosTeam("555"))
        assertEquals("https://test.snabbit.com/api/v1/runners/phone_call/555", http.last?.url)
        assertEquals(HttpMethod.Post, http.last?.method)
    }

    @Test
    fun callSosTeam_blankPhone_skipsRequest() = runTest {
        val http = FakeHttp(ok(""))
        assertEquals(false, SosApiImpl(http, reporter, testPreflight()).callSosTeam("  "))
        assertNull(http.last)
    }
}
