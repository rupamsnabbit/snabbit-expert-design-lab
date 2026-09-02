package com.snabbit.runner.shared.features.tiering.data

import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TieringProfile
import kotlinx.coroutines.flow.Flow

/**
 * Read seam for the tiering surfaces. Both flows are cold projections over the
 * Dart-fed stores ([com.snabbit.runner.shared.core.runnerstate.RunnerStateStore]
 * and [com.snabbit.runner.shared.features.profile.RunnerProfileStore]) — the
 * ViewModel collects them on `viewModelScope`. Main-safe by contract (the impl
 * decodes off [com.snabbit.runner.shared.core.AppDispatchers.default]).
 */
interface TieringDataSource {

    /** The live `current_state.tier_nudge` (a top-level sibling of `widget_data`), or null when absent / unparseable. */
    val nudge: Flow<TierNudge?>

    /** The tiering slice of the runner profile (`runners/me`), Dart-fed; empty defaults before the first push. */
    val profile: Flow<TieringProfile>

    /** The current `current_state` `widget_name` (drives the ECPO-926 job-state override); null before the first push. */
    val widgetName: Flow<String?>

    /** Decode the `THE_COIN_NUDGE` coins body from [nudge]'s raw `nudge_details`; null if absent or malformed. */
    fun coins(nudge: TierNudge): TierCoinsData?
}
