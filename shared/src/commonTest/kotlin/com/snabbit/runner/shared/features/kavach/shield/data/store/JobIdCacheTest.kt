package com.snabbit.runner.shared.features.kavach.shield.data.store

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class JobIdCacheTest {
    @Test
    fun caches_and_clears() {
        val cache = JobIdCache()
        assertNull(cache.get())
        cache.set(650)
        assertEquals(650, cache.get())
        cache.set(null)
        assertNull(cache.get())
    }
}
