package com.snabbit.runner.shared.features.job.data

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull

/**
 * Tolerant readers for the heterogeneous `widget_data`. The `current_state`
 * backend sends numbers as numbers OR quoted strings, and fields come and go, so
 * these mirror the Flutter `anyValueToInt`/`anyValueToDouble` resilience: a
 * string `"120"` parses to `120`, and a missing/odd field degrades to
 * null/false instead of throwing.
 */
internal fun JsonElement?.asIntOrNull(): Int? {
    val c = (this as? JsonPrimitive)?.contentOrNull?.trim() ?: return null
    return c.toIntOrNull() ?: c.toDoubleOrNull()?.toInt()
}

internal fun JsonElement?.asDoubleOrNull(): Double? =
    (this as? JsonPrimitive)?.contentOrNull?.trim()?.toDoubleOrNull()

internal fun JsonElement?.asStringOrNull(): String? =
    (this as? JsonPrimitive)?.contentOrNull

internal fun JsonElement?.asBoolean(): Boolean {
    val p = this as? JsonPrimitive ?: return false
    return p.booleanOrNull ?: (p.contentOrNull?.equals("true", ignoreCase = true) == true)
}

/** The nested object at [key], or null when absent / not an object. */
internal fun JsonObject?.obj(key: String): JsonObject? = this?.get(key) as? JsonObject
