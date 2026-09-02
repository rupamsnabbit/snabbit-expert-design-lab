package com.snabbit.runner.shared.features.kavach.shared.domain

import kotlin.concurrent.Volatile

/** How the current monitoring session was armed — mirrors Flutter's `ShieldTrigger`. Drives the
 *  `trigger` prop on the shield lifecycle events (started/resumed/paused/stopped). */
enum class ActiveTrigger(val value: String) {
    AUTO("auto"),
    MANUAL("manual"),
    SOS("sos"),
}

/**
 * Shared single-source-of-truth for the active session's trigger — the KMP port of Flutter's
 * `ShieldStartStopController.activeTrigger`. Written on a successful arm (manual/auto) or a cold SOS
 * start, read by the lifecycle-analytics emitters (ShieldEventRouter, endForJob), and cleared at
 * job-end so a stale trigger can't leak into the next job.
 *
 * A Koin single so the three consumers (SafetyDataSourceImpl writes+reads, SosCoordinator writes,
 * ShieldEventRouter reads) share one value. `@Volatile`: written on arm/raise (main/default),
 * read on the router's default-dispatcher collector — same cross-thread idiom as SosCoordinator.
 */
class ActiveTriggerHolder {
    @Volatile
    var current: ActiveTrigger? = null

    /** The analytics `trigger` value — "unknown" until an arm/SOS start commits one (Flutter parity). */
    fun value(): String = current?.value ?: "unknown"
}
