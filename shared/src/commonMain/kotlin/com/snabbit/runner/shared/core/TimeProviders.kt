package com.snabbit.runner.shared.core

/**
 * Typed time-supplier interfaces (§8.3 / §3.6). Replace raw `() -> Long`
 * and `() -> String` Koin bindings, which collapsed to the same runtime
 * type (`kotlin.jvm.functions.Function0`) and forced reliance on named
 * qualifiers for disambiguation.
 *
 * `fun interface` + `operator fun invoke()` lets call sites stay
 * ergonomic — `currentTimeMs()` and `nowIso()` still read like function
 * invocations and SAM-converted lambdas still bind cleanly:
 *
 *   single<CurrentTimeMs> { CurrentTimeMs { System.currentTimeMillis() } }
 *
 * Distinct types mean Koin resolves these without qualifiers, and any
 * future caller doing `get<CurrentTimeMs>()` cannot accidentally receive
 * a [NowIso] (or vice versa).
 */
fun interface CurrentTimeMs {
    operator fun invoke(): Long
}

fun interface NowIso {
    operator fun invoke(): String
}
