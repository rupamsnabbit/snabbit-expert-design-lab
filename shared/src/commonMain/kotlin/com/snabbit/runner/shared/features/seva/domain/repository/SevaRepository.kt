package com.snabbit.runner.shared.features.seva.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint

/**
 * Domain port for nearby-Seva lookup. The production impl in `data/repository/`
 * collapses the data-layer `NetworkError` into [RunnerActionError] so domain +
 * presentation never see HTTP types — consistent with `ShiftRepository`. Seva
 * markers are best-effort decoration, so the caller (HomeViewModel) treats any
 * error as "no markers" rather than surfacing it.
 */
interface SevaRepository {
    suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int = 500,
        type: String = "all",
    ): Result<List<SevaPoint>, RunnerActionError>
}
