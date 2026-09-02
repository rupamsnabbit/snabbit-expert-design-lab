package com.snabbit.runner.shared.features.home.suspended.data

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.home.suspended.domain.model.SuspendedInfo
import com.snabbit.runner.shared.features.profile.ProfileBridgeState
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/**
 * Typed read model the Home VM consumes for the suspended-runner takeover.
 * Folds the `current_state` envelope stream into a [SuspendedInfo] when
 * `widget_name == RUNNER_SUSPENDED`, `null` for every other widget (the runner
 * is not suspended). Sibling of `ShiftProjector` / `LunchProjector`, each of
 * which owns its own slice of the widget space.
 *
 * The two variant flags come from the bridge-fed `runners/me` profile
 * ([RunnerProfileStore]) — Dart reads the same source (`UserProfile`):
 *  - [SuspendedInfo.isAadhaarRekyc] (`is_aadhaar_rekyc`) picks the card variant.
 *  - [SuspendedInfo.isRateCardV2Effective] (`is_rate_card_v2_effective`) picks
 *    the "Go to Earnings" destination.
 * Both degrade to `false` until Dart has pushed a profile (Loading/Error), which
 * matches Dart's null-safe `user?.isAadhaarRekyc == true` read.
 *
 * Concrete class, no interface — matches `ShiftProjector` / `LunchProjector`.
 */
class SuspendedProjector(
    private val store: RunnerStateStore,
    private val profileStore: RunnerProfileStore,
    scope: CoroutineScope,
) {
    private val _info = MutableStateFlow<SuspendedInfo?>(null)

    /** Latest suspended read model, or `null` when the runner is not suspended. */
    val info: StateFlow<SuspendedInfo?> = _info.asStateFlow()

    init {
        scope.launch {
            combine(store.state, profileStore.state) { state, profile ->
                toInfo(state, profile)
            }.collect { _info.value = it }
        }
    }

    /** Ask Dart to re-fetch `current_state` (e.g. after a reactivation request). */
    fun requestRefresh() = store.requestRefresh()

    /** Ask Dart to re-fetch the runner profile (`runners/me`) — the source of the
     *  suspended-card variant flags ([SuspendedInfo.isAadhaarRekyc] /
     *  [SuspendedInfo.isRateCardV2Effective]). Called on Home load/refresh so the
     *  flags are current before (or shortly after) the card first renders. */
    suspend fun requestProfileRefresh() = profileStore.requestRefresh()

    private fun toInfo(e: RunnerState?, profileState: ProfileBridgeState): SuspendedInfo? =
        if (e?.widgetName == RUNNER_SUSPENDED) {
            val profile = (profileState as? ProfileBridgeState.Content)?.profile
            SuspendedInfo(
                isAadhaarRekyc = profile?.isAadhaarRekyc == true,
                isRateCardV2Effective = profile?.isRateCardV2Effective == true,
            )
        } else {
            null
        }

    private companion object {
        const val RUNNER_SUSPENDED = "RUNNER_SUSPENDED"
    }
}
