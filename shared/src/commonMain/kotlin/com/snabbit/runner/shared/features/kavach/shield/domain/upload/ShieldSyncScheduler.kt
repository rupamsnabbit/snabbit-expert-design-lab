package com.snabbit.runner.shared.features.kavach.shield.domain.upload

/**
 * Requests an out-of-band outbox drain.
 *
 * The outbox had no time-based driver: a drain only ran on enqueue, at process launch, or on an
 * offline→online edge. So a row left behind at job end waited for the next job's first clip. Android
 * backs this with WorkManager, which survives process death and reboot; iOS has no binding (Kavach is
 * Android-only today), and callers resolve it optionally.
 */
interface ShieldSyncScheduler {
    /**
     * [expedite] jumps an already-pending drain that is sitting in backoff — for an explicit user moment
     * like checkout. Leave it false for pass-driven reschedules; expediting those would re-run
     * immediately after every pass that left rows behind.
     */
    fun schedule(expedite: Boolean = false)
}
