package com.snabbit.runner.shared.core.navigation.di

import com.snabbit.runner.shared.core.navigation.DeeplinkMapping
import com.snabbit.runner.shared.core.navigation.Destination
import com.snabbit.runner.shared.core.navigation.DestinationFactory
import org.koin.core.module.Module
import org.koin.core.qualifier.named
import org.koin.dsl.bind

/**
 * One-call commonMain registration of a native destination: binds a [DestinationFactory]
 * (open-by-[key]) and, when [deeplinkValue] is given, a [DeeplinkMapping]. Stays
 * decentralised — every feature calls this in its own Koin module and the host collects
 * them via `getAll`, so adding a destination needs no edit to the controller/registry.
 * Pair with the `nativeScreen<D>(…)` that registers the Compose screen — both now live
 * in commonMain.
 *
 * Each binding is given a **unique [named] qualifier** (derived from [key]/[deeplinkValue]).
 * Without it every `single { DestinationFactory { … } }` shares the same primary type
 * (`DestinationFactory`) and root qualifier, so a second registration would *override* the
 * first and `getAll<DestinationFactory>()` would return only the last one — i.e. only one
 * native destination could ever exist. The qualifier makes each a distinct definition that
 * `getAll` collects (same reason `CoreModule` disambiguates same-typed bindings).
 *
 * ```kotlin
 * nativeDestination<JobDetail>(key = "job_detail", deeplinkValue = "job") { args ->
 *     JobDetail(jobId = args["id"].orEmpty())
 * }
 * ```
 */
fun <D : Destination> Module.nativeDestination(
    key: String,
    deeplinkValue: String? = null,
    build: (args: Map<String, String?>) -> D,
) {
    single(named("nativeDestination:$key")) {
        DestinationFactory { k, args -> if (k == key) build(args) else null }
    } bind DestinationFactory::class

    if (deeplinkValue != null) {
        single(named("nativeDeeplink:$deeplinkValue")) {
            DeeplinkMapping { value, params -> if (value == deeplinkValue) build(params) else null }
        } bind DeeplinkMapping::class
    }
}
