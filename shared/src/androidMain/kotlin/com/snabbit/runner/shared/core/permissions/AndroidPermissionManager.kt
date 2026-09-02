package com.snabbit.runner.shared.core.permissions

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.permissions.internal.AndroidServiceChecker
import com.snabbit.runner.shared.core.permissions.internal.GrantRuntimeDelegate
import com.snabbit.runner.shared.core.permissions.internal.primaryAndroidPermission
import com.snabbit.runner.shared.core.permissions.internal.toGrantOrNull
import com.snabbit.runner.shared.core.permissions.strict.AccessibilityHandler
import com.snabbit.runner.shared.core.permissions.strict.AdminPolicyChecker
import com.snabbit.runner.shared.core.permissions.strict.BatteryOptHandler
import com.snabbit.runner.shared.core.permissions.strict.OverlayPermissionHandler
import com.snabbit.runner.shared.core.permissions.strict.StrictPermissionHandler
import dev.brewkits.grant.GrantManager
import dev.brewkits.grant.impl.AndroidGrantLauncher
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.lang.ref.WeakReference
import kotlin.coroutines.resume

/**
 * Android [PermissionManager]: routes runtime permissions to Grant (via [GrantRuntimeDelegate]),
 * strict permissions to Settings-intent [StrictPermissionHandler]s, and informational queries
 * to [AdminPolicyChecker]. Also implements [ActivityAttachable] — the host Activity wires its
 * launchers here in `onCreate`.
 *
 * Every public call is exception-safe: an unexpected failure resolves to a re-askable
 * [PermissionStatus.DENIED] (never the permanent [PermissionStatus.NOT_AVAILABLE], which would
 * make callers give up for good) and is recorded to [CrashReporter], so a flaky OEM API can
 * never crash the app. Genuine "not available here" determinations (API-level gate, AdminPolicy,
 * unresolvable Settings screen) return [PermissionStatus.NOT_AVAILABLE] explicitly.
 *
 * Threading:
 *  - [attachActivity]/[detach] must run on the **main thread** in the Activity's `onCreate`/
 *    `onDestroy` — `registerForActivityResult` requires registration before STARTED.
 *  - `request`/`requestStrict` are safe to call from any dispatcher: `requestStrict` confines its
 *    launcher dispatch + continuation slot to the main thread internally (the launcher result
 *    callbacks fire there too), so an off-main caller never races the `pendingStrict` slot.
 *  - `check`/`request` delegate to Grant, whose work (`checkSelfPermission`) is fast and
 *    main-safe; callers may invoke them from `Dispatchers.Main` without ANR risk.
 *  - `shouldShowRationale`/`isPreciseLocationGranted`/`isServiceEnabled`/`openSettings`/
 *    `checkAdminPolicy` are synchronous and main-safe.
 */
internal class AndroidPermissionManager(
    private val context: Context,
    private val grantManager: GrantManager,
    private val crashReporter: CrashReporter,
) : PermissionManager, ActivityAttachable {

    private val delegate = GrantRuntimeDelegate(grantManager) { Build.VERSION.SDK_INT }

    private val overlayHandler = OverlayPermissionHandler(context)
    private val batteryHandler = BatteryOptHandler(context)
    private val accessibilityHandler = AccessibilityHandler(context)
    private val adminChecker = AdminPolicyChecker(context, crashReporter)
    private val serviceChecker = AndroidServiceChecker(context, crashReporter)

    // Remembers which permissions have been requested at least once, so a `DENIED` with
    // `shouldShowRationale == false` can be distinguished as DENIED_ALWAYS (vs. never-asked).
    // Necessary because Grant cannot make this distinction in our usage: Grant computes
    // DENIED_ALWAYS only when its `PlatformConfig.activity` is set, but that field is `internal`
    // to grant-core (unsettable from our code) and neither GrantFactory nor AndroidGrantLauncher
    // populate it — so Grant always returns plain DENIED. We compute the upgrade ourselves.
    private val requestedStore =
        context.getSharedPreferences("snabbit_permissions_requested", Context.MODE_PRIVATE)

    // Runtime permissions actually present in the merged manifest. A stripped/undeclared one
    // (e.g. READ_MEDIA_* removed via tools:node="remove") can't be granted by a dialog or in
    // Settings, so it resolves to NOT_AVAILABLE. Read once — the manifest can't change at runtime.
    private val declaredPermissions: Set<String> by lazy {
        try {
            context.packageManager
                .getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
                .requestedPermissions?.toSet().orEmpty()
        } catch (t: Throwable) {
            emptySet()
        }
    }

    private var activityRef: WeakReference<ComponentActivity>? = null
    private var settingsLauncher: ActivityResultLauncher<Intent>? = null

    // Single in-flight strict (Settings) request; resumed from the launcher callback.
    private var pendingStrict: CancellableContinuation<PermissionStatus>? = null
    private var pendingStrictHandler: StrictPermissionHandler? = null

    // --- ActivityAttachable ---

    override fun attachActivity(activity: ComponentActivity) {
        if (activityRef?.get() === activity) return // already attached to this instance
        // Self-heal: if we're re-attaching to a NEW Activity instance without a prior detach()
        // (e.g. config-change/process-death recreation where onDestroy's detach was missed or
        // raced), tear down the old state first. Otherwise the previous launcher would leak and
        // an in-flight strict continuation bound to the dead launcher would hang forever.
        releaseActivityState()
        activityRef = WeakReference(activity)
        try {
            grantManager.setLauncher(AndroidGrantLauncher.from(activity))
            settingsLauncher = activity.registerForActivityResult(
                ActivityResultContracts.StartActivityForResult(),
            ) { onStrictSettingsResult() }
        } catch (t: Throwable) {
            // Registering after STARTED throws — surface it; attach earlier (onCreate).
            crashReporter.report(t, mapOf("op" to "attachActivity: launcher registration failed"))
        }
    }

    override fun detach() = releaseActivityState()

    /**
     * Resume/clear any in-flight strict request and release the launcher + Activity ref. Called
     * from both [detach] (onDestroy) and [attachActivity] (defensive, before re-registering on a
     * new instance), so a missed/raced detach can never strand the suspended request() — its
     * awaiting caller always gets a result instead of hanging.
     */
    private fun releaseActivityState() {
        // Resume any in-flight strict request before the launcher dies with the Activity.
        // Re-check the handler so a grant completed just before recreation is still reported.
        pendingStrict?.let { cont ->
            val granted = try {
                pendingStrictHandler?.isGranted() == true
            } catch (t: Throwable) {
                crashReporter.report(t, mapOf("op" to "strict re-check on detach"))
                false
            }
            if (cont.isActive) {
                cont.resume(if (granted) PermissionStatus.GRANTED else PermissionStatus.DENIED)
            }
        }
        pendingStrict = null
        pendingStrictHandler = null
        settingsLauncher?.unregister()
        settingsLauncher = null
        activityRef = null
    }

    // --- PermissionManager ---

    override suspend fun check(permission: SnabbitPermission): PermissionStatus =
        safe("check:$permission") {
            when (permission) {
                SnabbitPermission.Overlay,
                SnabbitPermission.BatteryOptimization,
                SnabbitPermission.AccessibilityService ->
                    if (strictHandler(permission).isGranted()) PermissionStatus.GRANTED else PermissionStatus.DENIED

                SnabbitPermission.AdminPolicy -> PermissionStatus.NOT_AVAILABLE // use checkAdminPolicy()

                else -> refine(permission, delegate.check(permission))
            }
        }

    override suspend fun request(permission: SnabbitPermission): PermissionStatus =
        safe("request:$permission") {
            when (permission) {
                SnabbitPermission.Overlay,
                SnabbitPermission.BatteryOptimization,
                SnabbitPermission.AccessibilityService -> requestStrict(strictHandler(permission))

                SnabbitPermission.AdminPolicy -> PermissionStatus.NOT_AVAILABLE

                else -> {
                    markRequested(permission)
                    refine(permission, delegate.request(permission))
                }
            }
        }

    /**
     * Runtime permissions are requested as one Grant batch (matching `permission_handler`) and
     * emitted first, in input order; strict/informational permissions follow, each handled
     * individually (they need a Settings round-trip).
     */
    override fun requestMultiple(
        permissions: List<SnabbitPermission>,
    ): Flow<Pair<SnabbitPermission, PermissionStatus>> = flow {
        val runtime = permissions.filter { it.toGrantOrNull() != null }
        val others = permissions.filter { it.toGrantOrNull() == null }

        if (runtime.isNotEmpty()) {
            runtime.forEach { markRequested(it) }
            try {
                delegate.requestMultiple(runtime).collect { (permission, status) ->
                    emit(permission to refine(permission, status))
                }
            } catch (c: CancellationException) {
                throw c // never swallow cancellation
            } catch (t: Throwable) {
                crashReporter.report(t, mapOf("op" to "requestMultiple(runtime) failed"))
                // Transient failure → DENIED (re-askable), NOT NOT_AVAILABLE (which means
                // "doesn't exist on this device" and would make callers give up permanently).
                runtime.forEach { emit(it to PermissionStatus.DENIED) }
            }
        }

        others.forEach { permission -> emit(permission to request(permission)) }
    }

    override fun shouldShowRationale(permission: SnabbitPermission): Boolean {
        val androidPerm = permission.primaryAndroidPermission() ?: return false
        val activity = activityRef?.get() ?: return false
        return try {
            ActivityCompat.shouldShowRequestPermissionRationale(activity, androidPerm)
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "shouldShowRationale:$permission"))
            false
        }
    }

    override fun isPreciseLocationGranted(): Boolean = try {
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to "isPreciseLocationGranted"))
        false
    }

    override fun openSettings() {
        try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            (activityRef?.get() ?: context).startActivity(intent)
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "openSettings"))
        }
    }

    override fun isServiceEnabled(service: ServiceType): Boolean = serviceChecker.isEnabled(service)

    override fun checkAdminPolicy(): AdminPolicyInfo = adminChecker.check()

    // --- internals ---

    /**
     * Refine a runtime `DENIED`:
     *  - If the permission's manifest entry is absent (stripped via `tools:node="remove"`, e.g.
     *    media perms on API 33+), it can't be granted by a dialog or in Settings → `NOT_AVAILABLE`.
     *  - Otherwise upgrade to `DENIED_ALWAYS` when it was asked before and the OS no longer offers
     *    a rationale (i.e. "don't ask again").
     *
     * We must compute DENIED_ALWAYS ourselves because Grant cannot in our setup: Grant only emits
     * DENIED_ALWAYS when its `PlatformConfig.activity` is non-null, but that field is `internal` to
     * grant-core and is never populated by `GrantFactory.create` / `AndroidGrantLauncher.from`, so
     * Grant always returns plain DENIED. We hold our own Activity `WeakReference` and a persisted
     * requested-before set to make the same determination.
     *
     * Coexistence caveat: "asked before" is tracked only for requests made through THIS module.
     * A permission permanently denied via the legacy `permission_handler` path reports `DENIED`
     * here until it has been requested once through this module.
     */
    private fun refine(permission: SnabbitPermission, status: PermissionStatus): PermissionStatus {
        if (status != PermissionStatus.DENIED) return status
        val androidPerm = permission.primaryAndroidPermission() ?: return status
        // Stripped/undeclared → genuinely not grantable on this build. (Guarded: skip when the
        // manifest can't be read, e.g. unit tests, so we don't over-report NOT_AVAILABLE.)
        if (declaredPermissions.isNotEmpty() && androidPerm !in declaredPermissions) {
            return PermissionStatus.NOT_AVAILABLE
        }
        if (!isRequested(permission)) return PermissionStatus.DENIED // never asked → still askable
        val activity = activityRef?.get() ?: return PermissionStatus.DENIED // can't tell → safest
        val canAskAgain = ActivityCompat.shouldShowRequestPermissionRationale(activity, androidPerm)
        return if (canAskAgain) PermissionStatus.DENIED else PermissionStatus.DENIED_ALWAYS
    }

    private fun strictHandler(permission: SnabbitPermission): StrictPermissionHandler = when (permission) {
        SnabbitPermission.Overlay -> overlayHandler
        SnabbitPermission.BatteryOptimization -> batteryHandler
        SnabbitPermission.AccessibilityService -> accessibilityHandler
        else -> error("$permission is not a strict permission")
    }

    private suspend fun requestStrict(handler: StrictPermissionHandler): PermissionStatus {
        if (handler.isGranted()) return PermissionStatus.GRANTED
        // Main-confined: the `pendingStrict` slot + `launcher.launch()` are written here but read/
        // resumed on the main thread by onStrictResult()/detach(). Confining to Main keeps an off-main
        // caller (any dispatcher is allowed) from racing the slot or calling the non-thread-safe
        // ActivityResultLauncher off-main. `.immediate` is a no-op when already on Main.
        return withContext(Dispatchers.Main.immediate) {
            val launcher = settingsLauncher ?: return@withContext PermissionStatus.DENIED // no Activity
            val intent = handler.settingsIntent() ?: return@withContext PermissionStatus.NOT_AVAILABLE
            if (pendingStrict != null) return@withContext PermissionStatus.DENIED // another in progress

            suspendCancellableCoroutine { cont ->
                pendingStrict = cont
                pendingStrictHandler = handler
                cont.invokeOnCancellation {
                    pendingStrict = null
                    pendingStrictHandler = null
                }
                try {
                    launcher.launch(intent)
                } catch (t: Throwable) {
                    pendingStrict = null
                    pendingStrictHandler = null
                    crashReporter.report(t, mapOf("op" to "strict settings launch"))
                    // Launch failure is transient (the permission still exists) → re-askable DENIED.
                    // Guard isActive like the other resume sites: a cancellation racing with this catch
                    // (invokeOnCancellation already cleared pendingStrict) would otherwise throw
                    // "Already resumed".
                    if (cont.isActive) cont.resume(PermissionStatus.DENIED)
                }
            }
        }
    }

    private fun onStrictSettingsResult() {
        val cont = pendingStrict
        val handler = pendingStrictHandler
        pendingStrict = null
        pendingStrictHandler = null
        if (cont != null && cont.isActive) {
            val granted = try {
                handler?.isGranted() == true
            } catch (t: Throwable) {
                crashReporter.report(t, mapOf("op" to "strict re-check"))
                false
            }
            cont.resume(if (granted) PermissionStatus.GRANTED else PermissionStatus.DENIED)
        }
    }

    private fun markRequested(permission: SnabbitPermission) =
        requestedStore.edit().putBoolean(permission.toString(), true).apply()

    private fun isRequested(permission: SnabbitPermission): Boolean =
        requestedStore.getBoolean(permission.toString(), false)

    private inline fun safe(label: String, block: () -> PermissionStatus): PermissionStatus = try {
        block()
    } catch (c: CancellationException) {
        throw c // propagate coroutine cancellation; don't convert it to a status or log it
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to label))
        // Unexpected failure → re-askable DENIED, not the permanent NOT_AVAILABLE (which would
        // make callers stop asking). Genuine unavailability is returned before this catch.
        PermissionStatus.DENIED
    }
}
