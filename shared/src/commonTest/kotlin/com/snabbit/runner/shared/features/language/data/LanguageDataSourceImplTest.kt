package com.snabbit.runner.shared.features.language.data

import com.snabbit.runner.shared.core.CrashReporter
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
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Unit coverage for [LanguageDataSourceImpl] — URL construction, JSON-array
 * parsing into `LanguageOption`, unknown-field tolerance, and error mapping.
 * Backed by a fake [SnabbitHttpClient] (no real network / Ktor stack).
 */
class LanguageDataSourceImplTest {

    private val noopReporter = CrashReporter { _, _ -> }

    private fun dataSource(
        client: SnabbitHttpClient,
        crashReporter: CrashReporter = noopReporter,
    ) = LanguageDataSourceImpl(client, crashReporter)

    @Test
    fun getLanguages_parsesJsonArray_andHitsLanguageListPath() = runTest {
        val body = """
            [
              {"obj":"en","name":"English","name_native":"English","icon_text1":"A","icon_text2":"a"},
              {"obj":"hi","name":"Hindi","name_native":"हिन्दी","icon_text1":"अ","icon_text2":"आ"}
            ]
        """.trimIndent()
        val client = FakeHttpClient(Result.Ok(success(body)))

        val langs = dataSource(client).getLanguages()

        assertEquals(2, langs.size)
        assertEquals("en", langs[0].code)
        assertEquals("Hindi", langs[1].name)
        assertEquals("हिन्दी", langs[1].nameNative)
        assertEquals(
            "https://test.snabbit.com/api/v1/runners/language_list",
            client.lastRequest?.url,
        )
    }

    @Test
    fun getLanguages_tolerates_slashlessBaseUrl_and_unknownFields() = runTest {
        val body =
            """[{"obj":"en","name":"English","name_native":"English","icon_text1":"A","icon_text2":"a","added_later":42}]"""
        val client = FakeHttpClient(Result.Ok(success(body)), baseUrl = "https://test.snabbit.com")

        val langs = dataSource(client).getLanguages()

        assertEquals("en", langs.single().code)
        assertEquals(
            "https://test.snabbit.com/api/v1/runners/language_list",
            client.lastRequest?.url,
        )
    }

    @Test
    fun getLanguages_throwsAndReportsHttpError() = runTest {
        val err = NetworkError.HttpError(500, "boom", AppErrorType.SERVER_DOWN, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        assertFailsWith<LanguageNetworkException> {
            dataSource(FakeHttpClient(Result.Err(err)), reporter).getLanguages()
        }

        assertEquals(1, reported.size)
        assertEquals("getLanguages", reported.single().second["op"])
        assertEquals("500", reported.single().second["status"])
    }

    @Test
    fun setLanguage_patchesChangeLanguage_withLanguagePreferenceBody() = runTest {
        val client = FakeHttpClient(Result.Ok(success("")))

        dataSource(client).setLanguage("ENGLISH")

        assertEquals(HttpMethod.Patch, client.lastRequest?.method)
        assertEquals(
            "https://test.snabbit.com/api/v1/runners/me/change_language",
            client.lastRequest?.url,
        )
        assertEquals("""{"language_preference":"ENGLISH"}""", client.lastRequest?.body)
    }

    @Test
    fun setLanguage_throwsAndReportsHttpError() = runTest {
        val err = NetworkError.HttpError(500, "boom", AppErrorType.SERVER_DOWN, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        assertFailsWith<LanguageNetworkException> {
            dataSource(FakeHttpClient(Result.Err(err)), reporter).setLanguage("ENGLISH")
        }

        assertEquals(1, reported.size)
        assertEquals("setLanguage", reported.single().second["op"])
        assertEquals("500", reported.single().second["status"])
    }

    @Test
    fun setLanguage_doesNotReport_transportError() = runTest {
        // Transport failures are already reported by NetworkExceptionPlugin —
        // the datasource must not double-report them.
        val err = NetworkError.TransportError(AppErrorType.OTHER_ERROR, "rid", 1L)
        val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, meta -> reported += t to meta }

        assertFailsWith<LanguageNetworkException> {
            dataSource(FakeHttpClient(Result.Err(err)), reporter).setLanguage("ENGLISH")
        }

        assertTrue(reported.isEmpty())
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
