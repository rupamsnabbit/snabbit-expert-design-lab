package com.snabbit.runner.shared.core

import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Pins the [DebugLogGate] contract that the Android [Logger] reads.
 *
 * The gate is process-wide (consumers take `logger: Logger = defaultLogger()` as a
 * constructor default, so a Koin-level binding would miss most of them), which means
 * every test here restores it — the JVM test run shares one instance.
 */
class DebugLogGateTest {

    @AfterTest
    fun restore() {
        DebugLogGate.arm(false)
    }

    @Test
    fun gate_is_closed_unless_the_host_arms_it_open() {
        // Fail-closed: a process whose bootstrap never ran (or failed open) must stay
        // quiet rather than leak. Same state the object is constructed in.
        DebugLogGate.arm(false)
        assertFalse(DebugLogGate.isEnabled)
    }

    @Test
    fun a_debuggable_host_opens_the_gate() {
        DebugLogGate.arm(true)
        assertTrue(DebugLogGate.isEnabled)
    }

    @Test
    fun arming_is_idempotent_and_last_write_wins() {
        DebugLogGate.arm(true)
        DebugLogGate.arm(true)
        assertTrue(DebugLogGate.isEnabled)
        DebugLogGate.arm(false)
        assertFalse(DebugLogGate.isEnabled)
    }
}
