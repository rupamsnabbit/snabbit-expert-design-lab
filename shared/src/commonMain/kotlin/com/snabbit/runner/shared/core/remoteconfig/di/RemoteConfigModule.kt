package com.snabbit.runner.shared.core.remoteconfig.di

import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigStore
import org.koin.dsl.module

/**
 * Binds the RC bridge as a process singleton, exposed two ways:
 *  - concrete [RemoteConfigStore] — resolved by the `:app` `RemoteConfigBridgePlugin`
 *    to PUSH flags Flutter sends over the Pigeon bridge.
 *  - [RemoteConfigGateway] (read-only) — resolved by features to READ flags.
 * Same instance, so a push is immediately visible to every reader.
 */
val remoteConfigModule = module {
    single { RemoteConfigStore() }
    single<RemoteConfigGateway> { get<RemoteConfigStore>() }
}
