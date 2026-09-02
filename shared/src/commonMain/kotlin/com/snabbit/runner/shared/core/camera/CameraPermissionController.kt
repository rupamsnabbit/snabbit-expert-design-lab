package com.snabbit.runner.shared.core.camera

/**
 * Camera permission state, normalized across platforms.
 *
 * - [GRANTED] — camera may be opened.
 * - [DENIED] — denied this time, but the OS will still show the prompt
 *   on a future request (re-requestable).
 * - [PERMANENTLY_DENIED] — the user chose "don't ask again" / the OS will
 *   no longer prompt. The only path forward is app settings.
 */
enum class CameraPermissionStatus { GRANTED, DENIED, PERMANENTLY_DENIED }

/**
 * Seam for camera-permission handling.
 *
 * The camera module depends only on this interface — never on Android's
 * `ActivityResult` API or iOS's `AVCaptureDevice` authorization directly.
 * [PermissionManagerCameraController] implements it by delegating to the shared
 * KMP permissions module's `PermissionManager`; the host can also supply its own.
 * Nothing in the camera flow changes regardless of which controller is injected.
 *
 * Mirrors the Flutter `PermissionRequester` / `PermissionDeniedHandler`
 * seams from `capture_image_handler.dart`.
 */
interface CameraPermissionController {

    /** Current status without prompting the user. */
    suspend fun status(): CameraPermissionStatus

    /**
     * Requests the permission, prompting if the OS allows it. Returns the
     * resulting status. Safe to call when already granted (returns [GRANTED]
     * without a prompt).
     */
    suspend fun request(): CameraPermissionStatus

    /**
     * Requests the microphone permission (`RECORD_AUDIO`), prompting if the OS
     * allows it. Only needed for a [CameraConfig.enableAudio] video capture.
     * Returns the resulting status; safe to call when already granted.
     *
     * Defaults to [CameraPermissionStatus.DENIED] (fail-closed): a controller
     * that doesn't manage audio must not silently report a permission it never
     * checked. Callers degrade to silent recording whenever this isn't
     * [CameraPermissionStatus.GRANTED], so a non-audio controller still never
     * blocks capture — it just won't claim a mic it hasn't verified.
     */
    suspend fun requestMicrophone(): CameraPermissionStatus = CameraPermissionStatus.DENIED

    /**
     * Opens the OS app-settings screen so the user can grant a
     * [CameraPermissionStatus.PERMANENTLY_DENIED] permission manually.
     */
    fun openAppSettings()
}

/**
 * Default seam impl that reports the permission as already granted and does
 * no gating. Use when the host handles permission externally, and as the
 * test/back-compat default so call sites that pre-gate aren't forced to
 * supply a controller. Production camera flows inject a real controller.
 */
object AlwaysGrantedCameraPermissionController : CameraPermissionController {
    override suspend fun status(): CameraPermissionStatus = CameraPermissionStatus.GRANTED
    override suspend fun request(): CameraPermissionStatus = CameraPermissionStatus.GRANTED
    override suspend fun requestMicrophone(): CameraPermissionStatus = CameraPermissionStatus.GRANTED
    override fun openAppSettings() { /* no-op */ }
}
