package com.snabbit.runner.shared.features.kavach.shield.data.store

import kotlin.concurrent.Volatile

/**
 * The job the shield armed for — the fallback owner for clips the plugin didn't stamp. Set by the arm
 * sites only, never off a current_state read: `job_id` there survives POST_ACCEPT/CHECK_IN/POST_CHECKOUT
 * and lags the in-progress envelope (ECPO-986). Not cleared on teardown — a job's last clip lands after
 * it ends. `kotlin.concurrent.Volatile` is the multiplatform one; `kotlin.jvm.Volatile` breaks iOS.
 */
class JobIdCache {
    @Volatile
    private var jobId: Int? = null

    fun get(): Int? = jobId
    fun set(value: Int?) { jobId = value }
}
