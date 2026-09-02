package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.CrashReporter

/**
 * Records `(throwable, meta)` pairs reported via the core [CrashReporter] for
 * assertions (the camera module folds its error reporting into this seam — the
 * machine-readable code travels in `meta["code"]`).
 */
internal class FakeCrashReporter : CrashReporter {
    val reported = mutableListOf<Pair<Throwable, Map<String, String>>>()

    override fun report(throwable: Throwable, meta: Map<String, String>) {
        reported.add(throwable to meta)
    }
}
