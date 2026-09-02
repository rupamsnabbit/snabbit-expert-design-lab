package com.snabbit.runner.shared.core

/**
 * Logger abstraction. Modules accept a [Logger] via constructor — they do not
 * call platform logging APIs directly, so tests can substitute a fake.
 *
 * Use [defaultLogger] for production wiring (platform-specific impl). Tests
 * use FakeLogger from commonTest.
 */
interface Logger {
    fun d(tag: String, message: String)
    fun w(tag: String, message: String, throwable: Throwable? = null)
    fun e(tag: String, message: String, throwable: Throwable? = null)
}

/** Returns the platform's default [Logger]. */
expect fun defaultLogger(): Logger

/**
 * Release gate for debug-level ([Logger.d]) output.
 *
 * `d()` carries the noisy diagnostics — request URLs, capture-serve tokens, saved
 * file paths, MQTT topics, snapshot sequence numbers — and none of that belongs in
 * logcat on a shipped build, where any process holding READ_LOGS (or anyone with
 * adb) can read it. `w()` and `e()` deliberately keep writing on release: production
 * crash triage reads those breadcrumbs, and their payloads are redacted at the call
 * site instead (see `redactUrlForLog` in core/network).
 *
 * Armed once at startup by the platform bootstrap — on Android `KmpBootstrap`
 * derives it from the host's manifest `debuggable` flag, the same signal as
 * `BuildConfig.DEBUG`, read off the `Application` it already holds. Gating here
 * rather than at the Koin binding is deliberate: most consumers take
 * `logger: Logger = defaultLogger()` as a constructor default and never see the
 * Koin-bound instance.
 *
 * Defaults to **off** so a process that never bootstrapped — or whose bootstrap
 * failed open — stays quiet rather than leaking. Mirrors the `ProfileHostActions`
 * idiom: one host-armed process-wide flag, written before anything reads it.
 */
object DebugLogGate {

    /** True only on a debuggable (developer) build. */
    var isEnabled: Boolean = false
        private set

    /** Armed by the platform bootstrap. Idempotent — the host calls it once per process. */
    fun arm(debuggableBuild: Boolean) {
        isEnabled = debuggableBuild
    }
}
