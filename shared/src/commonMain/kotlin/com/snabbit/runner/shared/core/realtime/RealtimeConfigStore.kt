package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.storage.EncryptedStore
import kotlin.random.Random
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The `mqtt_config` object as delivered inside `GET /runners/me`
 * (LLD Appendix C — field names follow the backend's build_mqtt_config()).
 * `mqtt_kmp_enabled` defaults true when absent; explicit false is the
 * backend kill-switch (LLD §3.2).
 */
@Serializable
data class MqttConfig(
    @SerialName("broker_host") val host: String = "",
    @SerialName("broker_port") val port: Int = 1883,
    @SerialName("broker_url") val url: String? = null,
    @SerialName("use_tls") val useTls: Boolean = false,
    val keepalive: Int = 60,
    val username: String = "",
    @SerialName("client_id_prefix") val clientIdPrefix: String = "",
    @SerialName("state_topic") val stateTopic: String = "",
    val subscriptions: List<String> = emptyList(),
    @SerialName("mqtt_kmp_enabled") val kmpEnabled: Boolean = true,
)

/**
 * Owns the runner's realtime config (LLD §3.2 three layers):
 *  - source of truth: Dart pushes the `mqtt_config` JSON right after every
 *    `runners/me` (login + refreshes) via RealtimePlugin — the
 *    NetworkConfigStore pattern;
 *  - resilience cache: persisted last-known-good in [EncryptedStore] so the
 *    killed-app FCM wake path can connect BEFORE any Flutter code runs
 *    (LLD §6.2 cold-boot connects from cache);
 *  - kill-switch: absent/null config or `mqtt_kmp_enabled=false` ⇒ [snapshot]
 *    is null / disabled and the engine never starts.
 *
 * Also owns the stable per-install client-id suffix (LLD §6.1): a UUID-ish
 * token minted once, persisted encrypted, never derived from device ids;
 * cleared with app data — the desired semantics.
 */
class RealtimeConfigStore(
    private val store: EncryptedStore,
    private val logger: Logger,
) {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val _config = MutableStateFlow<MqttConfig?>(null)
    val config: StateFlow<MqttConfig?> = _config.asStateFlow()

    /**
     * App-side Firebase Remote Config kill-switch (`expert_mqtt_enabled`, feature
     * #1) — distinct from the backend per-runner [MqttConfig.kmpEnabled]. False ⇒
     * run the engine in poll-only mode (no MQTT, current_state loop). Default true
     * (fail-open). Pushed from Dart; persisted so the FCM cold-boot path reads it.
     */
    private val _appMqttEnabled = MutableStateFlow(true)
    val appMqttEnabled: StateFlow<Boolean> = _appMqttEnabled.asStateFlow()

    /** current_state poll cadence (`expert_current_state_poll_interval`), seconds. */
    private val _pollIntervalSeconds = MutableStateFlow(DEFAULT_POLL_SECONDS)
    val pollIntervalSeconds: StateFlow<Int> = _pollIntervalSeconds.asStateFlow()

    /** MQTT connect-timeout (`expert_mqtt_connect_timeout_seconds`), seconds (feature #2). */
    private val _connectTimeoutSeconds = MutableStateFlow(DEFAULT_CONNECT_TIMEOUT_SECONDS)
    val connectTimeoutSeconds: StateFlow<Int> = _connectTimeoutSeconds.asStateFlow()

    /** Post-action MQTT-miss deadline (`expert_mqtt_post_action_timeout_seconds`), seconds (feature #4). */
    private val _postActionTimeoutSeconds = MutableStateFlow(DEFAULT_POST_ACTION_SECONDS)
    val postActionTimeoutSeconds: StateFlow<Int> = _postActionTimeoutSeconds.asStateFlow()

    /**
     * Connection-health analytics kill-switch (`expert_mqtt_health_analytics_enabled`). Default
     * true (fail-open — collect by default); flip to false via RC to silence the mqtt_recovered/
     * degraded/offline/stopped stream without a build if it gets too chatty.
     */
    private val _healthAnalyticsEnabled = MutableStateFlow(true)
    val healthAnalyticsEnabled: StateFlow<Boolean> = _healthAnalyticsEnabled.asStateFlow()

    fun snapshot(): MqttConfig? = _config.value

    // ECPO-933 cohort membership: enrolled AND mqtt_kmp_enabled — deliberately NOT the host/topic usability
    // toRealtimeConfig() also requires (membership ≠ MQTT-ready). Cold/FCM-wake hydrates first (idempotent).
    suspend fun isKmpHosting(): Boolean {
        if (_config.value == null) hydrate()
        return _config.value?.kmpEnabled == true
    }

    /** Restore the last-known-good config + app-side flags from storage (cold boot). */
    suspend fun hydrate() {
        if (_config.value == null) {
            store.getString(KEY_CONFIG)?.let { raw -> _config.value = decode(raw) }
        }
        store.getString(KEY_APP_ENABLED)?.let { _appMqttEnabled.value = it.toBooleanStrictOrNull() ?: true }
        store.getString(KEY_POLL_SECONDS)?.let { _pollIntervalSeconds.value = it.toIntOrNull() ?: DEFAULT_POLL_SECONDS }
        store.getString(KEY_CONNECT_SECONDS)?.let { _connectTimeoutSeconds.value = it.toIntOrNull() ?: DEFAULT_CONNECT_TIMEOUT_SECONDS }
        store.getString(KEY_POSTACTION_SECONDS)?.let { _postActionTimeoutSeconds.value = it.toIntOrNull() ?: DEFAULT_POST_ACTION_SECONDS }
        store.getString(KEY_HEALTH_ANALYTICS)?.let { _healthAnalyticsEnabled.value = it.toBooleanStrictOrNull() ?: true }
    }

    /**
     * Dart push after `runners/me`. Null/blank raw = not enrolled ⇒ clear.
     * @return true iff a usable, enabled config is now held.
     */
    suspend fun push(rawJson: String?): Boolean {
        if (rawJson.isNullOrBlank() || rawJson == "null") {
            clear()
            return false
        }
        val parsed = decode(rawJson) ?: return (_config.value?.kmpEnabled == true)
        _config.value = parsed
        store.putString(KEY_CONFIG, rawJson)
        return parsed.kmpEnabled
    }

    /**
     * Dart push of the app-side Firebase RC values (feature #1): the global MQTT
     * kill-switch + the current_state poll cadence. Persisted so the cold-boot
     * path reads the last-known values before any Flutter code runs.
     */
    suspend fun pushAppConfig(
        mqttEnabled: Boolean,
        pollIntervalSeconds: Int,
        connectTimeoutSeconds: Int,
        postActionTimeoutSeconds: Int,
        healthAnalyticsEnabled: Boolean = true,
    ) {
        val poll = pollIntervalSeconds.coerceAtLeast(MIN_POLL_SECONDS)
        val connect = connectTimeoutSeconds.coerceAtLeast(MIN_CONNECT_TIMEOUT_SECONDS)
        val postAction = postActionTimeoutSeconds.coerceAtLeast(MIN_POST_ACTION_SECONDS)
        // Short-circuit: onUpdatedKeys fires on every RC change, so skip the
        // encrypted-storage writes when nothing moved (in-memory == persisted).
        if (_appMqttEnabled.value == mqttEnabled &&
            _pollIntervalSeconds.value == poll &&
            _connectTimeoutSeconds.value == connect &&
            _postActionTimeoutSeconds.value == postAction &&
            _healthAnalyticsEnabled.value == healthAnalyticsEnabled
        ) {
            return
        }
        _appMqttEnabled.value = mqttEnabled
        _pollIntervalSeconds.value = poll
        _connectTimeoutSeconds.value = connect
        _postActionTimeoutSeconds.value = postAction
        _healthAnalyticsEnabled.value = healthAnalyticsEnabled
        store.putString(KEY_APP_ENABLED, mqttEnabled.toString())
        store.putString(KEY_POLL_SECONDS, poll.toString())
        store.putString(KEY_CONNECT_SECONDS, connect.toString())
        store.putString(KEY_POSTACTION_SECONDS, postAction.toString())
        store.putString(KEY_HEALTH_ANALYTICS, healthAnalyticsEnabled.toString())
    }

    suspend fun clear() {
        _config.value = null
        store.delete(KEY_CONFIG)
    }

    /** Stable per-install suffix — minted once, persisted (LLD §6.1). */
    suspend fun installSuffix(): String {
        store.getString(KEY_SUFFIX)?.let { return it }
        val minted = buildString {
            repeat(12) { append("abcdefghijklmnopqrstuvwxyz0123456789"[Random.nextInt(36)]) }
        }
        store.putString(KEY_SUFFIX, minted)
        return minted
    }

    /**
     * Maps to the transport config, applying the gate: returns null when not
     * enrolled, kill-switched, or structurally unusable.
     */
    fun toRealtimeConfig(jwt: String, installSuffix: String): RealtimeConfig? {
        val c = _config.value ?: return null
        if (!c.kmpEnabled) return null
        if (c.host.isBlank() || c.stateTopic.isBlank()) {
            logger.w(TAG, "mqtt_config present but unusable (blank host/topic)")
            return null
        }
        return RealtimeConfig(
            host = c.host,
            port = c.port,
            useTls = c.useTls,
            username = c.username,
            password = jwt,
            clientId = c.clientIdPrefix + installSuffix,
            stateTopic = c.stateTopic,
            keepAliveSeconds = c.keepalive,
        )
    }

    private fun decode(raw: String): MqttConfig? = try {
        json.decodeFromString<MqttConfig>(raw)
    } catch (e: Exception) {
        logger.e(TAG, "mqtt_config decode failed — keeping previous", e)
        null
    }

    private companion object {
        const val TAG = "RealtimeConfigStore"
        const val KEY_CONFIG = "realtime.mqtt_config"
        const val KEY_SUFFIX = "realtime.install_suffix"
        const val KEY_APP_ENABLED = "realtime.app_mqtt_enabled"
        const val KEY_POLL_SECONDS = "realtime.poll_interval_seconds"
        const val KEY_CONNECT_SECONDS = "realtime.connect_timeout_seconds"
        const val KEY_POSTACTION_SECONDS = "realtime.post_action_timeout_seconds"
        const val KEY_HEALTH_ANALYTICS = "realtime.health_analytics_enabled"
        const val DEFAULT_POLL_SECONDS = 60
        const val MIN_POLL_SECONDS = 15
        const val DEFAULT_CONNECT_TIMEOUT_SECONDS = 25
        const val MIN_CONNECT_TIMEOUT_SECONDS = 5
        const val DEFAULT_POST_ACTION_SECONDS = 5
        const val MIN_POST_ACTION_SECONDS = 2
    }
}
