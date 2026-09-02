package com.snabbit.runner.remoteconfig.bridge

import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import org.koin.core.context.GlobalContext

/**
 * Pigeon bridge that lets Flutter push Firebase Remote Config **bool** flags
 * into the KMP module. Flutter owns Firebase RC; `:shared` has no RC path, so the
 * flags KMP screens gate on (e.g. `expert_show_earnings`, `expert_is_referrals_v2_enabled`)
 * are mirrored here into the Koin-singleton [RemoteConfigStore].
 *
 * One-directional (Dart → KMP) and stateless, so this is a plain [FlutterPlugin]
 * with no [io.flutter.embedding.engine.plugins.activity.ActivityAware] (unlike the
 * nav bridge — that one needs a host Activity). Registered in
 * `MainActivity.configureFlutterEngine`.
 *
 * Resilient to a fail-open KMP bootstrap: if Koin never started (KMP disabled for
 * this process, see [com.snabbit.runner.shared.core.KmpBootstrap]) the push is a
 * no-op rather than a crash — KMP screens then read their safe defaults.
 */
class RemoteConfigBridgePlugin : FlutterPlugin, RemoteConfigHostApi {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RemoteConfigHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RemoteConfigHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun setBoolFlags(flags: Map<String, Boolean>) {
        val koin = GlobalContext.getOrNull() ?: return
        koin.get<RemoteConfigStore>().setFlags(flags)
    }

    override fun setStringFlags(flags: Map<String, String>) {
        val koin = GlobalContext.getOrNull() ?: return
        koin.get<RemoteConfigStore>().setStringFlags(flags)
    }
}
