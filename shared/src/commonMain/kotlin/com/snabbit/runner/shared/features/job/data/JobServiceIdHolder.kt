package com.snabbit.runner.shared.features.job.data

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Holds the logged-in runner's profile `service_id` (Cook vs Expert), pushed from Dart via
 * `JobScreenLauncherPlugin`'s config channel and read by the job UI to pick the New-Job header
 * glyph. One Koin single shared by both surfaces — the foreground `ActiveJobOverlay` (over the
 * tabs) and the backgrounded draw-over `NewJobOverlayService`. Null until Dart pushes it; the
 * header then falls back to the envelope-derived category.
 */
class JobServiceIdHolder {
    private val _serviceId = MutableStateFlow<Int?>(null)
    val serviceId: StateFlow<Int?> = _serviceId.asStateFlow()

    fun set(id: Int?) {
        _serviceId.value = id
    }
}
