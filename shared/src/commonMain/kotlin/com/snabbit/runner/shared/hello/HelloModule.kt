package com.snabbit.runner.shared.hello

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.defaultAppDispatchers
import com.snabbit.runner.shared.core.defaultLogger

/**
 * Hello module — the canonical exemplar for new KMP modules.
 *
 * New modules (network, location, camera, etc.) follow this shape:
 *
 *   1. Public interface in this file ([HelloModule]) — the API callers see.
 *   2. `internal` implementation in [HelloModuleImpl] (commonMain) — pure
 *      Kotlin, no platform APIs, deps injected via constructor.
 *   3. `expect fun` factory ([helloModule]) declared here, with `actual`
 *      impls in androidMain/iosMain — this is where platform APIs
 *      (android.os.Build, UIDevice) are touched. commonMain stays pure.
 *
 * Tests instantiate [HelloModuleImpl] directly with fakes; they do not call
 * the expect/actual factory.
 *
 * If a module needs no platform APIs, the factory can be a plain top-level
 * function in commonMain instead of expect/actual.
 *
 * Add a sealed `<Module>Error` class only when callers will `when`-branch on
 * different failure modes (e.g., NetworkError.Timeout vs NetworkError.Http).
 */
interface HelloModule {
    suspend fun getHelloMessage(): String
}

/** Builds a [HelloModule] wired with the platform's OS label. */
expect fun helloModule(
    logger: Logger = defaultLogger(),
    dispatchers: AppDispatchers = defaultAppDispatchers(),
): HelloModule
