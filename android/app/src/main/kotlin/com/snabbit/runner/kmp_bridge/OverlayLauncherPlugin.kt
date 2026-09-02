package com.snabbit.runner.kmp_bridge

import com.snabbit.runner.awol.AwolOverlaySpec
import com.snabbit.runner.overlayhost.OverlayLauncher
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.context.GlobalContext

/**
 * Config bridge for the generic [OverlayLauncher] — the AWOL analogue of the
 * job launcher's config channel, but deliberately **not** [io.flutter.embedding.engine.plugins.activity.ActivityAware]:
 * the launcher itself is Application-scoped ([OverlayLauncher], armed in
 * `SnabbitRunnerApplication`) so the killed-state overlay path works with no
 * Activity ever attached. The only things that cross from Dart are the Remote
 * Config values (`AwolOverlayChannel.setEnabled` — Firebase RC isn't on the
 * native compile classpath): the overlay + home-card kill-switches plus the fallback map-image URLs
 * (the legacy `awol_enter_hotspot` / `awol_back_in_hotspot` assets), pushed at
 * provider init AND on RC live-updates. Until pushed, everything stays OFF
 * (ships dark, TR-07) and the image slot keeps its placeholder.
 *
 * The flag lands twice, deliberately: the launcher's native gate (whether to
 * start a window at all) and [AwolViewModel.setFlags] (the §9 routing input),
 * so the launch decision and the surface routing can never disagree.
 */
class OverlayLauncherPlugin : FlutterPlugin {

    private var configChannel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        configChannel = MethodChannel(binding.binaryMessenger, CONFIG_CHANNEL).apply {
            setMethodCallHandler(::handleConfig)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        configChannel?.setMethodCallHandler(null)
        configChannel = null
    }

    private fun handleConfig(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setOverlayEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                OverlayLauncher.instance?.setEnabled(AwolOverlaySpec.KEY, enabled)
                // Push the flags into the coordinator's routing + image
                // resolution (guarded: if the KMP bootstrap failed there is
                // no ViewModel to update). Blank URL → null → the image slot
                // keeps its placeholder.
                GlobalContext.getOrNull()?.get<AwolViewModel>()
                    ?.setFlags(
                        AwolFlags(
                            overlayEnabled = enabled,
                            homeCardEnabled = call.argument<Boolean>("homeCardEnabled") ?: false,
                            fallbackBreachImageUrl = call.argument<String>("breachImageUrl")
                                ?.takeIf { it.isNotBlank() },
                            fallbackReEnteredImageUrl = call.argument<String>("reEnteredImageUrl")
                                ?.takeIf { it.isNotBlank() },
                        ),
                    )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CONFIG_CHANNEL = "com.snabbit.runner/awol_overlay"
    }
}
