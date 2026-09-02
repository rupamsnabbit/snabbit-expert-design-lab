package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * KMP → Flutter one-shot actions the native Profile can't run itself because they
 * touch Flutter-only services/state: "silentNotifications" (stop notifications +
 * audio + persist the 'stopped' state) and "panCardUnavailable" (set the profile
 * provider's transient `panCardUnavailable` flag when the runner taps Create-ePAN).
 * Both are handled Dart-side by `ProfileActionsChannel`.
 *
 * Holds its channel **statically** (like `LanguagePlugin`/`DeeplinkPlugin`) so a
 * Compose screen can invoke it without an engine reference. `:app` invokes;
 * Flutter handles. Registered in `MainActivity.configureFlutterEngine`.
 */
class ProfileActionsPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
    }

    companion object {
        private const val CHANNEL = "com.snabbit.runner/profile_actions"
        private var channel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        /**
         * Fire-and-forget: run the Flutter "silent notifications" action. No-op if
         * the engine isn't attached (KMP disabled for this process). Must be called
         * on the main thread (Compose click handlers already are).
         */
        fun silentNotifications() {
            channel?.invokeMethod("silentNotifications", null)
        }

        /**
         * Fire-and-forget: set the Flutter profile's transient `panCardUnavailable`
         * flag (runner tapped Create-ePAN). Mirrors the drawer sheet, which sets it
         * before opening the ePAN portal. No-op if the engine isn't attached.
         */
        fun panCardUnavailable() {
            channel?.invokeMethod("panCardUnavailable", null)
        }

        /**
         * Fire-and-forget: stop the Flutter-owned alert alarm because a Compose CTA
         * acknowledged the alert (AWOL "I understand", delayed check-in "Check In").
         * The Android end of the `core/alarm` `AlarmController` seam; Dart handles it
         * in `AlarmSilencer.silence`.
         *
         * Narrower than [silentNotifications] on purpose — it silences the alarm only,
         * leaving posted notifications and the `'stopped'` marker alone.
         *
         * Unlike the two above, this posts to the main looper rather than requiring the
         * caller to be on it: acknowledgement reaches here from ViewModels, which are
         * free to run on any dispatcher, and `invokeMethod` requires the platform
         * thread (same reason as `RunnerStatePlugin`'s refresh bridge). No-op if the
         * engine isn't attached.
         */
        fun silenceAlarm() {
            mainHandler.post { channel?.invokeMethod("silenceAlarm", null) }
        }
    }
}
