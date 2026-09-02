package com.snabbit.runner.shared.core.analytics.di

import android.app.Application
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.providers.AndroidCleverTapApi
import com.snabbit.runner.shared.core.analytics.providers.AndroidMixpanelApi
import com.snabbit.runner.shared.core.analytics.providers.AppsFlyerAndroidProvider
import com.snabbit.runner.shared.core.analytics.providers.CleverTapProvider
import com.snabbit.runner.shared.core.analytics.providers.MixpanelProvider
import org.koin.dsl.bind
import com.snabbit.runner.shared.core.deeplink.DeeplinkDispatcher
import org.koin.dsl.module

/**
 * Android-side analytics bindings. Factory function — needs [app] +
 * [config] at module-construction time. [app] is captured by closure
 * (same pattern as [com.snabbit.runner.shared.core.di.platformModule]),
 * so Activity/Service contexts can't accidentally leak in.
 *
 * **Provider registration is conditional on credential presence.** A
 * blank AppsFlyer dev key / Mixpanel token → that provider is not
 * registered → it is simply absent from `getAll<AnalyticsProvider>()`,
 * and any route pointing at it is a harmless no-op. With no providers at
 * all the tracker is a no-op router. This is the dev / unit-test path; no
 * extra "disabled" flag needed. See LLD §4.2 / §5.6.
 *
 * Each provider is bound by its concrete type with a secondary
 * `bind AnalyticsProvider::class`, so multiple providers can coexist and
 * all be returned by `getAll<AnalyticsProvider>()` (two
 * `single<AnalyticsProvider>` definitions would collide on the same key).
 *
 * `AnalyticsConfig` itself is bound so downstream code (and the tracker,
 * via `analyticsModule`) can resolve `debugLogging` + `routes`.
 */
fun analyticsAndroidModule(app: Application, config: AnalyticsConfig) = module {
    single { config }

    if (config.isAppsFlyerEnabled) {
        single {
            AppsFlyerAndroidProvider(
                appContext = app.applicationContext,
                // !!: isAppsFlyerEnabled is the guard.
                devKey = config.appsFlyerDevKey!!,
                debugLogging = config.debugLogging,
                logger = get<Logger>(),
                crashReporter = get<CrashReporter>(),
                deeplinkDispatcher = get<DeeplinkDispatcher>(),
            )
        } bind AnalyticsProvider::class
    }

    if (config.isMixpanelEnabled) {
        single {
            MixpanelProvider(
                api = AndroidMixpanelApi(
                    appContext = app.applicationContext,
                    // !!: isMixpanelEnabled is the guard.
                    token = config.mixpanelProjectToken!!,
                ),
            )
        } bind AnalyticsProvider::class
    }

    if (config.cleverTapEnabled) {
        single {
            CleverTapProvider(AndroidCleverTapApi(app.applicationContext))
        } bind AnalyticsProvider::class
    }
}
