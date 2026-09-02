package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.Logger

/**
 * Sanitises analytics property bags before they reach providers. Runs once
 * at the tracker boundary; idempotent (re-running on already-sanitised
 * input is a no-op).
 *
 * Rules (LLD §2.4):
 *  1. Strip nulls.
 *  2. Widen integral types to [Long] — Dart `int` always lands as `Long`
 *     across the MethodChannel; in-process Kotlin callers would otherwise
 *     send `Int`. Single integer type at provider boundary kills the drift.
 *  3. Widen [Float] → [Double] for the same reason.
 *  4. Truncate strings >1024 chars (AppsFlyer silently drops at ~1k).
 *  5. Anything else → `toString()` with a warning.
 *
 * No recursion into nested maps/lists in v1 — vendors handle nesting
 * differently and we have no real call sites with nested props today.
 */
object PropertyValue {

    private const val MAX_STRING_LENGTH = 1024
    private const val TAG = "PropertyValue"

    /**
     * Returns a sanitised map whose values are guaranteed non-null —
     * the return type encodes the post-sanitisation contract that
     * downstream providers (notably [com.snabbit.runner.shared.core.analytics.providers.AppsFlyerAndroidProvider])
     * rely on. Removing this guarantee would surface as a runtime
     * `ClassCastException` inside AppsFlyer's `logEvent` overload that
     * expects `Map<String, Any>`.
     */
    fun sanitize(props: Map<String, Any?>, logger: Logger): Map<String, Any> {
        if (props.isEmpty()) return emptyMap()
        val out = LinkedHashMap<String, Any>(props.size)
        for ((key, value) in props) {
            if (value == null) continue
            out[key] = coerce(key, value, logger)
        }
        return out
    }

    private fun coerce(key: String, value: Any, logger: Logger): Any = when (value) {
        is String -> if (value.length > MAX_STRING_LENGTH) {
            logger.w(TAG, "property '$key' truncated from ${value.length} to $MAX_STRING_LENGTH chars")
            value.substring(0, MAX_STRING_LENGTH)
        } else {
            value
        }
        is Long -> value
        is Int -> value.toLong()
        is Short -> value.toLong()
        is Byte -> value.toLong()
        is Double -> value
        is Float -> value.toDouble()
        is Boolean -> value
        is Char -> value.toString()
        else -> {
            logger.w(TAG, "property '$key' of type ${value::class.simpleName} coerced via toString()")
            value.toString()
        }
    }
}
