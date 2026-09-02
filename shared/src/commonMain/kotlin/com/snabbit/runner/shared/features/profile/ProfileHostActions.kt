package com.snabbit.runner.shared.features.profile

/**
 * Host (`:app`) → Profile bridge for the bits the Profile ViewModel needs but that live
 * outside `:shared`: the two Flutter-channel actions (stop notifications/audio, mark PAN
 * unavailable) and the debug-build flag. The Android host binds real implementations once
 * at startup (`SnabbitRunnerApplication`), mirroring [RunnerStateStore.bind]. Unbound
 * defaults are no-op / `false` — the Profile tab only renders well after startup, so bind
 * has always run by then.
 */
class ProfileHostActions {
    private var silentNotif: (() -> Unit)? = null
    private var panUnavailable: (() -> Unit)? = null

    /** Debug build → the Profile shows the Debug Menu tile (Flutter's `kDebugMode`). */
    var isDebug: Boolean = false
        private set

    fun bind(
        silentNotifications: () -> Unit,
        panCardUnavailable: () -> Unit,
        isDebug: Boolean,
    ) {
        this.silentNotif = silentNotifications
        this.panUnavailable = panCardUnavailable
        this.isDebug = isDebug
    }

    fun silentNotifications() {
        silentNotif?.invoke()
    }

    fun panCardUnavailable() {
        panUnavailable?.invoke()
    }
}
