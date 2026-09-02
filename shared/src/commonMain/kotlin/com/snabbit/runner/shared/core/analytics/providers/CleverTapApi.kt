package com.snabbit.runner.shared.core.analytics.providers

/**
 * Seam over the native CleverTap SDK so [CleverTapProvider] is testable
 * without the SDK on the test classpath. Real impl: `AndroidCleverTapApi`
 * (androidMain). Push methods are added when push migrates (PR B).
 */
internal interface CleverTapApi {
    fun recordEvent(name: String, props: Map<String, Any>)
    fun onUserLogin(profile: Map<String, Any?>)
}
