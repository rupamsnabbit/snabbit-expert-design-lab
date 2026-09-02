package com.snabbit.runner.shared.core

/**
 * SAM type for non-fatal crash reporting. Modules accept a [CrashReporter]
 * via constructor or Koin injection — they do not call platform crash
 * reporting APIs (Crashlytics, Sentry, etc.) directly so tests can
 * substitute a fake.
 *
 * Declared as a `fun interface` rather than a raw `(Throwable, Map<…>) -> Unit`
 * because the lambda type erases to `Function2` on the JVM. A Koin
 * `single<(Throwable, Map<String, String>) -> Unit>` binding would
 * collide with any other `Function2` binding registered in the same
 * Koin scope; the distinct interface type makes the resolution
 * unambiguous.
 *
 * Host wiring: [com.snabbit.runner.shared.core.di.platformModule]
 * accepts an optional `(Throwable, Map<…>) -> Unit` lambda from the
 * Application and binds a [CrashReporter] that delegates to it. When the
 * host passes `null` (or omits the param), the binding logs a warning
 * via the resolved [Logger] so failures aren't silently swallowed.
 */
fun interface CrashReporter {
    fun report(throwable: Throwable, meta: Map<String, String>)
}
