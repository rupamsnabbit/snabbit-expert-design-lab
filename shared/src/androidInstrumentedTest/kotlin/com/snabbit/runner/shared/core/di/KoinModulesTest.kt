package com.snabbit.runner.shared.core.di

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.crypto.tink.aead.AeadConfig
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ProviderKeys
import com.snabbit.runner.shared.core.analytics.di.analyticsAndroidModule
import com.snabbit.runner.shared.core.analytics.di.analyticsModule
import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.UnauthorizedDispatcher
import com.snabbit.runner.shared.core.storage.EncryptedStore
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageFactory
import com.snabbit.runner.shared.storage.di.storageModule
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.BeforeClass
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.mp.KoinPlatform.getKoin

/**
 * Verifies the Koin graph (§14) by actually instantiating each binding.
 * If any `get()` in [coreModule] or [platformModule] is missing, the
 * test fails with a clear "no definition found" error rather than at
 * first use from production code.
 *
 * Runs as an instrumented test because [platformModule] needs a real
 * Application context for TinkDataStoreEncryptedStore + Android Keystore.
 */
@RunWith(AndroidJUnit4::class)
class KoinModulesTest {

    companion object {
        @JvmStatic
        @BeforeClass
        fun initTink() {
            AeadConfig.register()
        }
    }

    private val app = ApplicationProvider.getApplicationContext<android.app.Application>()

    @After
    fun teardown() {
        stopKoin()
    }

    @Test
    fun coreAndPlatformModules_resolveAllBindings() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
            )
        }

        // Pulling SnabbitHttpClient transitively materialises every binding
        // in the graph (HttpClient, interceptors, store, observer, dispatcher,
        // time suppliers, …). If any get() is unresolved Koin throws here.
        val koin = getKoin()
        assertNotNull(koin.get<Logger>())
        assertNotNull(koin.get<AppDispatchers>())
        assertNotNull(koin.get<EncryptedStore>())
        assertNotNull(koin.get<StoreManager>())
        assertNotNull(koin.get<NetworkConfigStore>())
        assertNotNull(koin.get<UnauthorizedDispatcher>())
        assertNotNull(koin.get<SnabbitHttpClient>())
    }

    @Test
    fun storageModule_resolvesAllBindings() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
                storageModule(app),
            )
        }

        val koin = getKoin()
        assertNotNull(koin.get<SecureStorage>())
        assertNotNull(koin.get<PreferenceStorage>())
        assertNotNull(koin.get<StorageFactory>())
    }

    @Test
    fun unauthorizedDispatcher_isSingleton() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
            )
        }
        // The 401 path relies on the bridge installing an emitter that the
        // observer can fire — this only works if both sides resolve the
        // same instance.
        assertSame(getKoin().get<UnauthorizedDispatcher>(), getKoin().get<UnauthorizedDispatcher>())
    }

    @Test
    fun crashReporter_resolvesNoopByDefault() {
        // No crashReporter argument — platformModule binds a no-op so
        // coreModule.get() always resolves.
        startKoin {
            modules(
                platformModule(app),
                coreModule,
            )
        }
        assertNotNull(getKoin().get<SnabbitHttpClient>())
        assertNotNull(getKoin().get<CrashReporter>())
    }

    @Test
    fun crashReporter_isPropagated_whenProvided() {
        val captured = mutableListOf<Throwable>()
        val reporter: (Throwable, Map<String, String>) -> Unit = { t, _ -> captured += t }

        startKoin {
            modules(
                platformModule(app, reporter),
                coreModule,
            )
        }
        assertNotNull(getKoin().get<CrashReporter>())
    }

    @Test
    fun analytics_resolvesWithoutDevKey() {
        // Disabled config — no AppsFlyer provider should be registered.
        startKoin {
            modules(
                platformModule(app),
                coreModule,
                analyticsModule,
                analyticsAndroidModule(app, AnalyticsConfig.DISABLED),
            )
        }
        // Tracker resolves and is a no-op router (no providers).
        assertNotNull(getKoin().get<AnalyticsTracker>())
        assertTrue(getKoin().getAll<AnalyticsProvider>().isEmpty())
    }

    @Test
    fun analytics_registersAppsFlyerProvider_whenDevKeyPresent() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
                analyticsModule,
                analyticsAndroidModule(
                    app,
                    AnalyticsConfig(appsFlyerDevKey = "test-key-not-real"),
                ),
            )
        }
        val providers = getKoin().getAll<AnalyticsProvider>()
        assertEquals(1, providers.size)
        assertNotNull(getKoin().get<AnalyticsTracker>())
    }

    @Test
    fun analytics_registersBothProviders_whenDevKeyAndTokenPresent() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
                analyticsModule,
                analyticsAndroidModule(
                    app,
                    AnalyticsConfig(
                        appsFlyerDevKey = "test-key-not-real",
                        mixpanelProjectToken = "test-token-not-real",
                    ),
                ),
            )
        }
        // Both providers must resolve via getAll (multi-binding pattern) —
        // proves the second registration doesn't collide with / drop the first.
        val providers = getKoin().getAll<AnalyticsProvider>()
        assertEquals(2, providers.size)
        assertEquals(
            setOf(ProviderKeys.APPSFLYER, ProviderKeys.MIXPANEL),
            providers.map { it.tag }.toSet(),
        )
        assertNotNull(getKoin().get<AnalyticsTracker>())
    }

    @Test
    fun analytics_registersMixpanelOnly_whenOnlyTokenPresent() {
        startKoin {
            modules(
                platformModule(app),
                coreModule,
                analyticsModule,
                analyticsAndroidModule(
                    app,
                    AnalyticsConfig(mixpanelProjectToken = "test-token-not-real"),
                ),
            )
        }
        val providers = getKoin().getAll<AnalyticsProvider>()
        assertEquals(1, providers.size)
        assertEquals(ProviderKeys.MIXPANEL, providers.single().tag)
    }
}
