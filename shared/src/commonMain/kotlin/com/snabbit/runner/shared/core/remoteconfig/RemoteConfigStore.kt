package com.snabbit.runner.shared.core.remoteconfig

import kotlinx.coroutines.flow.MutableStateFlow

/**
 * In-memory snapshot of the Firebase Remote Config flags Flutter pushes across
 * the `RemoteConfigHostApi` bridge — **bool** flags and **string** flags (e.g.
 * JSON configs like `expert_vishwaas_banner`). Flutter owns Firebase; KMP mirrors.
 *
 * Backed by [MutableStateFlow]s so the writes (from the platform-channel thread)
 * and the reads (from Compose/main) are safely published without a lock. Flutter
 * pushes the **full** set each sync, so [setFlags]/[setStringFlags] replace their
 * snapshot wholesale — a key that has never been pushed falls back to the caller's
 * `default` ([RemoteConfigGateway] contract), which is the safe value when RC is
 * unavailable or the bridge hasn't fired yet.
 */
class RemoteConfigStore : RemoteConfigGateway {
    private val flags = MutableStateFlow<Map<String, Boolean>>(emptyMap())
    private val stringFlags = MutableStateFlow<Map<String, String>>(emptyMap())

    /** Replace the whole bool-flag snapshot with the latest values from Flutter. */
    fun setFlags(values: Map<String, Boolean>) {
        flags.value = values
    }

    /** Replace the whole string-flag snapshot with the latest values from Flutter. */
    fun setStringFlags(values: Map<String, String>) {
        stringFlags.value = values
    }

    override fun getBool(key: String, default: Boolean): Boolean =
        flags.value[key] ?: default

    override fun getString(key: String, default: String): String =
        stringFlags.value[key] ?: default
}
