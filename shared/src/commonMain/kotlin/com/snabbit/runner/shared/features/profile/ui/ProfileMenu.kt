package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.ui.graphics.Color
import com.snabbit.runner.shared.features.profile.ProfileFlutterRoutes
import com.snabbit.runner.shared.features.profile.ProfileRouteDecider
import com.snabbit.runner.shared.features.profile.ProfileUiIntent
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.ic_apply_leave
import com.snabbit.runner.shared.resources.ic_early_payout
import com.snabbit.runner.shared.resources.ic_emergency_logout
import com.snabbit.runner.shared.resources.ic_get_loan
import com.snabbit.runner.shared.resources.ic_insurance
import com.snabbit.runner.shared.resources.ic_language
import com.snabbit.runner.shared.resources.ic_merch_store
import com.snabbit.runner.shared.resources.ic_monthly_earnings
import com.snabbit.runner.shared.resources.ic_payout_history
import com.snabbit.runner.shared.resources.ic_rate_card
import com.snabbit.runner.shared.resources.ic_refer
import com.snabbit.runner.shared.resources.ic_seva
import org.jetbrains.compose.resources.DrawableResource

/**
 * One tappable menu row, as **data** (not UI). Rendered by [ProfileMenuRow]; grouped
 * by [ProfileSection]. [key] must be stable — it's the LazyColumn item key.
 */
data class ProfileMenuItem(
    val key: String,
    val label: String,
    val leadingIcon: DrawableResource? = null, // per-tile SVG (composeResources/drawable); null → dummy placeholder
    val value: String? = null,
    val valueColor: Color = ProfileTileDefaults.Value,
    val labelColor: Color = ProfileTileDefaults.Label,
    val showNewBadge: Boolean = false,
    val showChevron: Boolean = true,
    val onClick: () -> Unit,
)

/** One titled section (a [ProfileSectionCard]) grouping [items]. [key] is stable. */
data class ProfileSection(
    val key: String,
    val title: String,
    val items: List<ProfileMenuItem>,
)

/**
 * THE single place that defines the Profile menu. Add / reorder / gate a tile here
 * and it reflects on screen — `ProfileScreen` just renders the returned list.
 *
 * Returns **data** (`List<ProfileSection>`), so it's pure and unit-testable: given a
 * [RunnerProfile] + the Remote-Config flags it returns exactly the sections/rows that
 * should show (gates applied — an item that shouldn't appear is not added; a section
 * that ends up empty is dropped by [addSection]). `onClick` routes through [onIntent].
 *
 * Parity is tracked against the Flutter drawer (drawer-parity audit): every drawer
 * surface is here, PARKED, or a deliberate drop.
 */
fun buildProfileSections(
    profile: RunnerProfile,
    showEarnings: Boolean,
    referralsV2Enabled: Boolean,
    isDebug: Boolean,
    canEmergencyLogout: Boolean,
    tieringEnabled: Boolean,
    store: LocalizationStore,
    onIntent: (ProfileUiIntent) -> Unit,
): List<ProfileSection> {
    // Opens an existing Flutter page via the nav module's keep-host round trip
    // (the user returns to the Profile tab).
    fun open(route: String, args: Map<String, String> = emptyMap()) =
        onIntent(ProfileUiIntent.OpenFlutterRoute(route, args))

    val sections = buildList {
        // ── Earnings & Payments ──────────────────────────────────────────────
        addSection(
            "earnings",
            store.getMessage("profile.section_earnings", "Earnings & Payments"),
            buildList {
                // Monthly earnings — gated on RC `expert_show_earnings`. No inline ₹
                // amount: not available from runners/me (data-diff). v2 → monthly-summary
                // webview (drawer parity), else the native PayoutHome.
                if (showEarnings) {
                    add(
                        ProfileMenuItem(
                            key = "monthly_earnings",
                            label = store.getMessage("profile.monthly_earnings", "Monthly earnings"),
                            leadingIcon = Res.drawable.ic_monthly_earnings,
                            onClick = {
                                val r = ProfileRouteDecider.monthlyEarnings(profile.isRateCardV2Effective)
                                open(r.route, r.args)
                            },
                        ),
                    )
                }
                if (profile.showTransactionHistory) {
                    add(
                        ProfileMenuItem(
                            key = "payout_history",
                            label = store.getMessage("profile.payout_history", "Payout history"),
                            leadingIcon = Res.drawable.ic_payout_history,
                            onClick = { open(ProfileFlutterRoutes.TRANSACTION_HISTORY) },
                        ),
                    )
                }
                if (profile.showEarlyPayout) {
                    add(
                        ProfileMenuItem(
                            key = "early_payout",
                            label = store.getMessage("profile.early_payout", "Early Payout"),
                            leadingIcon = Res.drawable.ic_early_payout,
                            showNewBadge = true,
                            // Tiering parity: the webview replaces the native early-payouts screen.
                            onClick = {
                                if (tieringEnabled) {
                                    open(
                                        ProfileFlutterRoutes.APP_WEB_VIEW,
                                        mapOf(
                                            "webviewPath" to ProfileFlutterRoutes.WEBVIEW_EARLY_PAYOUT,
                                            "title" to store.getMessage("profile.early_payout", "Early Payout"),
                                        ),
                                    )
                                } else {
                                    open(ProfileFlutterRoutes.EARLY_PAYOUTS)
                                }
                            },
                        ),
                    )
                }
                if (profile.isRateCardV2Effective) {
                    add(
                        ProfileMenuItem(
                            key = "rate_card",
                            label = store.getMessage("profile.rate_card", "Rate card"),
                            leadingIcon = Res.drawable.ic_rate_card,
                            onClick = {
                                open(
                                    ProfileFlutterRoutes.APP_WEB_VIEW,
                                    mapOf(
                                        "webviewPath" to ProfileFlutterRoutes.WEBVIEW_RATE_CARD,
                                        "title" to "Rate card",
                                    ),
                                )
                            },
                        ),
                    )
                }
            },
        )

        // ── Shift & Availability ─────────────────────────────────────────────
        addSection(
            "shift",
            store.getMessage("profile.section_shift", "Shift & Availability"),
            buildList {
                add(
                    ProfileMenuItem(
                        key = "apply_leave",
                        label = store.getMessage("profile.apply_leave", "Apply leave"),
                        leadingIcon = Res.drawable.ic_apply_leave,
                        onClick = { open(ProfileFlutterRoutes.LONG_LEAVE) },
                    ),
                )
                // Emergency logout: on-shift only (RUNNER_WAIT_HOTSPOT / RUNNER_LOGOUT) —
                // the gate is the live `current_state` widget_name, folded into
                // `canEmergencyLogout` by ProfileViewModel. The flow itself is a modal
                // hosted by ProfileTabContent (opened via this intent).
                if (canEmergencyLogout) {
                    add(
                        ProfileMenuItem(
                            key = "emergency_logout",
                            label = store.getMessage("profile.emergency_logout", "Emergency logout"),
                            leadingIcon = Res.drawable.ic_emergency_logout,
                            labelColor = ProfileTileDefaults.LabelError,
                            onClick = { onIntent(ProfileUiIntent.ShowEmergencyLogout) },
                        ),
                    )
                }
            },
        )

        // ── Benefits & Perks ─────────────────────────────────────────────────
        addSection(
            "benefits",
            store.getMessage("profile.section_benefits", "Benefits & Perks"),
            buildList {
                // Refer & earn — RC `expert_is_referrals_v2_enabled` routes to the referrals
                // webview (entry_point=profile_menu) vs native ReferralsHome (drawer parity).
                add(
                    ProfileMenuItem(
                        key = "refer",
                        label = store.getMessage("profile.refer_earn", "Refer & earn"),
                        leadingIcon = Res.drawable.ic_refer,
                        onClick = {
                            val r = ProfileRouteDecider.referAndEarn(referralsV2Enabled, entryPoint = "profile_menu")
                            open(r.route, r.args)
                        },
                    ),
                )
                if (profile.showSeva) {
                    add(
                        ProfileMenuItem(
                            key = "seva",
                            label = store.getMessage("common.seva", "Seva"),
                            leadingIcon = Res.drawable.ic_seva,
                            showNewBadge = true,
                            onClick = {
                                open(
                                    ProfileFlutterRoutes.APP_WEB_VIEW,
                                    mapOf(
                                        "url" to profile.sevaUrl.orEmpty(),
                                        "title" to "Seva",
                                        "fetchLocation" to "true",
                                    ),
                                )
                            },
                        ),
                    )
                }
                // Tiering parity (drawer_menu): once tiering is live for the runner the single
                // generic "Insurance" tile splits into Accident + Health, each opening its own
                // tiering webview; otherwise the generic tile (native insurance-support) shows.
                if (tieringEnabled) {
                    add(
                        ProfileMenuItem(
                            key = "accident_insurance",
                            label = store.getMessage("accident_insurance", "Accident Insurance"),
                            leadingIcon = Res.drawable.ic_insurance,
                            onClick = {
                                open(
                                    ProfileFlutterRoutes.APP_WEB_VIEW,
                                    mapOf(
                                        "webviewPath" to ProfileFlutterRoutes.WEBVIEW_INSURANCE_ACCIDENT,
                                        "title" to store.getMessage("accident_insurance", "Accident Insurance"),
                                    ),
                                )
                            },
                        ),
                    )
                    add(
                        ProfileMenuItem(
                            key = "health_insurance",
                            label = store.getMessage("health_insurance", "Health Insurance"),
                            leadingIcon = Res.drawable.ic_insurance,
                            onClick = {
                                open(
                                    ProfileFlutterRoutes.APP_WEB_VIEW,
                                    mapOf(
                                        "webviewPath" to ProfileFlutterRoutes.WEBVIEW_INSURANCE_HEALTH,
                                        "title" to store.getMessage("health_insurance", "Health Insurance"),
                                    ),
                                )
                            },
                        ),
                    )
                } else {
                    add(
                        ProfileMenuItem(
                            key = "insurance",
                            label = store.getMessage("profile.insurance", "Insurance"),
                            leadingIcon = Res.drawable.ic_insurance,
                            onClick = { open(ProfileFlutterRoutes.INSURANCE_SUPPORT) },
                        ),
                    )
                }
                if (profile.showMerchStore) {
                    add(
                        ProfileMenuItem(
                            key = "merch_store",
                            label = store.getMessage("profile.snabbit_store", "Snabbit store"),
                            leadingIcon = Res.drawable.ic_merch_store,
                            onClick = {
                                open(
                                    ProfileFlutterRoutes.APP_WEB_VIEW,
                                    mapOf(
                                        "url" to profile.merchStoreUrl.orEmpty(),
                                        "title" to "Snabbit store",
                                        "fetchLocation" to "true",
                                    ),
                                )
                            },
                        ),
                    )
                }
                if (profile.isLoanEligible) {
                    add(
                        ProfileMenuItem(
                            key = "get_loan",
                            label = store.getMessage("profile.get_loan", "Get loan"),
                            leadingIcon = Res.drawable.ic_get_loan,
                            showNewBadge = true,
                            // Tiering parity: the loan webview replaces the native loan sheet.
                            onClick = {
                                if (tieringEnabled) {
                                    open(
                                        ProfileFlutterRoutes.APP_WEB_VIEW,
                                        mapOf(
                                            "webviewPath" to ProfileFlutterRoutes.WEBVIEW_LOAN,
                                            "title" to "Loans",
                                        ),
                                    )
                                } else {
                                    onIntent(ProfileUiIntent.ShowLoanSheet)
                                }
                            },
                        ),
                    )
                }
            },
        )

        // ── Account & Settings ───────────────────────────────────────────────
        // Dropped per product decision: Emergency contact, Personal details & KYC,
        // Bank/PAN detail rows (nudge-only).
        addSection(
            "account",
            store.getMessage("profile.section_account", "Account & Settings"),
            buildList {
                add(
                    ProfileMenuItem(
                        key = "language",
                        label = store.getMessage("profile.language", "Language"),
                        leadingIcon = Res.drawable.ic_language,
                        onClick = { onIntent(ProfileUiIntent.OpenLanguage) },
                    ),
                )
                // Silent notifications — app_config gated; taps a Flutter-side action
                // (stop notifications/audio) rather than navigating (no chevron).
                if (profile.showSilentNotification) {
                    add(
                        ProfileMenuItem(
                            key = "silent_notifications",
                            label = store.getMessage("profile.silent_notifications", "Silent notifications"),
                            showChevron = false,
                            onClick = { onIntent(ProfileUiIntent.SilentNotificationsClicked) },
                        ),
                    )
                }
                // Debug Menu — debug builds only (Flutter's kDebugMode); keep-host route.
                if (isDebug) {
                    add(
                        ProfileMenuItem(
                            key = "debug_menu",
                            label = store.getMessage("profile.debug_menu", "Debug Menu"),
                            onClick = { onIntent(ProfileUiIntent.OpenFlutterRoute(ProfileFlutterRoutes.DEBUG_MENU)) },
                        ),
                    )
                }
            },
        )
    }

    // Fire `profile_screen_cta_click` on every tile tap (analytics-only), preserving
    // each tile's own action. Wrapped centrally so no per-tile edits are needed.
    return sections.map { section ->
        section.copy(
            items = section.items.map { item ->
                val action = item.onClick
                item.copy(
                    onClick = {
                        onIntent(ProfileUiIntent.MenuItemTapped(cta = item.key, section = section.key))
                        action()
                    },
                )
            },
        )
    }
}

/** Appends a section only when it has ≥1 item (empty sections render nothing). */
private fun MutableList<ProfileSection>.addSection(
    key: String,
    title: String,
    items: List<ProfileMenuItem>,
) {
    if (items.isNotEmpty()) add(ProfileSection(key, title, items))
}
