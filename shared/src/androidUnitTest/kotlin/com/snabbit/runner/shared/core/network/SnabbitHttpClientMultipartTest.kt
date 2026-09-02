package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import org.junit.Test
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Smoke test for the multipart wiring in [SnabbitHttpClientImpl] — needs a
 * real file on disk because [readFileBytes] reads via the platform actual
 * (`java.io.File.readBytes` here), so it lives in androidUnitTest.
 *
 * Asserts the wire body carries the multipart boundary + the file bytes;
 * the multipart codec itself is Ktor's, we only verify our call site hands
 * it the right [FormPart.File] data.
 */
class SnabbitHttpClientMultipartTest {

    @Test
    fun execute_multipart_buildsBodyWithFilePartAndBoundary() = runTest {
        val tempFile = File.createTempFile("selfie", ".jpg").apply {
            writeBytes(byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x05))
            deleteOnExit()
        }
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "${TEST_BASE_URL}api/v1/runners/me/shift/login",
                query = mapOf("lat" to "12.34", "lng" to "56.78"),
                formParts = listOf(
                    FormPart.File(
                        name = "file",
                        filePath = tempFile.absolutePath,
                        filename = "selfie.jpg",
                        mimeType = "image/jpeg",
                    ),
                ),
            ),
        )

        assertTrue(result is Result.Ok, "result=$result")
        val recorded = engine.requestHistory.single()
        val contentType = recorded.body.contentType?.toString().orEmpty()
        assertTrue("multipart/form-data" in contentType, "contentType=$contentType")
        assertTrue("boundary=" in contentType, "contentType=$contentType")

        val bodyBytes = recorded.body.toByteArray()
        val bodyText = bodyBytes.decodeToString(throwOnInvalidSequence = false)
        assertTrue("name=\"file\"" in bodyText, "missing form field name; body=$bodyText")
        assertTrue("filename=\"selfie.jpg\"" in bodyText, "missing filename; body=$bodyText")
        assertTrue("image/jpeg" in bodyText, "missing mime; body=$bodyText")
        // The 5-byte payload survives intact between part headers and the trailing boundary.
        assertTrue(
            byteSequenceContains(bodyBytes, byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x05)),
            "missing raw file bytes in multipart body",
        )

        assertEquals(200, (result as Result.Ok).value.statusCode)
    }

    private fun byteSequenceContains(haystack: ByteArray, needle: ByteArray): Boolean {
        if (needle.isEmpty() || haystack.size < needle.size) return false
        outer@ for (i in 0..haystack.size - needle.size) {
            for (j in needle.indices) {
                if (haystack[i + j] != needle[j]) continue@outer
            }
            return true
        }
        return false
    }
}
