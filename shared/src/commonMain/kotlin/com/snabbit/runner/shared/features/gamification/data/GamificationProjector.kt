package com.snabbit.runner.shared.features.gamification.data

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.gamification.domain.model.GamificationState
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

/**
 * Typed gamification read model the feature VMs consume — the KMP analogue of the
 * gamification fields on Flutter's `RunnerRtDataProvider`, and the replacement
 * for the Dart `GamificationManager`.
 *
 * Folds the raw `current_state` envelope stream ([RunnerStateStore.envelope])
 * into a [GamificationState] (nudges, sheet warnings, cta-override map, coin /
 * red-card totals) via [GamificationParser]. Concrete class, no interface —
 * matches `ShiftProjector` / `LunchProjector` and `coreModule`.
 *
 * Parsing never throws; a malformed row is dropped and reported to
 * [CrashReporter] (the port of Dart's non-fatal Crashlytics logging). Staleness
 * of sheet warnings is evaluated against [currentTimeMs] so it is testable.
 */
class GamificationProjector(
    private val store: RunnerStateStore,
    scope: CoroutineScope,
    private val currentTimeMs: CurrentTimeMs,
    crashReporter: CrashReporter,
) {
    private val parser = GamificationParser(
        onError = { throwable, tag ->
            crashReporter.report(throwable, mapOf("op" to "GamificationParser.$tag"))
        },
    )

    private val _state = MutableStateFlow(GamificationState.EMPTY)

    /** Latest parsed gamification state. Seeded [GamificationState.EMPTY], replays to new collectors. */
    val state: StateFlow<GamificationState> = _state.asStateFlow()

    init {
        scope.launch {
            store.envelope.collect { envelope ->
                // Feed the prior state so the parser can carry forward the coin /
                // red-card totals when an envelope omits them (Flutter parity).
                _state.update { prev -> parser.parseState(envelope, currentTimeMs(), prev) }
            }
        }
    }

    /** Ask Dart to re-fetch `current_state` (e.g. a nudge countdown expired). */
    fun requestRefresh() = store.requestRefresh()

    /**
     * Parse a per-action response body (already a [JsonObject]) into a
     * [PostActionOutcome] — the KMP port of Dart
     * `PostActionOverlayController.parseFromResponse`. Null when the response
     * carries no `post_action_outcome`. Pure; does not touch [state].
     */
    fun parsePostActionOutcome(response: JsonObject?): PostActionOutcome? =
        parser.parsePostActionOutcome(response)
}
