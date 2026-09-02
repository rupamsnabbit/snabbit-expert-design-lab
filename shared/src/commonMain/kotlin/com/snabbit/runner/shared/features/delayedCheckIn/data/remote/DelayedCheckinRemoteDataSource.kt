package com.snabbit.runner.shared.features.job.delayedcheckin.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto.DispositionRequestDto

/**
 * Raw network seam for the delayed check-in support endpoints — KMP-native,
 * via [com.snabbit.runner.shared.core.network.SnabbitHttpClient]. Returns
 * the transport-level [Result] unopinionated; JSON decoding into domain
 * types happens one layer up, in
 * [com.snabbit.runner.shared.features.job.delayedcheckin.data.repository.DelayedCheckinRepositoryImpl].
 *
 * `suspend` + main-safe: implementations switch off the main thread internally.
 */
interface DelayedCheckinRemoteDataSource {

    /** `POST api/v1/runner_job/penalty/{runnerJobId}/disposition?ameyo_support=<bool>`. */
    suspend fun submitDisposition(
        runnerJobId: Int,
        ameyoSupport: Boolean,
        body: DispositionRequestDto,
    ): Result<SuccessResponse, NetworkError>

    /** `GET api/v1/runners/me/helpline?type=<widgetType>`. */
    suspend fun getHelpline(widgetType: String): Result<SuccessResponse, NetworkError>
}
