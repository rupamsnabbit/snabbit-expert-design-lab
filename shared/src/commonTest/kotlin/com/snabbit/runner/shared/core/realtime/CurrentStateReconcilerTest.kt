package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.network.NetworkConfig
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.network.resolveUrl
import com.snabbit.runner.shared.core.result.Result
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private class FakeHttp(
    var next: Result<SuccessResponse, NetworkError>,
    private val baseUrl: String = "https://test.snabbit.com",
) : SnabbitHttpClient {
    var lastRequest: SnabbitRequest? = null
    override suspend fun execute(request: SnabbitRequest): Result<SuccessResponse, NetworkError> {
        // Record the RESOLVED url, mirroring the real client — the production
        // path is now relative and `execute` joins it to the pushed base.
        lastRequest = request.copy(
            url = request.resolveUrl(NetworkConfig(baseUrl = baseUrl, versionCode = "1")),
        )
        return next
    }
    override fun close() = Unit
}

class CurrentStateReconcilerTest {

    @Test
    fun maps_current_state_into_envelope() = runTest {
        // current_state carries widget_name/widget_data FLAT at the top level plus
        // the sibling render fields — NOT nested under "widget" (that's the MQTT
        // STATE_SNAPSHOT shape). The reconciler must re-nest so the store gets a
        // real widget, not null.
        val http = FakeHttp(
            Result.Ok(
                success(
                    """{"state_seq":12,"epoch":3,"widget_name":"ON_THE_JOB",""" +
                        """"widget_data":{"job_id":5},"sheet_warnings":[],"gold_coins_total":7,""" +
                        """"show_lunch_selection":true}""",
                ),
            ),
        )
        val env = CurrentStateReconciler(http, FakeLogger()).fetch()
        assertEquals(12, env?.stateSeq)
        assertEquals(3, env?.epoch)
        assertEquals(
            "https://test.snabbit.com/api/v1/runners/me/app/current_state",
            http.lastRequest?.url,
        )
        // The flat widget was re-nested + toRunnerStateJson() reproduces the store
        // shape with a NON-null widget (the blank-card regression guard) + siblings.
        val storeJson = env!!.toRunnerStateJson()
        assertTrue(storeJson.contains("\"widget_name\":\"ON_THE_JOB\""), storeJson)
        assertTrue(storeJson.contains("\"gold_coins_total\":7"), storeJson)
        // Top-level show_lunch_selection must survive the DTO hop (lunch-banner contract).
        assertTrue(storeJson.contains("\"show_lunch_selection\":true"), storeJson)
    }

    @Test
    fun current_state_tier_nudge_flows_into_the_envelope() = runTest {
        // Regression: tier_nudge is a TOP-LEVEL sibling of widget_data on current_state. The
        // reconciler's DTO must decode it (this HTTP fetcher has its OWN DTO — the earlier
        // SnapshotEnvelope fix only covered the MQTT-message path), or the whole MQTT cohort
        // loses the tiering nudge whenever it runs on the HTTP reconcile / degraded poll.
        val http = FakeHttp(
            Result.Ok(
                success(
                    """{"state_seq":12,"widget_name":"ON_THE_JOB","widget_data":{"job_id":5},""" +
                        """"tier_nudge":{"nudge_name":"PERFECT_JOB","nudge_details":{"coin_amount":2}}}""",
                ),
            ),
        )
        val env = CurrentStateReconciler(http, FakeLogger()).fetch()
        // Captured onto the envelope...
        assertNotNull(env?.tierNudge)
        // ...and re-emitted in the store JSON the projector pushes to RunnerStateStore.
        val storeJson = env!!.toRunnerStateJson()
        assertTrue(storeJson.contains("\"tier_nudge\""), storeJson)
        assertTrue(storeJson.contains("PERFECT_JOB"), storeJson)
    }

    @Test
    fun missing_state_seq_defaults_to_zero_seed_and_keeps_widget() = runTest {
        val http = FakeHttp(Result.Ok(success("""{"widget_name":"X","widget_data":{}}""")))
        val env = CurrentStateReconciler(http, FakeLogger()).fetch()
        // A missing state_seq is a backend regression: apply as seq=0 (seed-only,
        // first-wins) rather than a client clock that would out-rank real backend
        // seqs. The widget must still flow through.
        assertEquals(0L, env?.stateSeq)
        assertTrue(env!!.toRunnerStateJson().contains("\"widget_name\":\"X\""))
    }

    @Test
    fun malformed_body_returns_null() = runTest {
        val http = FakeHttp(Result.Ok(success("<html>gateway error</html>")))
        assertNull(CurrentStateReconciler(http, FakeLogger()).fetch())
    }

    private fun success(body: String) = SuccessResponse(
        statusCode = 200,
        body = body,
        headers = emptyMap(),
        requestId = "rid",
        durationMs = 1L,
    )
}
