package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.features.profile.data.remote.dto.RunnerProfileDto
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Read-model state for the runner profile (`runners/me`), fed from the Flutter side.
 * While the app is still mostly Flutter, Dart owns the single `runners/me` fetch and
 * pushes the result here — KMP does **not** fetch it natively (that would double the
 * API load). Error is a first-class pushed state so a failed Dart fetch surfaces on
 * the KMP Profile screen immediately, not after a timeout.
 */
sealed interface ProfileBridgeState {
    /** No push yet (before Dart's launch fetch resolves). */
    data object Loading : ProfileBridgeState

    /** Latest good profile pushed from Dart. */
    data class Content(val profile: RunnerProfile) : ProfileBridgeState

    /** Dart's `runners/me` fetch failed and there is no prior content to fall back to. */
    data class Error(val message: String?) : ProfileBridgeState
}

/**
 * Holds the latest [ProfileBridgeState] pushed from Dart and exposes it as a hot
 * [StateFlow]. Single instance, owned by Koin (`profileModule`) — the profile-data
 * analogue of [com.snabbit.runner.shared.core.runnerstate.RunnerStateStore], but the
 * payload is the whole `runners/me` body (decoded with the same [RunnerProfileDto]).
 *
 * Dart is the single source of truth: write-from-Dart ([pushProfile]/[pushProfileError]),
 * read-from-Compose ([state]/[snapshot]). A malformed payload never blanks a good screen —
 * it's logged and the last [Content] is preserved.
 *
 * Reverse direction: [requestRefresh] asks Dart to re-fetch `runners/me` (+ period-leave)
 * now — e.g. the Profile tab pulled-to-refresh. The host (`ProfileSyncPlugin`) installs a
 * [bind] bridge on plugin attach; the refreshed body flows back through [pushProfile].
 */
class RunnerProfileStore(private val logger: Logger) {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val _state = MutableStateFlow<ProfileBridgeState>(ProfileBridgeState.Loading)

    // Raw `runners/me` body kept alongside the decoded profile so a feature can decode a slice the
    // Profile DTO drops (Kavach reads `safety_shield` here instead of re-fetching runners/me) —
    // mirrors RunnerStateStore.envelope. Updated only on a good decode → a malformed push keeps last.
    private val _rawProfile = MutableStateFlow<JsonObject?>(null)

    // Suspending reverse bridge: [requestRefresh] awaits Dart's re-fetch + push, so a
    // pull-to-refresh spinner clears exactly when Dart finishes — even when the re-fetch
    // returns identical data (StateFlow would coalesce it) or fails. Set on plugin attach.
    private var refreshBridge: (suspend () -> Unit)? = null

    // Collapses concurrent refreshes (e.g. the shell's open-seed + the Profile VM's
    // open-seed racing) into a single Dart fetch — main-thread only, so a plain flag is safe.
    private var refreshing = false

    /** Latest state; replays to new collectors. Starts at [ProfileBridgeState.Loading]. */
    val state: StateFlow<ProfileBridgeState> = _state.asStateFlow()

    /** The profile when currently [Content], else null — for non-observing readers (e.g. the Earnings tab). */
    fun snapshot(): RunnerProfile? = (_state.value as? ProfileBridgeState.Content)?.profile

    /**
     * The raw `runners/me` body as a [JsonObject], or null before the first good push. Lets a feature
     * decode a slice the Profile DTO doesn't model — Kavach reads `safety_shield` here instead of
     * re-fetching runners/me. Non-suspending peek; kept last-good on a malformed push.
     */
    fun rawSnapshot(): JsonObject? = _rawProfile.value

    /**
     * The raw `runners/me` body as a hot [StateFlow] — the reactive counterpart of [rawSnapshot].
     * Observe THIS (not [state]) to decode a slice the Profile DTO drops: [state] dedupes on the
     * decoded [RunnerProfile], so it is BLIND to a change in a dropped field (e.g. the tiering
     * `has_viewed_intro` / `tier_effective_date` / `service_id`) and would silently swallow the
     * update. Re-emits on every good push; holds the last-good body on a malformed one.
     */
    val rawProfile: StateFlow<JsonObject?> = _rawProfile.asStateFlow()

    /**
     * Dart → KMP: the raw `runners/me` body. Decode → [Content]. A decode failure is
     * logged and, only if there's no prior content, surfaces as [Error] (stale-but-valid
     * beats a blank UI).
     */
    fun pushProfile(rawJson: String) {
        try {
            val element = json.parseToJsonElement(rawJson)
            _state.value = ProfileBridgeState.Content(
                json.decodeFromJsonElement(RunnerProfileDto.serializer(), element).toDomain(),
            )
            // Retain the raw body only on a successful decode → a malformed push keeps the last good.
            (element as? JsonObject)?.let { _rawProfile.value = it }
        } catch (e: Exception) {
            logger.e(TAG, "pushProfile decode failed", e)
            if (_state.value !is ProfileBridgeState.Content) {
                _state.value = ProfileBridgeState.Error(null)
            }
        }
    }

    /**
     * Dart → KMP: the `runners/me` fetch failed. Surface [Error] immediately — unless we
     * already have [Content] (a failed pull-to-refresh keeps the last good profile on screen).
     */
    fun pushProfileError(message: String?) {
        if (_state.value !is ProfileBridgeState.Content) {
            _state.value = ProfileBridgeState.Error(message)
        }
    }

    /**
     * Publish a [RunnerProfile] directly as [Content] (without JSON decoding). Used by a
     * future iOS native-fetch path and by tests; the Android bridge uses [pushProfile].
     */
    fun setProfile(profile: RunnerProfile) {
        _state.value = ProfileBridgeState.Content(profile)
    }

    /**
     * Optimistically patch the cached profile's [RunnerProfile.languagePreference] after a
     * successful language change, so the native Profile / Language screens reflect the new
     * language immediately — even when the change happens entirely inside the Compose host
     * (Flutter engine backgrounded), where a Dart re-push can't be relied on. No-op until
     * there's a [Content] profile to patch, or when the value is unchanged. Corrected by the
     * next authoritative Dart push (which already carries the new language, since the server
     * persist succeeded first). The raw body ([rawSnapshot]) is intentionally left
     * untouched — it backs non-language slices (e.g. Kavach's `safety_shield`).
     */
    fun patchLanguagePreference(code: String) {
        val current = snapshot() ?: return
        if (current.languagePreference == code) return
        _state.value = ProfileBridgeState.Content(
            current.copy(languagePreference = code),
        )
    }

    /** Install (or clear, with `null`) the suspending bridge that forwards [requestRefresh] to Dart. */
    fun bind(bridge: (suspend () -> Unit)?) {
        refreshBridge = bridge
    }

    /**
     * Ask Dart to re-fetch `runners/me` (+ period-leave) and suspend until it finishes
     * (the fresh body flows back through [pushProfile] during that call). Concurrent calls
     * collapse to one fetch. No-op if no bridge is bound (e.g. tests, or plugin not yet
     * attached).
     */
    suspend fun requestRefresh() {
        if (refreshing) return
        refreshing = true
        try {
            refreshBridge?.invoke()
        } finally {
            refreshing = false
        }
    }

    private companion object {
        const val TAG = "RunnerProfileStore"
    }
}
