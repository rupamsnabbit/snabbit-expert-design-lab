package com.snabbit.runner.shared.core

import kotlinx.coroutines.CoroutineDispatcher

/**
 * Coroutine dispatcher abstraction. Modules accept [AppDispatchers] via
 * constructor instead of referring to `kotlinx.coroutines.Dispatchers`
 * directly, so tests can substitute a TestDispatcher.
 */
interface AppDispatchers {
    /** For I/O-bound work (network, disk). */
    val io: CoroutineDispatcher

    /** For CPU-bound work (parsing, computation). */
    val default: CoroutineDispatcher

    /** For work that must run on the UI thread. */
    val main: CoroutineDispatcher
}

/** Returns the platform's default [AppDispatchers]. */
expect fun defaultAppDispatchers(): AppDispatchers
