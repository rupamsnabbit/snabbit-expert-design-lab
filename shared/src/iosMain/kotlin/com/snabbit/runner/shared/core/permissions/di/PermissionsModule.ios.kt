package com.snabbit.runner.shared.core.permissions.di

import com.snabbit.runner.shared.core.permissions.IosPermissionManager
import com.snabbit.runner.shared.core.permissions.IosPermissionObserver
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionObserver
import org.koin.core.module.Module
import org.koin.core.module.dsl.bind
import org.koin.core.module.dsl.singleOf
import org.koin.dsl.module

/**
 * iOS wiring — stubs only (Android-first migration). Real Grant-iOS wiring is deferred; the
 * [com.snabbit.runner.shared.core.permissions.internal.GrantRuntimeDelegate] is already common, so
 * turning iOS on later is mostly building a GrantManager here. There is no `ActivityAttachable` on
 * iOS (an Android concept).
 */
actual fun permissionsModule(): Module = module {
    singleOf(::IosPermissionManager) { bind<PermissionManager>() }
    singleOf(::IosPermissionObserver) { bind<PermissionObserver>() }
}
