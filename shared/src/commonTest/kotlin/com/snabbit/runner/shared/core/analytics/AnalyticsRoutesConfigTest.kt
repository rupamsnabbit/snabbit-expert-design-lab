package com.snabbit.runner.shared.core.analytics

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AnalyticsRoutesConfigTest {

    @Test
    fun seed_isStrict_noDefaultSink() {
        assertEquals(emptySet(), AnalyticsRoutesConfig.SEED.default)
    }

    @Test
    fun seed_routesKnownEvents() {
        val t = AnalyticsRoutesConfig.SEED.table
        // a CleverTap-only, a both, and an AppsFlyer event (spot checks)
        assertEquals(setOf(ProviderKeys.CLEVERTAP), t["chat_screen_opened"])
        assertEquals(setOf(ProviderKeys.MIXPANEL, ProviderKeys.CLEVERTAP), t["arrival_screen_load"])
        assertTrue(ProviderKeys.APPSFLYER in (t["app_launched"] ?: emptySet()))
    }

    // Shipped unrouted: SEED.default is empty, so a missing entry resolves to zero destinations and
    // UnroutedEventReporter files a non-fatal per occurrence instead of the event reaching a provider.
    @Test
    fun seed_routesTheDeferredRecordingMarker() {
        assertTrue(AnalyticsRoutesConfig.SEED.table["expert_shield_restore_recording_deferred"].isNullOrEmpty().not())
    }

    @Test
    fun seed_referencesNoUnknownProviderKeys() {
        assertTrue(AnalyticsRoutesConfig.SEED.unknownKeys(ProviderKeys.ALL).isEmpty())
    }
}
