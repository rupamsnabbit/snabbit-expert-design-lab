package com.snabbit.runner.shared.core.analytics.di

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import com.snabbit.runner.shared.core.analytics.AnalyticsProvider
import com.snabbit.runner.shared.core.analytics.AnalyticsRouteTable
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.AnalyticsTrackerImpl
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.analytics.ProviderKeys
import com.snabbit.runner.shared.core.analytics.UnroutedEventReporter
import org.koin.dsl.module

/**
 * Platform-free Koin bindings for the analytics module. The tracker reads
 * `getAll<AnalyticsProvider>()`, which the platform module
 * (`analyticsAndroidModule(config)`) populates conditionally based on
 * config (e.g. blank dev key / blank token → that provider is not
 * registered, and routes pointing at it are harmless no-ops).
 *
 * The event router ([AnalyticsRouteTable]) is built here from the
 * code-baked [AnalyticsConfig.routes] data, with `onUnrouted` wired to a
 * logging + sampled crash-reporting [UnroutedEventReporter]. At
 * construction the route config is validated against [ProviderKeys.ALL] so
 * a typo'd key (which union routing would otherwise silently swallow) is
 * surfaced at startup.
 */
val analyticsModule = module {
    single {
        val config = get<AnalyticsConfig>()
        val logger = get<Logger>()
        val crashReporter = get<CrashReporter>()

        val unknownKeys = config.routes.unknownKeys(ProviderKeys.ALL)
        if (unknownKeys.isNotEmpty()) {
            logger.e(
                "AnalyticsModule",
                "Route table references unknown provider keys (check for typos): $unknownKeys",
            )
        }

        val unroutedReporter = UnroutedEventReporter(logger, crashReporter)
        val routes = AnalyticsRouteTable(
            table = config.routes.table,
            default = config.routes.default,
            onUnrouted = unroutedReporter::onUnrouted,
        )

        // Construction owns the impl; the interface binding below resolves to
        // this SAME instance, so KmpBootstrap can call the impl-only
        // bootstrap() lifecycle without a downcast.
        AnalyticsTrackerImpl(
            providers = getAll<AnalyticsProvider>(),
            routes = routes,
            debugLogging = config.debugLogging,
            logger = logger,
            crashReporter = crashReporter,
        )
    }
    single<AnalyticsTracker> { get<AnalyticsTrackerImpl>() }

    // Cross-cutting error-event wrapper (X.3 Errors & Loading), injected by any feature that surfaces a
    // generic error state so `error_screen_load` / `error_screen_cta_click` have one canonical shape.
    single { ErrorAnalytics(get()) }
}
