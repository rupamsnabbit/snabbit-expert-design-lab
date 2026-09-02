package com.snabbit.runner.shared.core.analytics

import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.bind
import org.koin.dsl.module
import org.koin.mp.KoinPlatform.getKoin
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Guards the Koin multi-binding pattern used by `analyticsAndroidModule`:
 * two distinct concrete provider types, each bound by its concrete type
 * with a secondary `bind AnalyticsProvider::class`, must BOTH be returned
 * by `getAll<AnalyticsProvider>()`. (Two `single<AnalyticsProvider>`
 * definitions would instead collide on the same key.) Runs on the JVM so
 * it verifies the pattern without the emulator-only KoinModulesTest.
 */
class AnalyticsKoinWiringTest {

    private class SecondaryFakeProvider(override val tag: String) : AnalyticsProvider {
        override suspend fun start() {}
        override fun track(name: String, props: Map<String, Any>) {}
        override fun identify(userId: String?) {}
        override fun reset() {}
    }

    @AfterTest
    fun teardown() = stopKoin()

    @Test
    fun getAll_returnsEveryProviderBoundViaBind() {
        startKoin {
            modules(
                module {
                    single { FakeAnalyticsProvider("AppsFlyer") } bind AnalyticsProvider::class
                    single { SecondaryFakeProvider("Mixpanel") } bind AnalyticsProvider::class
                },
            )
        }

        val providers = getKoin().getAll<AnalyticsProvider>()

        assertEquals(2, providers.size)
        assertEquals(setOf("AppsFlyer", "Mixpanel"), providers.map { it.tag }.toSet())
    }
}
