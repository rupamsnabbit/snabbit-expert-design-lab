package com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Request body for `POST api/v1/runner_job/penalty/{runnerJobId}/disposition`.
 * `runnerJobId` itself is a path segment, not a body field — see
 * [com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.DelayedCheckinRemoteDataSource].
 */
@Serializable
data class DispositionRequestDto(
    @SerialName("job_id") val jobId: Int,
    @SerialName("runner_id") val runnerId: Int,
    @SerialName("disposition_tag") val dispositionTag: String,
    @SerialName("disposition_message") val dispositionMessage: String,
)
