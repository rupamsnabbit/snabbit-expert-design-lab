package com.snabbit.runner.shared.features.kavach.shield.domain

import kotlinx.coroutines.sync.Mutex

/**
 * Shared lock serializing the plugin's `initialize()` + `onJobStarted()` check-then-act across its two
 * otherwise-unsynchronized callers — `SafetyDataSourceImpl.arm()` and `ShieldLayerRestore.restore()` —
 * which each gate on `shieldState == IDLE` on independent coroutine scopes. Without a shared monitor a
 * foreground cold-start-mid-job can let both read IDLE and double-init (redundant multi-MB model load +
 * FGS promote/demote churn). A Koin single so both callers share one mutex.
 */
class ShieldInitLock {
    val mutex = Mutex()
}
