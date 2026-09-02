package com.snabbit.runner.shared.core.analytics.providers

import com.snabbit.runner.shared.core.analytics.ProviderKeys
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class MixpanelProviderContractTest {

    private fun provider(api: FakeMixpanelApi = FakeMixpanelApi()) =
        MixpanelProvider(api) to api

    @Test
    fun tag_isMixpanelKey() {
        val (p, _) = provider()
        assertEquals(ProviderKeys.MIXPANEL, p.tag)
    }

    @Test
    fun start_initialisesTheApi() = runTest {
        val (p, api) = provider()

        p.start()

        assertEquals(listOf(FakeMixpanelApi.Call.Initialize), api.calls)
    }

    @Test
    fun track_forwardsNameAndProps() {
        val (p, api) = provider()

        p.track("job_started", mapOf("job_id" to "42"))

        assertEquals(
            listOf(FakeMixpanelApi.Call.Track("job_started", mapOf("job_id" to "42"))),
            api.calls,
        )
    }

    @Test
    fun identify_nonNull_forwardsDistinctId() {
        val (p, api) = provider()

        p.identify("expert-42")

        assertEquals(listOf(FakeMixpanelApi.Call.Identify("expert-42")), api.calls)
    }

    @Test
    fun identify_null_isNoOp() {
        val (p, api) = provider()

        p.identify(null)

        // Mixpanel has no "un-identify"; null must not reach the SDK.
        assertTrue(api.calls.isEmpty())
    }

    @Test
    fun reset_forwards() {
        val (p, api) = provider()

        p.reset()

        assertEquals(listOf(FakeMixpanelApi.Call.Reset), api.calls)
    }

    @Test
    fun setUserProperty_forwardsKeyAndValue() {
        val (p, api) = provider()

        p.setUserProperty("city", "Mumbai")

        assertEquals(
            listOf(FakeMixpanelApi.Call.SetUserProperty("city", "Mumbai")),
            api.calls,
        )
    }

    @Test
    fun setUserProperty_landsAfterIdentify_whenCalledInThatOrder() {
        // §5.8 — people.set must target the identified distinct_id, so
        // identify must reach the SDK before setUserProperty.
        val (p, api) = provider()

        p.identify("expert-42")
        p.setUserProperty("city", "Mumbai")

        assertEquals(
            listOf(
                FakeMixpanelApi.Call.Identify("expert-42"),
                FakeMixpanelApi.Call.SetUserProperty("city", "Mumbai"),
            ),
            api.calls,
        )
    }

    @Test
    fun setUserProperties_forwardsMapAsSinglePeopleSet() {
        val (p, api) = provider()

        p.setUserProperties(mapOf("city" to "Mumbai", "tier" to 2L))

        assertEquals(
            listOf(
                FakeMixpanelApi.Call.SetUserProperties(
                    mapOf("city" to "Mumbai", "tier" to 2L),
                ),
            ),
            api.calls,
        )
    }
}
