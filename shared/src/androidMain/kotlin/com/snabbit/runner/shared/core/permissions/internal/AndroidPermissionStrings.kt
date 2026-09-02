package com.snabbit.runner.shared.core.permissions.internal

import android.Manifest
import android.os.Build
import com.snabbit.runner.shared.core.permissions.SnabbitPermission

/**
 * The representative Android manifest permission string for a runtime [SnabbitPermission],
 * used for `shouldShowRequestPermissionRationale` and `checkSelfPermission`. `null` when
 * rationale/self-check doesn't apply (strict, informational, or special-access permissions
 * like exact-alarm that aren't requested via the runtime dialog).
 *
 * For media/notification permissions the backing runtime permission differs by API level; this
 * must stay in lockstep with Grant's own per-API mapping, otherwise the rationale / DENIED_ALWAYS
 * check runs against a permission Grant never requested (e.g. on API <=32 Photos resolves to
 * READ_EXTERNAL_STORAGE, not READ_MEDIA_IMAGES).
 */
internal fun SnabbitPermission.primaryAndroidPermission(): String? = when (this) {
    SnabbitPermission.LocationFine -> Manifest.permission.ACCESS_FINE_LOCATION
    SnabbitPermission.LocationCoarse -> Manifest.permission.ACCESS_COARSE_LOCATION
    SnabbitPermission.LocationBackground -> Manifest.permission.ACCESS_BACKGROUND_LOCATION
    SnabbitPermission.Camera -> Manifest.permission.CAMERA
    SnabbitPermission.Microphone -> Manifest.permission.RECORD_AUDIO
    SnabbitPermission.Contacts -> Manifest.permission.READ_CONTACTS

    SnabbitPermission.Notifications ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) "android.permission.POST_NOTIFICATIONS" else null
    // Photos and Storage intentionally resolve to the SAME backing permission here — this app only
    // needs image read access, so both map to READ_MEDIA_IMAGES (API 33+) / READ_EXTERNAL_STORAGE
    // (<=32). It is not a copy-paste bug: we deliberately don't request READ_MEDIA_VIDEO. Mirrors
    // Grant (GALLERY_IMAGES_ONLY / STORAGE both reduce to image read on this app). Both are also
    // manifest-stripped on 33+ (READ_MEDIA_* removed via tools:node="remove"), so they report
    // NOT_AVAILABLE there regardless; the ≤32 path is the one that actually grants.
    SnabbitPermission.Photos ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) "android.permission.READ_MEDIA_IMAGES"
        else Manifest.permission.READ_EXTERNAL_STORAGE
    SnabbitPermission.Storage ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) "android.permission.READ_MEDIA_IMAGES"
        else Manifest.permission.READ_EXTERNAL_STORAGE

    // No runtime-dialog permission string (special-access / strict / informational).
    SnabbitPermission.ExactAlarm,
    SnabbitPermission.Overlay,
    SnabbitPermission.BatteryOptimization,
    SnabbitPermission.AccessibilityService,
    SnabbitPermission.AdminPolicy -> null
}
