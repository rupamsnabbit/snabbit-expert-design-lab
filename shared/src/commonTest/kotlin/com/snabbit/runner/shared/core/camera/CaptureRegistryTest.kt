package com.snabbit.runner.shared.core.camera

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Tests [CaptureRegistry] — the concurrency-critical token/TTL store that had no
 * coverage before. Uses an injectable [clock] and a virtual-time [sweepScope] so
 * TTL/sweep behaviour is deterministic, and a fake [CaptureIndex] to assert the
 * synchronous mirror stays in lock-step.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CaptureRegistryTest {

    private class RecordingIndex : CaptureIndex {
        val map = mutableMapOf<String, String>()
        override fun put(token: String, filePath: String) { map[token] = filePath }
        override fun remove(token: String) { map.remove(token) }
    }

    @Test
    fun `register then resolve returns the path`() = runTest {
        val reg = CaptureRegistry(sweepScope = backgroundScope, clock = { 0L })
        val token = reg.register("/tmp/a.jpg")
        assertEquals("/tmp/a.jpg", reg.resolve(token))
        assertEquals(1, reg.size())
    }

    @Test
    fun `resolve is null for an unknown token`() = runTest {
        val reg = CaptureRegistry(sweepScope = backgroundScope, clock = { 0L })
        assertNull(reg.resolve("nope"))
    }

    @Test
    fun `resolve past TTL evicts and deletes the file`() = runTest {
        var now = 0L
        val deleted = mutableListOf<String>()
        val reg = CaptureRegistry(
            sweepScope = backgroundScope,
            defaultTtlMs = 1_000,
            onDeleteFile = { deleted.add(it) },
            clock = { now },
        )
        val token = reg.register("/tmp/a.jpg")

        now = 1_001 // past the TTL
        assertNull(reg.resolve(token))
        assertEquals(listOf("/tmp/a.jpg"), deleted)
        assertEquals(0, reg.size())
    }

    @Test
    fun `evict removes the entry and deletes the file`() = runTest {
        val deleted = mutableListOf<String>()
        val reg = CaptureRegistry(
            sweepScope = backgroundScope,
            onDeleteFile = { deleted.add(it) },
            clock = { 0L },
        )
        val token = reg.register("/tmp/a.jpg")

        reg.evict(token)

        assertNull(reg.resolve(token))
        assertEquals(listOf("/tmp/a.jpg"), deleted)
    }

    @Test
    fun `periodic sweep evicts expired entries then self-stops`() = runTest {
        var now = 0L
        val deleted = mutableListOf<String>()
        val reg = CaptureRegistry(
            sweepScope = backgroundScope,
            defaultTtlMs = 1_000,
            sweepIntervalMs = 5_000,
            onDeleteFile = { deleted.add(it) },
            clock = { now },
        )
        reg.register("/tmp/a.jpg")
        assertEquals(1, reg.size())

        now = 2_000 // both entries now expired
        advanceTimeBy(5_001) // let one sweep tick fire
        runCurrent()

        assertEquals(0, reg.size())
        assertEquals(listOf("/tmp/a.jpg"), deleted)
    }

    @Test
    fun `index mirror stays in lock-step with the registry`() = runTest {
        val index = RecordingIndex()
        val reg = CaptureRegistry(sweepScope = backgroundScope, index = index, clock = { 0L })

        val token = reg.register("/tmp/a.jpg")
        assertEquals("/tmp/a.jpg", index.map[token])

        reg.evict(token)
        assertNull(index.map[token])
    }

    @Test
    fun `generated tokens are unique under a burst`() = runTest {
        val reg = CaptureRegistry(sweepScope = backgroundScope, clock = { 0L })
        val tokens = (1..1_000).map { reg.register("/tmp/$it.jpg") }.toSet()
        assertEquals(1_000, tokens.size)
    }
}
