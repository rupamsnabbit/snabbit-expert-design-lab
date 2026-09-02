package com.snabbit.runner.shared.core.permissions

import kotlinx.coroutines.flow.Flow

/**
 * The single entry point for all permission operations (Facade).
 *
 * Platform implementations route runtime permissions to the Grant library, strict
 * permissions (overlay/battery/accessibility) to custom Settings-intent handlers, and
 * informational checks (admin policy) to read-only queries.
 *
 * Every call is exception-safe: an unexpected platform error resolves to a safe value
 * (with diagnostics) rather than crashing.
 *
 * ## Usage contract — who calls what, and from where
 *
 * This is a process-scoped singleton (Koin `single`) so headless callers (IoT/background
 * collectors, the location module, future iOS) can share one instance that survives Activity
 * recreation. Android splits permission work into two categories with different requirements:
 *
 *  - **Reads — Activity-independent, safe anywhere (incl. app killed / background service).**
 *    [check], [isPreciseLocationGranted], [isServiceEnabled], [checkAdminPolicy] only read OS
 *    state (`checkSelfPermission` etc.) and need just a `Context`. These are the calls a
 *    background consumer should use (e.g. the IoT collector calls `check(LocationFine)` before
 *    collecting while the app is killed).
 *
 *  - **Requests / rationale — require an attached Activity; UI-layer only.** [request],
 *    [requestMultiple] and [shouldShowRationale] need a live `Activity` (Android cannot show a
 *    permission dialog, or distinguish "permanently denied" via
 *    `shouldShowRequestPermissionRationale`, without one). The host **must** attach the Activity
 *    via `ActivityAttachable.attachActivity()` in `onCreate` and `detach()` in `onDestroy`.
 *    Called with **no Activity attached** (pure background / before attach), they **degrade
 *    safely** — `request`/`requestMultiple` return [PermissionStatus.DENIED] (never a false
 *    [PermissionStatus.DENIED_ALWAYS], never a crash) and `shouldShowRationale` returns `false`
 *    — but they cannot produce full semantics. By convention: **the UI/Activity layer drives
 *    permission requests, then loads the modules that depend on the granted permissions.**
 */
interface PermissionManager {

    /** Current status, without showing any UI. Activity-independent — safe from background. */
    suspend fun check(permission: SnabbitPermission): PermissionStatus

    /**
     * Request a single permission. Suspends until the user responds.
     * Runtime → system dialog; strict → Settings screen; informational → no-op check.
     *
     * **Requires an attached Activity** (UI layer). With none attached (background / pre-attach)
     * it can't show a dialog and returns [PermissionStatus.DENIED]. See the interface contract.
     */
    suspend fun request(permission: SnabbitPermission): PermissionStatus

    /**
     * Request multiple permissions. Matches the app's current `permission_handler`
     * behaviour: runtime permissions are requested in one batch (the OS shows their
     * dialogs back-to-back), and each result is emitted as a
     * `(permission, status)` pair. Already-granted permissions are emitted without a dialog.
     *
     * **Requires an attached Activity** (see the interface contract); with none attached each
     * permission degrades to [PermissionStatus.DENIED]. Do NOT include
     * [SnabbitPermission.LocationBackground] in a batch with foreground permissions — Android
     * drops the whole request; request background location on its own after foreground is granted.
     */
    fun requestMultiple(permissions: List<SnabbitPermission>): Flow<Pair<SnabbitPermission, PermissionStatus>>

    /**
     * Whether to show a rationale before requesting.
     * `true`  → user denied before (not permanently) — show explanation, then request.
     * `false` → never asked yet, or permanently denied — just request or open settings.
     *
     * **Requires an attached Activity** (`shouldShowRequestPermissionRationale` needs one);
     * returns `false` with no Activity attached. See the interface contract.
     */
    fun shouldShowRationale(permission: SnabbitPermission): Boolean

    /**
     * Android 12+: distinguishes precise (`ACCESS_FINE_LOCATION`) from approximate
     * (`ACCESS_COARSE_LOCATION` only). Mirrors geolocator's accuracy check.
     */
    fun isPreciseLocationGranted(): Boolean

    /** Open the app's system settings page (for `DENIED_ALWAYS` recovery). Fire-and-forget. */
    fun openSettings()

    /** Whether a hardware/OS service toggle is currently on (not a permission check). */
    fun isServiceEnabled(service: ServiceType): Boolean

    /** Read-only device-admin / MDM snapshot. */
    fun checkAdminPolicy(): AdminPolicyInfo
}
