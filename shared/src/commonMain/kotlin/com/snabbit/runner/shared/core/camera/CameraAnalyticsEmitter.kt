package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/**
 * Emits camera lifecycle/action analytics.
 *
 * The camera module **owns** the event names and property schema (matching the
 * app's existing `capture_image_*` events) and the decision of *when* to fire — so
 * consumers no longer implement an analytics interface. A consumer supplies only a
 * [source] (the launch context — e.g. `"go_live"`, `"shift_login"`) and the shared
 * [AnalyticsTracker]; every event is tagged with `source` plus the capture config.
 *
 * **Routing note:** [AnalyticsTracker.track] fans out to the registered providers
 * (currently AppsFlyer) and does **not** pass through the Dart-side event allowlist,
 * so these events land wherever the analytics module routes — not CleverTap/Mixpanel
 * by default. To send them to CT/MP, register a CT/MP `AnalyticsProvider` (or inject
 * a bridging tracker); this emitter is channel-agnostic and needs no change.
 */
class CameraAnalyticsEmitter(
    private val tracker: AnalyticsTracker,
    private val source: String,
) {
    /** Capture (photo) or recording (video) started. */
    fun captureStarted(config: CameraConfig) =
        tracker.track(EVENT_STARTED, baseProps(config))

    /** Capture/recording completed successfully. */
    fun captureCompleted(config: CameraConfig, sizeBytes: Long, durationMs: Long) =
        tracker.track(
            EVENT_COMPLETED,
            baseProps(config) + mapOf(PROP_SIZE_BYTES to sizeBytes, PROP_DURATION_MS to durationMs),
        )

    /** User dismissed the camera without capturing. */
    fun captureCancelled(config: CameraConfig) =
        tracker.track(EVENT_CANCELLED, baseProps(config))

    /** Capture/recording failed. [errorCode] is a [CameraErrorCode] constant. */
    fun captureFailed(config: CameraConfig, errorCode: String) =
        tracker.track(EVENT_FAILED, baseProps(config) + mapOf(PROP_ERROR_CODE to errorCode))

    /** Camera permission denied ([status] is `"denied"` or `"permanently_denied"`). */
    fun permissionDenied(status: String) =
        tracker.track(EVENT_PERMISSION_DENIED, mapOf(PROP_SOURCE to source, PROP_STATUS to status))

    private fun baseProps(config: CameraConfig): Map<String, Any?> = mapOf(
        PROP_SOURCE to source,
        PROP_LENS to config.lens.name.lowercase(),
        PROP_MODE to config.mode.name.lowercase(),
        PROP_QUALITY to config.quality.name.lowercase(),
    )

    private companion object {
        const val EVENT_STARTED = "capture_image_started"
        const val EVENT_COMPLETED = "capture_image_completed"
        const val EVENT_CANCELLED = "capture_image_cancelled"
        const val EVENT_FAILED = "capture_image_failed"
        const val EVENT_PERMISSION_DENIED = "capture_image_permission_denied"

        const val PROP_SOURCE = "source"
        const val PROP_LENS = "lens"
        const val PROP_MODE = "mode"
        const val PROP_QUALITY = "quality"
        const val PROP_SIZE_BYTES = "size_bytes"
        const val PROP_DURATION_MS = "duration_ms"
        const val PROP_ERROR_CODE = "error_code"
        const val PROP_STATUS = "status"
    }
}
