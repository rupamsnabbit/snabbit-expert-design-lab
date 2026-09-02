package com.snabbit.runner.shared.core

import android.util.Log

actual fun defaultLogger(): Logger = AndroidLogger

/**
 * Logcat-backed [Logger].
 *
 * `d()` is release-gated through [DebugLogGate] — a no-op on a shipped build, so the
 * identifiers that ride debug diagnostics never reach logcat. `w()` / `e()` always
 * write: they are what production crash triage reads, and callers redact their own
 * payloads (the network client logs a redacted URL, not the raw one).
 */
private object AndroidLogger : Logger {
    override fun d(tag: String, message: String) {
        if (DebugLogGate.isEnabled) Log.d(tag, message)
    }

    override fun w(tag: String, message: String, throwable: Throwable?) {
        Log.w(tag, message, throwable)
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        Log.e(tag, message, throwable)
    }
}
