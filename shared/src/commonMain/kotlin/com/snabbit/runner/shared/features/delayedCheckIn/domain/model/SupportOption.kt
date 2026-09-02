package com.snabbit.runner.shared.features.job.delayedcheckin.domain.model

/**
 * One selectable option on the "Call Support Partner" grid (job support
 * bottom sheet). [id] is the value sent back as `disposition_tag` on
 * submit — see
 * [com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository.DelayedCheckinRepository.submitDisposition].
 */
data class SupportOption(
    val id: String,
    val label: String,
    val iconUrl: String? = null,
)
