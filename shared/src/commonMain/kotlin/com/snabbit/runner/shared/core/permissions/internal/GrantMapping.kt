package com.snabbit.runner.shared.core.permissions.internal

import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import dev.brewkits.grant.AppGrant
import dev.brewkits.grant.GrantPermission
import dev.brewkits.grant.GrantStatus
import dev.brewkits.grant.RawPermission

/**
 * Pure mapping between our types and Grant's. No platform APIs → unit-testable in commonTest.
 *
 * Kept as `internal` extension functions in this `internal` package (not members of
 * [SnabbitPermission]) so the public sealed type stays free of Grant types — consumers
 * (IoT, location) see a Grant-agnostic permission API and don't transitively couple to
 * `GrantPermission`/`GrantStatus`. (Grant itself is multiplatform incl. iOS, so this is about
 * API surface, not platform availability.)
 */

/**
 * The Grant permission backing a runtime [SnabbitPermission], or `null` for a
 * strict/informational permission Grant does not handle (overlay, battery, accessibility,
 * admin policy).
 *
 * Implication of `null`: such a permission is **not a Grant runtime permission**, so the
 * platform [com.snabbit.runner.shared.core.permissions.PermissionManager] must route it to a
 * strict-settings handler or the admin checker — it never reaches [GrantRuntimeDelegate]. The
 * delegate treats `null` defensively as [PermissionStatus.NOT_AVAILABLE] (it should never be
 * asked about one). `requestMultiple` uses `null` to partition runtime vs strict/info inputs.
 *
 * `LocationCoarse` has no dedicated `AppGrant` constant, so it is expressed as a
 * [RawPermission] (equal by value, which keeps it usable as a map key).
 */
internal fun SnabbitPermission.toGrantOrNull(): GrantPermission? = when (this) {
    SnabbitPermission.LocationFine -> AppGrant.LOCATION
    SnabbitPermission.LocationCoarse -> RawPermission(
        identifier = "SNABBIT_LOCATION_COARSE",
        androidPermissions = listOf("android.permission.ACCESS_COARSE_LOCATION"),
        iosUsageKey = "NSLocationWhenInUseUsageDescription",
    )
    SnabbitPermission.LocationBackground -> AppGrant.LOCATION_ALWAYS
    SnabbitPermission.Camera -> AppGrant.CAMERA
    SnabbitPermission.Microphone -> AppGrant.MICROPHONE
    SnabbitPermission.Contacts -> AppGrant.READ_CONTACTS
    SnabbitPermission.Notifications -> AppGrant.NOTIFICATION
    SnabbitPermission.ExactAlarm -> AppGrant.SCHEDULE_EXACT_ALARM
    SnabbitPermission.Photos -> AppGrant.GALLERY_IMAGES_ONLY
    SnabbitPermission.Storage -> AppGrant.STORAGE

    SnabbitPermission.Overlay,
    SnabbitPermission.BatteryOptimization,
    SnabbitPermission.AccessibilityService,
    SnabbitPermission.AdminPolicy -> null
}

/**
 * Lowest API level below which this permission has **no usable form at all** in our mapping, so
 * the delegate short-circuits to [PermissionStatus.NOT_AVAILABLE] before ever calling Grant.
 * `1` = "no such hard floor" (always reachable through Grant on every supported API).
 *
 * This is NOT a full per-permission "introduced in API X" table, and deliberately so. Grant owns
 * the real per-API behavior: permissions that don't exist as a runtime dialog below some level are
 * either implicitly granted there (e.g. `POST_NOTIFICATIONS`/`SCHEDULE_EXACT_ALARM` pre-33/31) or
 * fall back to a legacy permission (e.g. media → `READ_EXTERNAL_STORAGE` ≤32). Gating those here
 * would wrongly force `NOT_AVAILABLE` and skip Grant's correct handling. The only hard floor is
 * `LocationBackground`: `ACCESS_BACKGROUND_LOCATION` simply does not exist before API 29.
 *
 * Exhaustive on purpose (no `else`): adding a [SnabbitPermission] forces an explicit API-floor
 * decision here rather than silently defaulting to `1`.
 */
internal fun SnabbitPermission.minApiLevel(): Int = when (this) {
    SnabbitPermission.LocationBackground -> 29   // ACCESS_BACKGROUND_LOCATION (API 29)

    // No hard floor — reachable via Grant on every supported API (Grant handles per-API nuance,
    // implicit-grant, and legacy fallbacks). minSdk is 26.
    SnabbitPermission.LocationFine,
    SnabbitPermission.LocationCoarse,
    SnabbitPermission.Camera,
    SnabbitPermission.Microphone,
    SnabbitPermission.Contacts,
    SnabbitPermission.Notifications,
    SnabbitPermission.ExactAlarm,
    SnabbitPermission.Photos,
    SnabbitPermission.Storage,
    SnabbitPermission.Overlay,
    SnabbitPermission.BatteryOptimization,
    SnabbitPermission.AccessibilityService,
    SnabbitPermission.AdminPolicy -> 1
}

/** Collapse Grant's 6-value status onto our 4-value [PermissionStatus]. */
internal fun GrantStatus.toPermissionStatus(): PermissionStatus = when (this) {
    GrantStatus.GRANTED -> PermissionStatus.GRANTED
    GrantStatus.PARTIAL_GRANTED -> PermissionStatus.GRANTED   // limited access is still usable
    GrantStatus.DENIED -> PermissionStatus.DENIED
    GrantStatus.DENIED_ALWAYS -> PermissionStatus.DENIED_ALWAYS
    GrantStatus.NOT_DETERMINED -> PermissionStatus.DENIED     // caller then triggers request()
    GrantStatus.BUSY -> PermissionStatus.DENIED               // transient; caller may retry
}

/**
 * Status collapse that matches the app's existing `permission_handler` semantics per permission.
 *
 * `permission_handler` treats `Permission.locationAlways` as ONLY `ACCESS_BACKGROUND_LOCATION`, so
 * foreground-only ("while using") reports DENIED for it. Grant instead returns `PARTIAL_GRANTED`
 * for foreground-only, so for [SnabbitPermission.LocationBackground] we map that to `DENIED` —
 * otherwise a caller would think "Allow all the time" is granted and skip the background upgrade.
 * Every other permission keeps the generic collapse (Photos' partial access is genuinely usable).
 *
 * This does NOT limit foreground capability: a caller that only needs in-use location checks
 * [SnabbitPermission.LocationFine]/[SnabbitPermission.LocationCoarse] (which report GRANTED on a
 * while-using grant). [SnabbitPermission.LocationBackground] is specifically the "all the time"
 * capability, so reporting DENIED until background is actually granted is the correct signal —
 * and Grant drives the OS 2-step flow (foreground dialog → background settings) on request.
 */
internal fun GrantStatus.toPermissionStatus(permission: SnabbitPermission): PermissionStatus =
    if (this == GrantStatus.PARTIAL_GRANTED && permission == SnabbitPermission.LocationBackground) {
        PermissionStatus.DENIED
    } else {
        toPermissionStatus()
    }
