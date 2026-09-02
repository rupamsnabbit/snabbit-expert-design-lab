package com.snabbit.runner.shared.core.analytics.providers

import com.snabbit.runner.shared.core.analytics.ProviderKeys
import kotlin.test.Test
import kotlin.test.assertEquals

class CleverTapProviderContractTest {

    @Test
    fun tag_isCleverTapKey() {
        assertEquals(ProviderKeys.CLEVERTAP, CleverTapProvider(FakeCleverTapApi()).tag)
    }

    @Test
    fun track_forwardsToRecordEvent() {
        val api = FakeCleverTapApi()
        CleverTapProvider(api).track("job_started", mapOf("id" to "1"))
        assertEquals(listOf(FakeCleverTapApi.Call.Record("job_started", mapOf("id" to "1"))), api.calls)
    }

    @Test
    fun onUserLogin_forwards() {
        val api = FakeCleverTapApi()
        CleverTapProvider(api).onUserLogin(mapOf("Identity" to 7))
        assertEquals(listOf(FakeCleverTapApi.Call.Login(mapOf("Identity" to 7))), api.calls)
    }
}
