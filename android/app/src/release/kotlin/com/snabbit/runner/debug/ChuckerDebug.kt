package com.snabbit.runner.debug

import android.app.Application
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import org.koin.core.module.Module
import org.koin.dsl.module

/**
 * RELEASE source set — no-op twin of the debug [ChuckerDebug]. No Chucker dependency, no interceptor,
 * no button, no bridge: the empty module binds no
 * [com.snabbit.runner.shared.core.network.ApiHttpInterceptors], so the shared engine uses its plain
 * default.
 */
object ChuckerDebug {
    fun networkModule(context: Context): Module = module { }
    fun launchIntent(context: Context): Intent? = null
    fun armFloatingButton(app: Application) = Unit
    fun registerFlutterBridge(engine: FlutterEngine) = Unit
}
