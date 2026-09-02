package com.snabbit.runner.shared.features.kavach.shared.di

import com.safetykavach.shield.recording.ClipKeyWrapperPort
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldKeyWrapper
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldSyncScheduler
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.WorkManagerShieldSyncScheduler
import org.koin.android.ext.koin.androidContext
import org.koin.dsl.module

/**
 * Android-only Kavach bindings — the pieces that need a Context or the plugin's host seams.
 * Loaded after [safetyModule] in KmpBootstrap (mirrors `profileAndroidModule`).
 */
val safetyAndroidModule = module {
    single<ShieldSyncScheduler> { WorkManagerShieldSyncScheduler(androidContext()) }

    // The plugin asks us to wrap each clip's AES key for its sidecar; the public key and the RSA
    // algorithm stay here, so the plugin never learns either.
    single<ClipKeyWrapperPort> {
        val wrapper = get<ShieldKeyWrapper>()
        val crashReporter = get<CrashReporter>()
        object : ClipKeyWrapperPort {
            // Report, don't just swallow: a wrap failure (missing/rotated public key) means the clip goes
            // out with no sidecar and is unrecoverable if the process then dies — which surfaces a session
            // later as clip_sidecar_missing with no cause. Still returns null so the clip emits regardless.
            override suspend fun wrap(aesKeyBase64: String): String? =
                runCatching { wrapper.wrapAesKey(aesKeyBase64) }
                    .onFailure { crashReporter.report(it, mapOf("op" to "shield_clip_key_wrap")) }
                    .getOrNull()
        }
    }
}
