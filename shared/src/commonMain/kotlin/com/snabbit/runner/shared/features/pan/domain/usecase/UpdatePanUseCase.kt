package com.snabbit.runner.shared.features.pan.domain.usecase

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.pan.domain.repository.PanRepository

/**
 * Submits the runner's PAN number. Thin stateless wrapper over [PanRepository] —
 * the seam the Profile ViewModel calls for the PAN nudge sheet. Returns a
 * user-facing error message on failure.
 */
class UpdatePanUseCase(
    private val repository: PanRepository,
) {
    suspend operator fun invoke(panNumber: String): Result<Unit, String> =
        repository.updatePan(panNumber)
}
