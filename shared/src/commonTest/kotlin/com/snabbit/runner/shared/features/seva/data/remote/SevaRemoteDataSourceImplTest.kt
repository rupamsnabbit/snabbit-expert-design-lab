package com.snabbit.runner.shared.features.seva.data.remote

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.jsonHeaders
import com.snabbit.runner.shared.core.network.makeTestClient
import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

/**
 * Branch coverage for [SevaRemoteDataSourceImpl] over a Ktor MockEngine:
 * decode-success, malformed-body → synthetic HttpError, and server-error
 * passthrough. Also asserts the radius is clamped into the query.
 */
class SevaRemoteDataSourceImplTest {

    private val okBody = """
        {"washrooms":[{"id":"W1","name":"Loo","category":"Cafe",
          "dLat":28.61,"dLng":77.20,"road":"Main St","distance":100}],
         "restingPlaces":[]}
    """.trimIndent()

    @Test fun success_decodesPoints_andClampsRadiusInQuery() = runTest {
        val engine = MockEngine { respond(okBody, HttpStatusCode.OK, jsonHeaders()) }
        val ds = SevaRemoteDataSourceImpl(makeTestClient(engine), FakeLogger())

        // radius above the 1000 ceiling must be clamped, not sent verbatim.
        val result = ds.nearby(lat = 28.6, lng = 77.2, radius = 5000, type = "all")

        val ok = assertIs<Result.Ok<List<*>>>(result)
        assertEquals(1, ok.value.size)
        val q = engine.requestHistory.single().url.parameters
        assertEquals("1000", q["radius"])
        assertEquals("all", q["type"])
        assertEquals("28.6", q["lat"])
        assertEquals("77.2", q["lng"])
    }

    @Test fun belowFloor_radiusClampedToOne() = runTest {
        val engine = MockEngine { respond(okBody, HttpStatusCode.OK, jsonHeaders()) }
        val ds = SevaRemoteDataSourceImpl(makeTestClient(engine), FakeLogger())

        ds.nearby(lat = 1.0, lng = 2.0, radius = 0, type = "washroom")

        assertEquals("1", engine.requestHistory.single().url.parameters["radius"])
    }

    @Test fun malformedBody_mapsToHttpError() = runTest {
        val engine = MockEngine { respond("{ not json", HttpStatusCode.OK, jsonHeaders()) }
        val ds = SevaRemoteDataSourceImpl(makeTestClient(engine), FakeLogger())

        val err = assertIs<Result.Err<NetworkError>>(ds.nearby(1.0, 2.0, 500, "all"))
        assertIs<NetworkError.HttpError>(err.error)
    }

    @Test fun serverError_passesThroughAsErr() = runTest {
        val engine = MockEngine { respond("boom", HttpStatusCode.InternalServerError, jsonHeaders()) }
        val ds = SevaRemoteDataSourceImpl(makeTestClient(engine), FakeLogger())

        val err = assertIs<Result.Err<NetworkError>>(ds.nearby(1.0, 2.0, 500, "all"))
        val http = assertIs<NetworkError.HttpError>(err.error)
        assertEquals(500, http.statusCode)
    }
}
