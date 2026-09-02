package com.snabbit.runner.compose_overlay.plugin

import android.app.Activity
import android.content.Context
import com.snabbit.runner.compose_overlay.data.OverlayChannelManager
import com.snabbit.runner.compose_overlay.service.OverlayService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Flutter plugin entry point for the native Compose overlay system.
 *
 * Registered in [MainActivity] and wired automatically by the Flutter engine.
 * On attach, creates an [OverlayChannelManager] (MethodChannel + EventChannel)
 * and stores a static reference on [OverlayService] so the service can wire
 * ViewModel callbacks when it starts.
 *
 * On detach, disposes the channel manager and clears the reference.
 */
class ComposeOverlayPlugin : FlutterPlugin, ActivityAware {

    private var channelManager: OverlayChannelManager? = null
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channelManager = OverlayChannelManager(
            messenger = binding.binaryMessenger,
            context = binding.applicationContext,
        )
        // Set static reference so OverlayService can wire ViewModel callbacks when it starts
        OverlayService.channelManager = channelManager
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channelManager?.dispose()
        channelManager = null
        OverlayService.channelManager = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    companion object {
        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val plugin = ComposeOverlayPlugin()
            flutterEngine.plugins.add(plugin)
        }
    }
}
