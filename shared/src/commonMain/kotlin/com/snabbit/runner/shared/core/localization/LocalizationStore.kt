package com.snabbit.runner.shared.core.localization

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * The runner's server-driven i18n map (key → translated string) plus the
 * current language, mirrored from the Flutter `LanguageProvider`. Dart owns the
 * fetch (`GET internationalization_file/{lang}`); this is the read model the KMP
 * / Compose Multiplatform surfaces look up copy against — the localization
 * analogue of `RunnerStateStore`.
 *
 * It mirrors only the READ surface of `LanguageProvider` ([getMessage] /
 * [getFormattedMessage], kept to the same names for cross-platform familiarity);
 * it deliberately does NOT fetch. Dart stays the single source of truth and
 * pushes the resolved map over the bridge on every language settle (cold-start
 * restore + every change), so ownership isn't split and the HTTP call isn't
 * duplicated.
 *
 * [pushMessages] never throws: a malformed payload is logged at ERROR, reported
 * to telemetry via [CrashReporter], and the last good snapshot is preserved
 * (stale-but-valid beats blank copy).
 *
 * Each successful push is also **persisted to disk** (unencrypted
 * [PreferenceStorage] — the i18n map is non-secret UI copy) as one JSON blob and
 * restored on a cold start via [seedFromCache], mirroring `NetworkConfigStore`.
 * So a KMP surface that comes up before Flutter is alive to push (e.g. an FCM
 * overlay on a force-killed app) shows the last-known localized copy. Only before
 * the very first push on a fresh install — while the async seed is still in
 * flight, or for a key absent from the map — does [getMessage] fall back to the
 * caller's English default (the defaults the KMP `XxxStrings` already ship).
 *
 * Persistence is **opt-in**: a store built without a [PreferenceStorage]
 * (unit tests, iOS until the storage module is wired) simply skips persist/seed
 * and behaves exactly as an in-memory read model.
 */
@Serializable
data class LocalizationSnapshot(
    val language: String = "",
    val messages: Map<String, String> = emptyMap(),
) {
    companion object {
        val EMPTY = LocalizationSnapshot()
    }
}

class LocalizationStore(
    private val logger: Logger,
    private val crashReporter: CrashReporter,
    private val preferenceStorage: PreferenceStorage? = null,
    dispatchers: AppDispatchers? = null,
) {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val _state = MutableStateFlow(LocalizationSnapshot.EMPTY)

    /** Latest pushed snapshot. Replays to new collectors; equal snapshots coalesce. */
    val state: StateFlow<LocalizationSnapshot> = _state.asStateFlow()

    // Fire-and-forget scope for persisting each pushed snapshot (only when a
    // store is wired). Process-lived; SupervisorJob so a failed write can't tear
    // it down. Persistence is opt-in — a store built without deps (unit tests,
    // iOS until wired) simply doesn't persist or seed.
    private val persistScope: CoroutineScope? =
        dispatchers?.let { CoroutineScope(SupervisorJob() + it.io) }

    /** Non-suspending peek — [LocalizationSnapshot.EMPTY] before the first push. */
    fun snapshot(): LocalizationSnapshot = _state.value

    /**
     * Decode [messagesJson] (a flat `{ "<key>": "<value>", … }` object) and
     * publish it alongside [language]. Non-string values are skipped rather than
     * failing the whole map (the i18n file is flat key→string, but a stray
     * null/nested value must not blank the copy). A decode failure is logged at
     * ERROR, reported to telemetry, and leaves the previous snapshot (and the
     * persisted copy) untouched. A successful push is persisted fire-and-forget
     * for cold-start restore. Host-only: Dart writes, the UI reads.
     */
    fun pushMessages(language: String, messagesJson: String) {
        try {
            val obj = json.decodeFromString<JsonObject>(messagesJson)
            val messages = buildMap(obj.size) {
                for ((key, element) in obj) {
                    (element as? JsonPrimitive)?.contentOrNull?.let { put(key, it) }
                }
            }
            val snapshot = LocalizationSnapshot(language = language, messages = messages)
            _state.value = snapshot
            // PII discipline: log the key COUNT, never the contents.
            logger.d(TAG, "pushMessages: language=$language, keys=${messages.size}")
            persist(snapshot)
        } catch (e: Exception) {
            logger.e(TAG, "pushMessages decode failed; keeping last good snapshot", e)
            // Near-impossible (Dart sends `jsonEncode` of a flat map) — so if it
            // fires it's a genuine anomaly worth telemetry. PII-safe: context only.
            crashReporter.report(e, mapOf("store" to TAG, "op" to "pushMessages"))
        }
    }

    /**
     * Restore the last-persisted snapshot on a cold start, so a KMP surface that
     * comes up before Flutter is alive to push (e.g. an FCM overlay on a
     * force-killed app) shows the last-known localized copy instead of the
     * English defaults. No-op without a wired store, if a push already landed, or
     * if nothing was persisted. Assigns **atomically** so it never clobbers a
     * push that raced in ahead of it — a fresh push always wins over disk.
     */
    suspend fun seedFromCache() {
        if (_state.value != LocalizationSnapshot.EMPTY) return
        val storage = preferenceStorage ?: return
        val raw = storage.getString(KEY_SNAPSHOT)?.takeIf { it.isNotBlank() } ?: return
        val restored = try {
            json.decodeFromString<LocalizationSnapshot>(raw)
        } catch (e: Exception) {
            logger.e(TAG, "seedFromCache decode failed; ignoring cached snapshot", e)
            crashReporter.report(e, mapOf("store" to TAG, "op" to "seedFromCache"))
            return
        }
        _state.update { current -> if (current == LocalizationSnapshot.EMPTY) restored else current }
    }

    /**
     * Persist [snapshot] as a single JSON blob under one key — `language` and
     * `messages` travel together so a reader never sees a half-updated pair.
     * Fire-and-forget on [AppDispatchers.io]; [PreferenceStorage] is fail-safe
     * (never throws, returns `false` on failure), so the UI is never gated on IO.
     */
    private fun persist(snapshot: LocalizationSnapshot) {
        val storage = preferenceStorage ?: return
        val scope = persistScope ?: return
        scope.launch {
            val ok = storage.putString(KEY_SNAPSHOT, json.encodeToString(snapshot))
            if (!ok) logger.w(TAG, "persist: putString returned false")
        }
    }

    /**
     * Look up [key], falling back to [fallback] (the caller's English default)
     * when absent or before the first push. Mirrors `LanguageProvider.getMessage`.
     * Pure passthrough — the value is returned verbatim, with no brace/placeholder
     * rewriting (single- vs double-brace alignment is each consumer's concern).
     */
    fun getMessage(key: String, fallback: String): String =
        _state.value.messages[key] ?: fallback

    /**
     * Look up [key] then substitute `{{param}}` tokens from [values]. Mirrors
     * `LanguageProvider.getFormattedMessage` (double-brace), so a bridged server
     * value such as `"You will miss earnings of ₹{{loss_amount}}"` interpolates
     * exactly as it does on the Flutter side.
     */
    fun getFormattedMessage(
        key: String,
        fallback: String,
        values: Map<String, String>,
    ): String = values.entries.fold(getMessage(key, fallback)) { acc, (param, value) ->
        acc.replace("{{$param}}", value)
    }

    private companion object {
        const val TAG = "LocalizationStore"
        const val KEY_SNAPSHOT = "localization_snapshot"
    }
}
