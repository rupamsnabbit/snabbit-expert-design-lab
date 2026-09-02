package com.snabbit.runner.shared.core.network

import io.ktor.client.engine.mock.MockRequestHandler
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode

/**
 * Ordered response queue for tests that drive a sequence of responses
 * (retries, pagination, sequential calls). See §15.4.
 *
 * Usage:
 *
 *     val queue = MockResponseQueue().apply {
 *         enqueue(HttpStatusCode.ServiceUnavailable, "{\"error\":\"retry\"}")
 *         enqueue(HttpStatusCode.ServiceUnavailable, "{\"error\":\"retry\"}")
 *         enqueue(HttpStatusCode.OK, "{\"ok\":true}")
 *     }
 *     val engine = MockEngine(queue.handler())
 */
internal class MockResponseQueue {

    private val queue = ArrayDeque<MockRequestHandler>()

    fun enqueue(status: HttpStatusCode, body: String) {
        queue.addLast { respond(body, status, jsonHeaders()) }
    }

    /** Throws if the engine is asked for a response after the queue empties. */
    fun handler(): MockRequestHandler = { request ->
        val next = queue.removeFirstOrNull()
            ?: error("MockResponseQueue exhausted — no enqueued response for ${request.url}")
        next(request)
    }
}
