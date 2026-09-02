package com.snabbit.runner.debug

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * DEBUG-only Flutter bridge for the native Chucker button ↔ chucker_flutter. Owns the MethodChannel
 * and ties its lifecycle to the FlutterEngine (attach/detach) — matching the kmp_bridge plugin
 * convention, so the handler is cleared on engine detach (no stale channel).
 *  - native → Dart: [openFlutterInspector] asks Dart to show chucker_flutter.
 *  - Dart → native: "flutterInspectorClosed" → [ChuckerDebug.onInspectorClosed] re-shows the NET
 *    button (which is hidden while the inspector route is open).
 */
internal class ChuckerBridgePlugin : FlutterPlugin {

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            active = it
            it.setMethodCallHandler(::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        if (active === channel) active = null
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "flutterInspectorClosed") {
            ChuckerDebug.onInspectorClosed()
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.snabbit.runner/chucker_debug"

        // Channel of the currently-attached engine (null while detached).
        @Volatile
        private var active: MethodChannel? = null

        /** Ask Dart to open chucker_flutter. No-op if no FlutterEngine is attached. */
        fun openFlutterInspector() {
            active?.invokeMethod("showFlutterInspector", null)
        }
    }
}
