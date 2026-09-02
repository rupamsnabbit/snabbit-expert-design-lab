package com.snabbit.runner.shared.core.di

import org.koin.core.context.stopKoin
import org.koin.dsl.koinApplication
import org.koin.dsl.module
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * KmpBootstrap listed `safetyModule` twice. Had Koin loaded it twice, the eager `createdAtStart`
 * ShieldUploadCoordinator would have attached TWO EncryptedAudio collectors and enqueued every clip twice.
 *
 * This pins only the Koin semantics that made it harmless — it does NOT guard the module list itself, so a
 * duplicate re-added to KmpBootstrap would still pass. It documents why that wouldn't be a live bug.
 */
class KoinDuplicateModuleTest {

    @AfterTest
    fun tearDown() = stopKoin()

    @Test
    fun sameModuleListedTwice_constructsEagerSingleOnce() {
        var constructions = 0
        val m = module { single(createdAtStart = true) { constructions++ } }

        koinApplication { modules(listOf(m, m)) }.koin.createEagerInstances()

        assertEquals(1, constructions)
    }
}
