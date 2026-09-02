package com.snabbit.runner.shared.features.profile.ui

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.profile.ProfileFlutterRoutes
import com.snabbit.runner.shared.features.profile.ProfileUiIntent
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.features.profile.sampleRunnerProfile
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Tiering-gated routing in [buildProfileSections]: when tiering is live, Insurance splits into
 * Accident + Health and Early Payout / Loan reroute to their webviews (mirrors the Flutter
 * `drawer_menu` `isTieringEnabled` branches); otherwise each keeps its native destination.
 */
class ProfileMenuTieringRoutingTest {

    // Empty store → English fallbacks (the same labels the tiles render pre-bundle).
    private fun store() = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> })

    private fun sections(
        profile: RunnerProfile,
        tieringEnabled: Boolean,
        onIntent: (ProfileUiIntent) -> Unit = {},
    ) = buildProfileSections(
        profile = profile,
        showEarnings = false,
        referralsV2Enabled = false,
        isDebug = false,
        canEmergencyLogout = false,
        tieringEnabled = tieringEnabled,
        store = store(),
        onIntent = onIntent,
    )

    private fun tap(profile: RunnerProfile, tieringEnabled: Boolean, key: String): List<ProfileUiIntent> {
        val intents = mutableListOf<ProfileUiIntent>()
        sections(profile, tieringEnabled) { intents += it }.flatMap { it.items }.first { it.key == key }.onClick()
        return intents
    }

    private fun firstOpen(intents: List<ProfileUiIntent>) =
        intents.filterIsInstance<ProfileUiIntent.OpenFlutterRoute>().first()

    // ── Insurance split ──────────────────────────────────────────

    @Test
    fun `tiering disabled shows the single generic insurance tile`() {
        val keys = sections(sampleRunnerProfile(), tieringEnabled = false).flatMap { it.items }.map { it.key }
        assertTrue("insurance" in keys)
        assertFalse("accident_insurance" in keys)
        assertFalse("health_insurance" in keys)
    }

    @Test
    fun `tiering enabled replaces the generic insurance tile with accident and health`() {
        val keys = sections(sampleRunnerProfile(), tieringEnabled = true).flatMap { it.items }.map { it.key }
        assertTrue("accident_insurance" in keys)
        assertTrue("health_insurance" in keys)
        assertFalse("insurance" in keys)
    }

    @Test
    fun `accident and health tiles open their tiering webviews`() {
        val intents = mutableListOf<ProfileUiIntent>()
        val items = sections(sampleRunnerProfile(), tieringEnabled = true) { intents += it }.flatMap { it.items }
        items.first { it.key == "accident_insurance" }.onClick()
        items.first { it.key == "health_insurance" }.onClick()
        val opens = intents.filterIsInstance<ProfileUiIntent.OpenFlutterRoute>()
        assertEquals(2, opens.size)
        assertEquals(ProfileFlutterRoutes.APP_WEB_VIEW, opens[0].route)
        assertEquals(ProfileFlutterRoutes.WEBVIEW_INSURANCE_ACCIDENT, opens[0].args["webviewPath"])
        assertEquals(ProfileFlutterRoutes.WEBVIEW_INSURANCE_HEALTH, opens[1].args["webviewPath"])
    }

    // ── Early Payout ─────────────────────────────────────────────

    @Test
    fun `early payout reroutes to the tiering webview when enabled`() {
        val open = firstOpen(tap(sampleRunnerProfile(showEarlyPayout = true), tieringEnabled = true, "early_payout"))
        assertEquals(ProfileFlutterRoutes.APP_WEB_VIEW, open.route)
        assertEquals(ProfileFlutterRoutes.WEBVIEW_EARLY_PAYOUT, open.args["webviewPath"])
    }

    @Test
    fun `early payout keeps the native screen when tiering disabled`() {
        val open = firstOpen(tap(sampleRunnerProfile(showEarlyPayout = true), tieringEnabled = false, "early_payout"))
        assertEquals(ProfileFlutterRoutes.EARLY_PAYOUTS, open.route)
    }

    // ── Loan ─────────────────────────────────────────────────────

    @Test
    fun `loan reroutes to the tiering webview when enabled`() {
        val open = firstOpen(tap(sampleRunnerProfile(isLoanEligible = true), tieringEnabled = true, "get_loan"))
        assertEquals(ProfileFlutterRoutes.WEBVIEW_LOAN, open.args["webviewPath"])
    }

    @Test
    fun `loan opens the sheet when tiering disabled`() {
        assertTrue(ProfileUiIntent.ShowLoanSheet in tap(sampleRunnerProfile(isLoanEligible = true), tieringEnabled = false, "get_loan"))
    }
}
