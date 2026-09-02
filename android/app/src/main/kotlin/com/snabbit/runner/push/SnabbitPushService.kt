package com.snabbit.runner.push

import android.os.Bundle
import android.util.Log
import com.clevertap.android.sdk.CleverTapAPI
import com.google.firebase.messaging.RemoteMessage
import com.snabbit.runner.AppForegroundTracker
import com.snabbit.runner.job.JobScreenExtras
import com.snabbit.runner.job.overlay.NewJobOverlaySpec
import com.snabbit.runner.overlayhost.ComposeOverlayHost
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * FCM receiver subclass that fires CleverTap's "push viewed" impression
 * natively, then delegates to [FlutterFirebaseMessagingService] so the
 * Dart background handler still runs and renders the notification.
 *
 * Solves the MissingPluginException for backgrounded pushes: the Flutter
 * background isolate has no MethodChannel, so impression tracking can't
 * round-trip through Dart → Android. Native side does it directly.
 *
 * ponytail: lives in :app (not :shared) because the parent class is
 * Flutter-coupled. When Flutter is removed, swap the parent to
 * [com.google.firebase.messaging.FirebaseMessagingService] and own the
 * render path here (currently in main.dart's firebaseMessagingBackground-
 * Handler). The CleverTap-impression line stays the same.
 */
class SnabbitPushService : FlutterFirebaseMessagingService(), KoinComponent {

    // Process-wide KMP state store (Koin single). On a force-killed FCM wake the
    // Application → KmpBootstrap has already started Koin before this service runs,
    // so this resolves; lazy so a fail-open bootstrap can't crash service creation.
    private val runnerStateStore: RunnerStateStore by inject()

    // RC gateway (mirror-backed, sync). On a cold FCM wake the mirror may be empty → getBool returns the
    // default (false), which correctly suppresses the draw-over-other-apps overlay until enabled (§8).
    private val remoteConfig: RemoteConfigGateway by inject()

    override fun onMessageReceived(message: RemoteMessage) {
        // Diagnostic: whether this fires at all when backgrounded/killed tells us if the push is a
        // data-bearing message (fires) vs a notification hybrid the OS routes to the tray (never
        // fires). `hasNotification=true` confirms the hybrid that blocks the terminated overlay.
        Log.i(
            TAG,
            "onMessageReceived keys=${message.data.keys} name=${message.data["name"]} " +
                "hasNotification=${message.notification != null} fg=${AppForegroundTracker.isForeground}",
        )
        val extras = message.toBundle()
        val info = CleverTapAPI.getNotificationInfo(extras)
        if (info.fromCleverTap) {
            CleverTapAPI.getDefaultInstance(applicationContext)
                ?.pushNotificationViewedEvent(extras)
        }

        // Phase B: a backend new-job push (HIGH-priority *data* message, not a
        // CleverTap push) wakes us even when force-killed. Seed the job envelope into
        // the KMP store and — only when the app isn't foreground — raise the draw-over
        // overlay natively (the Flutter isolate has no UI cold, so it can't). Purely
        // additive: never consumes the message; always falls through to super so the
        // Dart cache/notification path keeps running.
        if (message.data["name"] == NEW_JOB_ALLOCATION) {
            try {
                // Seed unconditionally — it feeds BOTH surfaces off the one store.
                // Foreground, this is what drives the in-app job UI (JobScreenLauncher-
                // Plugin fronts NavigationHostActivity → ActiveJobOverlay); backgrounded
                // or killed, it primes the draw-over overlay started below.
                // Seed unconditionally — it feeds BOTH surfaces off the one store. Gate the
                // draw-over start on whether the seed actually produced a RUNNER_NEW_JOB, so a
                // payload missing both `envelope` and `job_id` can't raise a card-less dimmed
                // scrim that never dismisses.
                val seeded = seedNewJobState(message.data)
                Log.i(
                    TAG,
                    "NEW_JOB_ALLOCATION seeded=$seeded fg=${AppForegroundTracker.isForeground} " +
                        "hasEnvelope=${message.data["envelope"] != null} jobId=${message.data["job_id"]}",
                )
                // FG-guard: only draw over other apps when we're NOT foreground. In the
                // foreground the seed above already surfaces the job in-app, so drawing over as
                // well would stack the overlay on the live app and show a duplicate card.
                // Backgrounded/killed, this is the only way the runner sees the job. Also gated on the
                // `expert_show_new_job_overlay_on_other_apps` RC flag (default false, ECPO-860 #8) — a cold-wake
                // empty mirror reads false, so the overlay stays off until the flag is enabled.
                if (seeded &&
                    !AppForegroundTracker.isForeground &&
                    remoteConfig.getBool(NewJobOverlaySpec.RC_SHOW_ON_OTHER_APPS, false)
                ) {
                    Log.i(TAG, "Starting new-job overlay via ComposeOverlayHost from FCM (terminated/background)")
                    ComposeOverlayHost.start(this, NewJobOverlaySpec.KEY) {
                        message.data["service_id"]?.toIntOrNull()
                            ?.let { putExtra(JobScreenExtras.EXTRA_SERVICE_ID, it) }
                    }
                }
            } catch (e: Exception) {
                // Background FGS start can still be refused (push not HIGH-priority
                // on API 31+/35) or Koin may have fail-opened. The FCM notification
                // is the fallback — NotificationService routes a NEW_JOB_ALLOCATION tap.
                Log.e(TAG, "New-job overlay start blocked/failed; notification fallback", e)
            }
        } else if (!AppForegroundTracker.isForeground) {
            // Any other backend wake/sync push (observed: data-only, name=null) signals state MAY have
            // changed while we're backgrounded. Ask Dart to re-fetch current_state NOW rather than waiting
            // up to ~60s for the next RunnerRtDataProvider poll, so a freshly-assigned job surfaces the
            // draw-over overlay promptly (JobScreenLauncher fires off the refreshed store state). The bridge
            // posts to the main thread itself (RunnerStatePlugin.bind), so this is safe from the FCM
            // background thread; it no-ops when the bridge is unbound (terminated cold wake — that path is
            // the NEW_JOB_ALLOCATION seed above, not this reverse-refresh).
            try {
                Log.i(TAG, "wake push name=${message.data["name"]} bg → requestRefresh (immediate re-sync)")
                runnerStateStore.requestRefresh()
            } catch (e: Exception) {
                Log.e(TAG, "requestRefresh on wake push failed", e)
            }
        }

        super.onMessageReceived(message)
    }

    // FCM rotates tokens while the process is dead too (reinstall, data clear,
    // Play Services events). Dart's `messaging.onTokenRefresh` only fires while
    // the isolate is alive, so we forward here natively — mirrors what the
    // dropped CleverTap `FcmMessageListenerService` used to do.
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        CleverTapAPI.getDefaultInstance(applicationContext)
            ?.pushFcmRegistrationId(token, true)
    }

    /**
     * Seed [RunnerStateStore] so the overlay's `JobViewModel` has a `RUNNER_NEW_JOB`
     * to render on a cold wake (the store is otherwise empty until the Flutter-bound
     * `RunnerStatePlugin` attaches). Prefers a full envelope in `data["envelope"]`;
     * else synthesises a minimal one from `data["job_id"]` (required for accept/deny).
     * [RunnerStateStore.pushState] never throws — a malformed payload is logged there.
     */
    private fun seedNewJobState(data: Map<String, String>): Boolean {
        val envelope = data["envelope"]?.takeIf { it.isNotBlank() }
            ?: data["job_id"]?.toLongOrNull()?.let { jobId ->
                """{"widget_name":"RUNNER_NEW_JOB","widget_data":{"job_id":$jobId}}"""
            }
        if (envelope != null) runnerStateStore.pushState(envelope)
        return envelope != null
    }

    private fun RemoteMessage.toBundle(): Bundle = Bundle().apply {
        data.forEach { (k, v) -> putString(k, v) }
    }

    private companion object {
        const val NEW_JOB_ALLOCATION = "NEW_JOB_ALLOCATION"
        const val TAG = "SnabbitPushService"
    }
}
