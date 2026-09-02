package com.snabbit.runner.shared.core.analytics.providers

import android.content.Context
import com.clevertap.android.sdk.CleverTapAPI

/**
 * Real [CleverTapApi] over the native SDK singleton. Thin forwarder —
 * untested at unit level (mirrors AndroidMixpanelApi / AppsFlyer). The SDK
 * auto-inits from the manifest `CLEVERTAP_ACCOUNT_ID`/`TOKEN` meta-data.
 */
internal class AndroidCleverTapApi(
    private val appContext: Context,
) : CleverTapApi {

    private val ct: CleverTapAPI?
        get() = CleverTapAPI.getDefaultInstance(appContext)

    override fun recordEvent(name: String, props: Map<String, Any>) {
        ct?.pushEvent(name, HashMap(props))
    }

    override fun onUserLogin(profile: Map<String, Any?>) {
        ct?.onUserLogin(HashMap(profile))
    }
}
