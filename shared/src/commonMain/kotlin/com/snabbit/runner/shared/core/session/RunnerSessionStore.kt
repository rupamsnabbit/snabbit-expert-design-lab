package com.snabbit.runner.shared.core.session

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Session values mirrored from Dart that KMP features must read **live at
 * use time** — never freeze them into a constructor or an Intent extra,
 * because Dart pushes them whenever its own source settles (profile fetch,
 * Remote Config activate), which can be after a Compose host has already
 * launched.
 *
 * Write-from-Dart (via the job launcher's config channel — see
 * `JobScreenLauncherPlugin.handleConfig`), read-from-KMP. The KMP sibling
 * of `NetworkConfigStore`/`RunnerStateStore` for per-session scalars.
 */
class RunnerSessionStore {

    private val _runnerId = MutableStateFlow<Int?>(null)

    /**
     * The logged-in runner's id (Dart `UserProfileProvider.user.id`), or
     * null before the profile settles. Consumers needing it for a request
     * read `.value` at request time (Dart parity: the profile is read live
     * at tap time) and degrade gracefully on null.
     */
    val runnerId: StateFlow<Int?> = _runnerId.asStateFlow()

    private val _ameyoSupport = MutableStateFlow(false)

    /**
     * The `expert_ameyo_support` Remote Config flag (delayed check-in
     * FR-13): true = the backend calls the runner back after a disposition
     * submit; false (the RC default and the degrade-safe fallback) = the
     * app dials the helpline. Read live at submit time so a mid-session RC
     * flip reaches already-open surfaces, matching Dart's request-time read.
     */
    val ameyoSupport: StateFlow<Boolean> = _ameyoSupport.asStateFlow()

    fun setRunnerId(id: Int?) {
        _runnerId.value = id
    }

    fun setAmeyoSupport(enabled: Boolean) {
        _ameyoSupport.value = enabled
    }
}
