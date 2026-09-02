package com.snabbit.runner.shared.features.job.domain.model

/**
 * A selectable post-checkout house task the runner marks as done. Migrated from the Flutter
 * `HouseTask` (`rate_customer.dart`): [key] is the stable identifier submitted back to the backend
 * (`update_task_collection`), [imageUrl] the remote illustration (`asset_link`) shown on the tile —
 * null when the backend omits it.
 */
data class HouseTask(
    val key: String,
    val imageUrl: String?,
)
