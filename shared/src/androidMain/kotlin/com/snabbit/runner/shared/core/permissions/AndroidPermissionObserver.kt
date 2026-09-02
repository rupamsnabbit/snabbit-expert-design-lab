package com.snabbit.runner.shared.core.permissions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.LocationManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.ChannelResult
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch

/**
 * [PermissionObserver] for Android.
 *
 * Android has no system callback for permission grant/revoke, so [observePermission] re-checks
 * on every app `ON_RESUME` (via [ProcessLifecycleOwner]) plus an initial emission. [observeService]
 * for GPS listens to `PROVIDERS_CHANGED`; CAMERA/MICROPHONE report static hardware presence
 * (their privacy-toggle state isn't app-readable), so those emit once.
 */
internal class AndroidPermissionObserver(
    private val context: Context,
    private val permissionManager: PermissionManager,
    private val crashReporter: CrashReporter,
) : PermissionObserver {

    override fun observePermission(permission: SnabbitPermission): Flow<PermissionStatus> = callbackFlow {
        recordIfDropped(trySend(permissionManager.check(permission)), "permission:$permission")

        val observer = object : DefaultLifecycleObserver {
            override fun onResume(owner: LifecycleOwner) {
                launch { recordIfDropped(trySend(permissionManager.check(permission)), "permission:$permission") }
            }
        }
        val lifecycle = ProcessLifecycleOwner.get().lifecycle
        lifecycle.addObserver(observer)

        awaitClose { lifecycle.removeObserver(observer) }
    }
        // Re-checks fire on every ON_RESUME; only emit when the status actually changed so
        // collectors don't rebuild on every foreground.
        .distinctUntilChanged()
        .flowOn(Dispatchers.Main) // lifecycle observers must be added/removed on the main thread

    override fun observeService(service: ServiceType): Flow<Boolean> = callbackFlow {
        recordIfDropped(trySend(permissionManager.isServiceEnabled(service)), "service:$service")

        if (service == ServiceType.GPS) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, i: Intent?) {
                    recordIfDropped(trySend(permissionManager.isServiceEnabled(service)), "service:$service")
                }
            }
            ContextCompat.registerReceiver(
                context,
                receiver,
                IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            awaitClose { runCatching { context.unregisterReceiver(receiver) } }
        } else {
            // CAMERA/MICROPHONE report static hardware presence (see AndroidServiceChecker) that
            // cannot change at runtime — nothing to observe. The Android 12+ privacy-toggle state
            // is not readable or observable by ordinary apps (it needs the privileged
            // OBSERVE_SENSOR_PRIVACY permission). So the single emission above is the only value;
            // keep the flow open until the collector cancels.
            awaitClose { }
        }
    }.distinctUntilChanged() // GPS re-checks on PROVIDERS_CHANGED can repeat the same value

    // A dropped emission (full 64-deep buffer) can't happen with these low-frequency streams, but
    // if a downstream consumer ever conflates/uses a rendezvous buffer it could silently lose the
    // latest state — record it so it never goes unnoticed.
    private fun recordIfDropped(result: ChannelResult<Unit>, label: String) {
        if (result.isFailure && !result.isClosed) {
            crashReporter.report(
                IllegalStateException("dropped emission (buffer full): $label"),
                mapOf("op" to "observer dropped emission: $label"),
            )
        }
    }
}
