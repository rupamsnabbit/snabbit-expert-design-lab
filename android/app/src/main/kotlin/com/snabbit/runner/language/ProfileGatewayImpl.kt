package com.snabbit.runner.language

import com.snabbit.runner.kmp_bridge.LanguagePlugin
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.features.language.domain.ProfileGateway
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import kotlin.coroutines.cancellation.CancellationException

/**
 * Channel-backed [ProfileGateway]. Apply-only + stateless (an app singleton) —
 * the runner's *current* language travels as a launch argument to the VM, not
 * through this seam.
 *
 * [applyLanguage] propagates an already-persisted language change to every in-app
 * cache: the KMP [RunnerProfileStore] (so the native Profile / Language screens
 * reflect it immediately, even while the Flutter engine is backgrounded) and the
 * Flutter side (a reliable prefs hand-off + a best-effort live reload). The
 * network persist itself is done by the KMP data source, not here.
 */
class ProfileGatewayImpl(
    private val crashReporter: CrashReporter,
    private val runnerProfileStore: RunnerProfileStore,
) : ProfileGateway {

    override suspend fun applyLanguage(code: String) {
        // KMP-local FIRST: optimistically patch the cached profile so the native
        // Profile / Language screens show the new language immediately. Pure local
        // update (no channel, no network), so it's reliable even when the change
        // happens entirely inside the Compose host with Flutter backgrounded —
        // exactly the case a Dart round-trip can't cover. Corrected by the next
        // authoritative runners/me push (which already carries the new language).
        runnerProfileStore.patchLanguagePreference(code)
        // Reliable, backgrounding-proof hand-off: persist the code to the
        // Flutter-readable prefs store so Flutter can reconcile it on its next
        // resume regardless of the live call below. The Compose Language screen runs
        // in NavigationHostActivity while the Flutter engine is backgrounded, so the
        // live `invokeFlutter` round-trip can be dropped or time out — this write is
        // the fix's load-bearing path (see LanguagePlugin.writePendingLanguage /
        // LanguageChannel.reconcilePendingLanguage).
        if (!LanguagePlugin.writePendingLanguage(code)) {
            crashReporter.report(
                IllegalStateException("writePendingLanguage: no app context"),
                mapOf("op" to "writePendingLanguage"),
            )
        }
        // Best-effort live Flutter-side apply (i18n + local provider) — a fast path
        // for the rare case the engine is reachable. The persist already succeeded in
        // the KMP data source before this is called, so a bridge failure here must NOT
        // surface as a save error — report it (this seam's only sink, mirroring
        // LanguageDataSourceImpl reporting its HTTP errors) and swallow. Never throws
        // except to propagate cancellation.
        try {
            LanguagePlugin.invokeFlutter("applyLanguage", code)
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "applyLanguage"))
        }
    }
}
