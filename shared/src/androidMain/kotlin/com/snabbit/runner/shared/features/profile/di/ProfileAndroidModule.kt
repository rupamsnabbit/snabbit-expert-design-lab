package com.snabbit.runner.shared.features.profile.di

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.snabbit.runner.shared.features.profile.ExternalUrlOpener
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

/**
 * androidMain Koin wiring for the Profile feature: the [ExternalUrlOpener] impl backed by
 * an `ACTION_VIEW` intent (application context + `NEW_TASK`), matching Flutter's
 * `url_launcher` external-application behaviour. Registered in `KmpBootstrap`.
 */
val profileAndroidModule = module {
    single<ExternalUrlOpener> {
        val context: Context = androidContext()
        ExternalUrlOpener { url ->
            runCatching {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }.isSuccess
        }
    }
}
