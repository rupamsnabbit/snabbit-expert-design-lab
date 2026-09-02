package com.snabbit.runner.shared.core.analytics.providers

import android.content.Context
import com.mixpanel.android.mpmetrics.MixpanelAPI
import org.json.JSONObject

/**
 * Real [MixpanelApi] backed by the `com.mixpanel.android` SDK. Thin
 * forwarder — no business logic — so it is the one piece that the
 * commonTest contract tests deliberately do not cover (mirrors how
 * `AppsFlyerAndroidProvider`'s direct SDK calls are exercised only via
 * manual / instrumented verification).
 *
 * The SDK instance is created lazily on first use, so calls that race
 * the [initialize] lifecycle (early Dart events during cold start) trigger
 * `getInstance` themselves rather than being null-dropped. The Mixpanel
 * SDK's own `HandlerThread` queue then buffers until network is ready.
 * `trackAutomaticEvents = false` mirrors the previous `mixpanel_flutter`
 * init in `lib/services/mixpanel_setup.dart`.
 */
internal class AndroidMixpanelApi(
    private val appContext: Context,
    private val token: String,
) : MixpanelApi {

    private val mixpanel: MixpanelAPI by lazy {
        MixpanelAPI.getInstance(appContext, token, false)
    }

    override fun initialize() {
        // SDK is lazy-initialised on first use; touching it here warms it.
        mixpanel
    }

    override fun track(name: String, props: Map<String, Any>) {
        mixpanel.track(name, props.toJsonObject())
    }

    override fun identify(distinctId: String) {
        mixpanel.identify(distinctId)
    }

    override fun reset() {
        mixpanel.reset()
    }

    override fun setUserProperty(key: String, value: Any?) {
        mixpanel.people.set(key, value)
    }

    override fun setUserProperties(props: Map<String, Any>) {
        mixpanel.people.set(props.toJsonObject())
    }

    private fun Map<String, Any>.toJsonObject(): JSONObject {
        val json = JSONObject()
        for ((k, v) in this) {
            // JSONObject.put throws on NaN/±Infinity; drop the key instead of
            // taking down the whole event.
            if (v is Double && !v.isFinite()) continue
            json.put(k, v)
        }
        return json
    }
}
