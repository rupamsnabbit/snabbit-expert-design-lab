package com.snabbit.runner.shared.core.config

import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlin.coroutines.resume

/** Android: read Firebase Remote Config natively via the official SDK. */
actual fun remoteConfigGateway(): RemoteConfigGateway = FirebaseRemoteConfigGateway()

/**
 * [RemoteConfigGateway] backed by the official Firebase Remote Config SDK (B-native).
 *
 * Reads the LIVE Firebase RC values directly — no Flutter/Pigeon mirror. The Flutter host
 * (FlutterFire + google-services) initializes Firebase on the shared, process-wide
 * [FirebaseRemoteConfig] singleton; [fetchAndActivate] refreshes it natively (also driven by the
 * host every launch — the two share the same singleton, so a redundant call is a cheap no-op).
 *
 * Default-safe: a key whose source is [FirebaseRemoteConfig.VALUE_SOURCE_STATIC] (never fetched, no
 * default set) resolves to the caller's `default` — so the shipped call-site defaults (e.g. accel
 * 2.7 G) are preserved rather than silently read as 0/false. Malformed remote values (asLong/asDouble
 * throw) also fall back to `default`.
 */
internal class FirebaseRemoteConfigGateway(
    private val json: Json = Json { ignoreUnknownKeys = true },
) : RemoteConfigGateway {

    // Lazy so constructing the gateway (e.g. Koin graph resolution) never touches Firebase;
    // getInstance() runs on first read, by when the host has initialized FirebaseApp.
    private val rc: FirebaseRemoteConfig by lazy { FirebaseRemoteConfig.getInstance() }

    override suspend fun getBoolean(key: String, default: Boolean): Boolean =
        read(key, default) { it.asBoolean() }

    override suspend fun getInt(key: String, default: Int): Int =
        read(key, default) { it.asLong().toInt() }

    override suspend fun getDouble(key: String, default: Double): Double =
        read(key, default) { it.asDouble() }

    override suspend fun getString(key: String, default: String): String =
        read(key, default) { it.asString() }

    // RC stores the list as a JSON array string (1:1 with Flutter's getList → json.decode). Blank
    // or malformed → default.
    override suspend fun getStringList(key: String, default: List<String>): List<String> =
        read(key, default) { json.decodeFromString<List<String>>(it.asString()) }

    // Bridge the Task<Boolean> to suspend via suspendCancellableCoroutine (no play-services-coroutines
    // dep). task.result is true when the activated config changed. Fail-safe: any failure → false so a
    // launch-time fetch never throws; the last activated values stay in effect.
    override suspend fun fetchAndActivate(): Boolean = suspendCancellableCoroutine { cont ->
        rc.fetchAndActivate().addOnCompleteListener { task ->
            if (cont.isActive) cont.resume(task.isSuccessful && task.result == true)
        }
    }

    // Confine to IO — the getters are documented main-safe, but rc.getValue() hits SharedPreferences on
    // the calling thread (StrictMode/jank when the cache is cold). runCatching wraps the lazy getInstance()
    // deref AND getValue() too, so a NoClassDefFoundError (compileOnly firebase-config, host absent) or any
    // SDK throw falls back to the caller's default instead of propagating out of a "default-safe" getter.
    private suspend fun <T> read(key: String, default: T, convert: (FirebaseRemoteConfigValue) -> T): T =
        withContext(Dispatchers.IO) {
            runCatching {
                val value = rc.getValue(key)
                if (value.source == FirebaseRemoteConfig.VALUE_SOURCE_STATIC) default else convert(value)
            }.getOrDefault(default)
        }
}
