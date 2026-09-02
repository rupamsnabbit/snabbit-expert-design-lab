package com.snabbit.runner.shared.features.language.domain

/**
 * Bridge seam to Flutter-owned profile state.
 *
 * The runner profile (incl. `languagePreference`) stays in Flutter. After the
 * KMP data source has persisted a language change server-side, this applies it
 * to Flutter-owned state across a MethodChannel (reloads the i18n file + updates
 * the local profile provider). The channel-backed implementation is wired in
 * `:app`; tests use `FakeProfileGateway`.
 *
 * The runner's *current* selection is not read here — it travels as a launch
 * argument to the screen (Intent extra / nav destination), so this port is
 * apply-only + stateless (an app singleton).
 *
 * `suspend` + main-safe.
 */
interface ProfileGateway {
    /**
     * Applies [code] to Flutter-owned state AFTER the KMP data source has
     * persisted it server-side: reloads the i18n file and updates the local
     * profile provider.
     *
     * Best-effort — the network persist already succeeded, so a failure here must
     * not surface as a save error. Implementations report + swallow their own
     * failures and must not throw (except to propagate cancellation).
     */
    suspend fun applyLanguage(code: String)
}
