package com.snabbit.runner.shared.features.kavach.shield.domain

import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ShieldMlLoadGuardTest {

    private val prefs = InMemoryPreferenceStorage()
    private var version = "1"
    private val guard = ShieldMlLoadGuard(prefs) { version }

    @Test
    fun freshInstall_allowsMl() = runTest {
        assertTrue(guard.mlAllowed())   // no marker → allowed
    }

    @Test
    fun crashedAttempt_sameBuild_blocksMl() = runTest {
        guard.beginAttempt()            // marker written, never cleared → simulates a native load-crash
        assertFalse(guard.mlAllowed())  // same build → ML stays off
    }

    @Test
    fun crashedAttempt_newBuild_reAllowsMl() = runTest {
        guard.beginAttempt()            // pending = "1"
        version = "2"                   // new app/model build
        assertTrue(guard.mlAllowed())   // stale marker for a different build → allowed again
    }

    @Test
    fun successfulAttempt_clearsMarker() = runTest {
        guard.beginAttempt()
        guard.markSucceeded()           // init returned → marker cleared
        assertTrue(guard.mlAllowed())
    }
}
