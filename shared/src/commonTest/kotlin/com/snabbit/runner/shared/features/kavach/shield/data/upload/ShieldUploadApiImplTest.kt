package com.snabbit.runner.shared.features.kavach.shield.data.upload

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
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Verifies the U1–U3 paths/query/body/parsing + 409-as-done, against the backend contract. */
class ShieldUploadApiImplTest {

    private val reporter = CrashReporter { _, _ -> }
    private fun ok(body: String) = Result.Ok(SuccessResponse(200, body, emptyMap(), "rid", 1L))
    private fun conflict() = Result.Err(
        NetworkError.HttpError(statusCode = 409, body = "", errorType = AppErrorType.OTHER_ERROR, requestId = "rid", durationMs = 1L),
    )

    private val encryption = ShieldEncryptionMetadata(encryptedKey = "EK", iv = "IV", authTag = "TAG")

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

    private fun api(http: SnabbitHttpClient, s3: HttpClient = HttpClient(MockEngine { respond("", HttpStatusCode.OK) })) =
        ShieldUploadApiImpl(http, s3, reporter, testPreflight())

    // ── U1 presigned ──

    @Test
    fun presigned_getsWithQuery_andParsesResponse() = runTest {
        val http = FakeHttp(
            ok("""{"presigned_url":"https://s3/put","s3_key":"k/1.m4a","max_file_size_bytes":1048576,"allowed_content_types":["audio/mp4"]}"""),
        )
        val out = api(http).getPresignedUrl(jobId = 7, timestamp = 1000L, isSos = true)
        assertTrue(out is UploadOutcome.Ok)
        assertEquals("https://s3/put", out.value.url)
        assertEquals("k/1.m4a", out.value.s3Key)
        assertEquals(1048576L, out.value.maxFileSizeBytes)
        assertEquals("audio/mp4", out.value.contentType)
        assertEquals("https://test.snabbit.com/api/v1/audio/presigned-url", http.last?.url)
        assertEquals(HttpMethod.Get, http.last?.method)
        assertEquals("7", http.last?.query?.get("job_id"))
        assertEquals("1000", http.last?.query?.get("timestamp"))
        assertEquals("true", http.last?.query?.get("is_sos"))
    }

    @Test
    fun presigned_defaultsContentTypeWhenNoneAllowed() = runTest {
        val http = FakeHttp(ok("""{"presigned_url":"u","s3_key":"k"}"""))
        val out = api(http).getPresignedUrl(jobId = 1, timestamp = 1L, isSos = false)
        assertTrue(out is UploadOutcome.Ok)
        assertEquals("audio/mp4", out.value.contentType)
    }

    @Test
    fun presigned_409_isConflict() = runTest {
        val out = api(FakeHttp(conflict())).getPresignedUrl(jobId = 1, timestamp = 1L, isSos = false)
        assertEquals(UploadOutcome.Conflict, out)
    }

    // ── U2 S3 PUT (raw client) ──

    @Test
    fun s3Put_200_returnsTrue() = runTest {
        var method: HttpMethod? = null
        var url: String? = null
        val s3 = HttpClient(MockEngine { req -> method = req.method; url = req.url.toString(); respond("", HttpStatusCode.OK) })
        val ok = ShieldUploadApiImpl(FakeHttp(ok("")), s3, reporter, testPreflight())
            .uploadToS3("https://s3/put", byteArrayOf(1, 2, 3), "audio/mp4")
        assertTrue(ok)
        assertEquals(HttpMethod.Put, method)
        assertEquals("https://s3/put", url)
    }

    @Test
    fun s3Put_non200_returnsFalse() = runTest {
        val s3 = HttpClient(MockEngine { respond("denied", HttpStatusCode.Forbidden) })
        val ok = ShieldUploadApiImpl(FakeHttp(ok("")), s3, reporter, testPreflight()).uploadToS3("https://s3/put", byteArrayOf(1), "audio/mp4")
        assertEquals(false, ok)
    }

    // ── U3 confirm ──

    @Test
    fun confirm_postsEnvelopeBody() = runTest {
        val http = FakeHttp(ok("""{"recording_id":"r1","status":"ok"}"""))
        val out = api(http).confirmUpload(
            jobId = 7, timestamp = 1000L, s3Key = "k/1.m4a", isSos = true,
            encryption = encryption, durationSeconds = 30, isCompressed = true,
        )
        assertEquals(UploadOutcome.Ok(Unit), out)
        assertEquals("https://test.snabbit.com/api/v1/audio/upload-complete", http.last?.url)
        assertEquals(HttpMethod.Post, http.last?.method)
        val body = http.last?.body ?: ""
        assertTrue(body.contains("\"job_id\":7"))
        assertTrue(body.contains("\"s3_key\":\"k/1.m4a\""))
        assertTrue(body.contains("\"is_sos\":true"))
        assertTrue(body.contains("\"file_extension\":\"m4a\""))
        assertTrue(body.contains("\"is_compressed\":true"))
        assertTrue(body.contains("\"encrypted_key\":\"EK\""))
        assertTrue(body.contains("\"auth_tag\":\"TAG\""))
        assertTrue(body.contains("\"algorithm\":\"AES-256-GCM\""))
        assertTrue(body.contains("\"key_wrap_algorithm\":\"RSA-OAEP-256\""))
        assertTrue(body.contains("\"key_version\":\"v1\""))
    }

    @Test
    fun confirm_409_isConflict() = runTest {
        val out = api(FakeHttp(conflict())).confirmUpload(
            jobId = 1, timestamp = 1L, s3Key = "k", isSos = false,
            encryption = encryption, durationSeconds = 1, isCompressed = false,
        )
        assertEquals(UploadOutcome.Conflict, out)
    }
}
