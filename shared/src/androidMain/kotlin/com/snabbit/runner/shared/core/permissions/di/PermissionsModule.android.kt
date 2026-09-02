package com.snabbit.runner.shared.core.permissions.di

import com.snabbit.runner.shared.core.permissions.ActivityAttachable
import com.snabbit.runner.shared.core.permissions.AndroidPermissionManager
import com.snabbit.runner.shared.core.permissions.AndroidPermissionObserver
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionObserver
import dev.brewkits.grant.GrantFactory
import dev.brewkits.grant.GrantManager
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.Module
import org.koin.core.module.dsl.bind
import org.koin.core.module.dsl.binds
import org.koin.core.module.dsl.singleOf
import org.koin.dsl.module

/**
 * Android wiring. [GrantManager] is built via Grant's [GrantFactory] from the Koin Android context.
 * One [AndroidPermissionManager] instance backs both [PermissionManager] and [ActivityAttachable]
 * (the host Activity attaches its launchers + Grant's Activity ref through the latter). Constructor
 * dependencies (`Context` via `androidContext()`, [GrantManager], `CrashReporter` from
 * `platformModule`) are resolved by type through the constructor-reference DSL.
 */
actual fun permissionsModule(): Module = module {
    single<GrantManager> { GrantFactory.create(androidContext()) }

    // One instance, exposed under both PermissionManager and ActivityAttachable.
    singleOf(::AndroidPermissionManager) { binds(listOf(PermissionManager::class, ActivityAttachable::class)) }

    singleOf(::AndroidPermissionObserver) { bind<PermissionObserver>() }
}
