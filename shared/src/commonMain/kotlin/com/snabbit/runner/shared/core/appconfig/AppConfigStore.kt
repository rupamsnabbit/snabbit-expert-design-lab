package com.snabbit.runner.shared.core.appconfig

import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * The backend app-config document (`ConfigHttp.getAppConfig`), mirrored from
 * the Flutter `GlobalState.setAppConfig()` fetch. Dart owns the fetch (once,
 * at startup — no retry, aligning with #421); this is the read model KMP
 * features consume until the app-config migration gives :shared its own
 * fetch.
 *
 * Kept as a raw [JsonObject] deliberately — the store stays agnostic to the
 * document's long tail of keys (`job_support`, `expert_not_moving_repeat_count`,
 * …). Each feature decodes only the slice it owns (e.g. the delayed check-in
 * `readJobSupportOptions` for FR-11), so a new config key never requires a
 * bridge change. The KMP analogue of `RunnerStateStore`, minus the reverse
 * direction: config is fetch-once, so there is nothing to request.
 *
 * Write-from-Dart, read-from-KMP. [pushConfig] never throws: a malformed
 * payload is logged and the last good document is preserved.
 */
class AppConfigStore(private val logger: Logger) {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val _config = MutableStateFlow<JsonObject?>(null)

    /** Latest pushed document, or null before the first push. Replays to new collectors. */
    val config: StateFlow<JsonObject?> = _config.asStateFlow()

    /** Non-suspending peek — null if nothing has been pushed yet. */
    fun snapshot(): JsonObject? = _config.value

    /**
     * Decode [rawJson] (the whole app-config response body) and publish it.
     * A decode failure — or a payload that isn't a JSON object — is logged
     * at ERROR and leaves the previous document untouched.
     */
    fun pushConfig(rawJson: String) {
        try {
            _config.value = json.parseToJsonElement(rawJson).jsonObject
        } catch (e: Exception) {
            logger.e(TAG, "pushConfig decode failed; keeping last good config", e)
        }
    }

    private companion object {
        const val TAG = "AppConfigStore"
    }
}
