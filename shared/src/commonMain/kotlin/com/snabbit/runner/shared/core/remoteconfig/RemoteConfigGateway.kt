package com.snabbit.runner.shared.core.remoteconfig

/**
 * Read-only access to the Firebase Remote Config flags KMP mirrors from Flutter.
 *
 * Firebase Remote Config lives on the Flutter side; its values are mirrored
 * across the Pigeon `RemoteConfigHostApi` bridge into [RemoteConfigStore]. A
 * feature reads a flag here with an explicit [default] that MUST match the
 * Flutter-side default for that key — so behaviour degrades gracefully when RC
 * is unavailable or hasn't synced into the store yet (the safe-default rule).
 *
 * Still a `fun interface` (single abstract [getBool]) so tests/previews can supply
 * a lambda; [getString] has a default returning the caller's fallback, so a lambda
 * gateway simply exposes no string flags (safe).
 */
fun interface RemoteConfigGateway {
    fun getBool(key: String, default: Boolean): Boolean

    /** Reads a string flag (e.g. a JSON config); falls back to [default]. */
    fun getString(key: String, default: String): String = default
}
