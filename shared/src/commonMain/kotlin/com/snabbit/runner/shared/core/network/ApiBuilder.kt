package com.snabbit.runner.shared.core.network

/**
 * Entry point for building relative API paths. Pick the version, chain
 * `.add(...)` for path segments, optionally `.query(key, value)` for query
 * parameters, then `.build()` (or rely on `toString()`).
 *
 *   Api.v1().add("runners").add("language_list").build()
 *     → "api/v1/runners/language_list"
 *
 *   Api.v1().add("runners").add("me").query("expand", "true").build()
 *     → "api/v1/runners/me?expand=true"
 *
 * Path segments and query values are written verbatim — no URL encoding.
 * Current paths use safe identifiers; revisit if/when externally-controlled
 * values land in path positions.
 */
object Api {
    fun v1(): ApiPath = ApiPath("api/v1")
    fun v2(): ApiPath = ApiPath("api/v2")

    /** Escape hatch for future versions (`v3`, `internal`, …). */
    fun version(v: String): ApiPath = ApiPath("api/$v")
}

class ApiPath internal constructor(private val base: String) {

    private val segments = mutableListOf<String>()
    private val params = mutableListOf<Pair<String, String>>()

    fun add(segment: String): ApiPath = apply { segments += segment }

    fun query(key: String, value: String): ApiPath = apply {
        params += key to value
    }

    fun build(): String = buildString {
        append(base)
        if (segments.isNotEmpty()) {
            append('/')
            append(segments.joinToString("/"))
        }
        if (params.isNotEmpty()) {
            append('?')
            append(params.joinToString("&") { (k, v) -> "$k=$v" })
        }
    }

    override fun toString(): String = build()
}
