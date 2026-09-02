package com.snabbit.runner.shared.features.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.profile.ui.ProfileFooter
import com.snabbit.runner.shared.features.profile.ui.ProfileFooterData
import com.snabbit.runner.shared.features.profile.ui.ProfileHeader
import com.snabbit.runner.shared.features.profile.ui.ProfileImproveRatingsBar
import com.snabbit.runner.shared.features.profile.ui.ProfileLoanSheet
import com.snabbit.runner.shared.features.profile.ui.ProfilePanSheet
import com.snabbit.runner.shared.features.profile.ui.ProfileNudge
import com.snabbit.runner.shared.features.profile.ui.ProfileNudgeCarousel
import com.snabbit.runner.shared.features.profile.ui.ProfileVishwaasBanner
import com.snabbit.runner.shared.features.profile.ui.ProfileSectionCard
import com.snabbit.runner.shared.features.profile.ui.ProfileTileDefaults
import com.snabbit.runner.shared.features.profile.ui.buildProfileSections
import com.snabbit.runner.shared.core.localization.LocalizationStore
import org.koin.mp.KoinPlatform.getKoin
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.ic_nudge_aadhaar
import com.snabbit.runner.shared.resources.ic_nudge_bank
import com.snabbit.runner.shared.resources.ic_nudge_pan

/**
 * The Profile tab's screen — a Compose Multiplatform UI over [ProfileViewModel].
 * [SnabbitScreen] provides the theme + window insets + snackbar only; the page
 * background is gray-50 and the **"Profile" heading scrolls with the content** (it is
 * the first list item, not a sticky top nav).
 *
 * Three-state body: **loading** (spinner) / **error** (message + Retry) / **content**.
 * The menu is data-driven — [buildProfileSections] is the single source of truth;
 * tiles/card/divider are Material 3 ([ProfileMenuRow] / [ProfileSectionCard]). The
 * header, nudge carousel, and error state still use Snabbit DS atoms.
 *
 * TODO: real per-tile icon SVGs (dummy placeholders for now); final header design;
 * Loan/PAN sheets PARKED.
 */
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel,
    strings: ProfileStrings,
    modifier: Modifier = Modifier,
    footer: ProfileFooterData? = null,
    /**
     * Renders the emergency-logout modal when [ProfileUiState.showEmergencyLogout]
     * is set. Injected because that flow owns its own VM (needs Koin/platform deps)
     * while `ProfileScreen` stays DI-free for previews/tests — `ProfileTabContent`
     * supplies it; previews use the no-op default. [onDismiss] clears the flag.
     */
    emergencyLogoutSheet: @Composable (onDismiss: () -> Unit) -> Unit = {},
    /** Non-null → the runner is on a new-scheme tier; the header card renders the per-tier
     *  "level" variant. Supplied by [ProfileTabContent] from the TieringViewModel. */
    tier: Tier? = null,
    onTierClick: () -> Unit = {},
    onTierShown: () -> Unit = {},
    /** The Udaan surface rendered directly below the profile card: the pre-intro intro
     *  banner OR the post-intro "Play video" row. Supplied by [ProfileTabContent] (it
     *  picks which, from the tiering state); null → nothing shown. */
    udaanSurface: (@Composable () -> Unit)? = null,
    /** Tiering live for this runner (effective date reached) — splits the menu's generic
     *  "Insurance" tile into Accident + Health. Supplied by [ProfileTabContent] from the tiering state. */
    tieringEnabled: Boolean = false,
) {
    val state by viewModel.uiState.collectAsState()

    // One-shot effects → snackbar (loan vendor-URL open failure). LaunchedEffect(Unit)
    // so the collector isn't recreated on recomposition (mirrors HomeScreen).
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ProfileUiEffect.ShowSnackbar -> snackbarHostState.showSnackbar(effect.message)
            }
        }
    }

    // "Profile" heading scrolls with the content (not a sticky top nav), so SnabbitScreen
    // provides only theme + insets + snackbar; the page background is gray-50 (DS bgPrimary
    // is white) so the white cards read on it.
    SnabbitScreen(
        modifier = modifier,
        containerColor = ProfileTileDefaults.PageBackground,
        snackbarHostState = snackbarHostState,
    ) { contentPadding ->
        val profile = state.profile
        when {
            state.isLoading && profile == null -> Box(
                modifier = Modifier.fillMaxSize().padding(contentPadding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
            }

            profile == null -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(contentPadding)
                    .padding(SnabbitTheme.spacing.componentPaddingLg),
                verticalArrangement = Arrangement.spacedBy(
                    SnabbitTheme.spacing.componentGapLg,
                    Alignment.CenterVertically,
                ),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                SnabbitText(
                    text = state.errorMessage ?: strings.errorMessage,
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
                SnabbitButton(
                    text = strings.retryLabel,
                    onClick = { viewModel.onIntent(ProfileUiIntent.Load) },
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    fullWidth = false,
                )
            }

            else -> ProfileContent(
                title = strings.title,
                profile = profile,
                showEarnings = state.showEarnings,
                referralsV2Enabled = state.referralsV2Enabled,
                isDebug = state.isDebug,
                canEmergencyLogout = state.canEmergencyLogout,
                periodLeave = state.periodLeave,
                vishwaasBannerUrl = state.vishwaasBannerUrl,
                footer = footer,
                isRefreshing = state.isRefreshing,
                contentPadding = contentPadding,
                onIntent = viewModel::onIntent,
                tier = tier,
                onTierClick = onTierClick,
                onTierShown = onTierShown,
                udaanSurface = udaanSurface,
                tieringEnabled = tieringEnabled,
            )
        }
        // Get-loan bottom sheet — vendored M3 SnabbitBottomSheet (shows when
        // state.loanSheet != null; the sheet internally conditional-renders).
        ProfileLoanSheet(
            state = state.loanSheet,
            onDismiss = { viewModel.onIntent(ProfileUiIntent.LoanSheetDismissed) },
            onRetry = { viewModel.onIntent(ProfileUiIntent.LoanSheetRetry) },
            onUnderstood = { viewModel.onIntent(ProfileUiIntent.LoanUnderstoodClicked) },
            onViewDetails = { viewModel.onIntent(ProfileUiIntent.LoanViewDetailsClicked) },
        )
        // PAN-update bottom sheet — vendored M3 SnabbitBottomSheet (shows when state.panSheet != null).
        ProfilePanSheet(
            state = state.panSheet,
            onDismiss = { viewModel.onIntent(ProfileUiIntent.PanSheetDismissed) },
            onInputChange = { viewModel.onIntent(ProfileUiIntent.PanInputChanged(it)) },
            onSubmit = { viewModel.onIntent(ProfileUiIntent.PanSubmit) },
            onCreateEpan = { viewModel.onIntent(ProfileUiIntent.CreatePanClicked) },
        )
        // Emergency-logout modal flow — owns its VM, rendered via the injected slot
        // (like HomeScreen's old FAB flow, now the Profile entry point).
        if (state.showEmergencyLogout) {
            emergencyLogoutSheet { viewModel.onIntent(ProfileUiIntent.EmergencyLogoutDismissed) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileContent(
    title: String,
    profile: RunnerProfile,
    showEarnings: Boolean,
    referralsV2Enabled: Boolean,
    isDebug: Boolean,
    canEmergencyLogout: Boolean,
    periodLeave: PeriodLeaveAvailability?,
    vishwaasBannerUrl: String?,
    footer: ProfileFooterData?,
    isRefreshing: Boolean,
    contentPadding: PaddingValues,
    onIntent: (ProfileUiIntent) -> Unit,
    tier: Tier? = null,
    onTierClick: () -> Unit = {},
    onTierShown: () -> Unit = {},
    udaanSurface: (@Composable () -> Unit)? = null,
    tieringEnabled: Boolean = false,
) {
    // Opens an existing Flutter page via the nav module's keep-host round trip
    // (the user returns to the Profile tab). Used by the top nudges; the section
    // menu builds its own opener inside buildProfileSections.
    fun open(route: String, args: Map<String, String> = emptyMap()) =
        onIntent(ProfileUiIntent.OpenFlutterRoute(route, args))

    val l10n: LocalizationStore = getKoin().get()

    // Top nudge carousel — only the nudges currently pending.
    val nudges = buildList {
        if (profile.hasBankNudge) {
            // Adding a bank/UPI re-fetches runners/me on the Flutter side, which pushes the
            // fresh profile into RunnerProfileStore → this VM (observing it) updates and the
            // nudge clears. Same for the Aadhaar re-KYC nudge below. No refresh-on-return needed.
            add(ProfileNudge(l10n.getMessage("profile.nudge_bank_title", "UPI ID / Bank details missing"), l10n.getMessage("profile.cta_add", "Add"), type = "bank", icon = Res.drawable.ic_nudge_bank) { onIntent(ProfileUiIntent.NudgeTapped("bank")); open(ProfileFlutterRoutes.ADD_BANK_OR_UPI) })
        }
        if (profile.hasAadhaarRekycNudge) {
            add(ProfileNudge(l10n.getMessage("profile.nudge_aadhaar_title", "Update your Aadhaar to keep your account active"), l10n.getMessage("profile.cta_update", "Update"), type = "aadhaar_rekyc", icon = Res.drawable.ic_nudge_aadhaar) { onIntent(ProfileUiIntent.NudgeTapped("aadhaar_rekyc")); open(ProfileFlutterRoutes.AADHAAR_REVERIFICATION) })
        }
        if (profile.hasPanNudge) {
            add(ProfileNudge(l10n.getMessage("profile.nudge_pan_title", "PAN card helps reduce income tax"), l10n.getMessage("profile.cta_add", "Add"), type = "pan", icon = Res.drawable.ic_nudge_pan) { onIntent(ProfileUiIntent.NudgeTapped("pan")); onIntent(ProfileUiIntent.ShowPanSheet) })
        }
        if (profile.hasPanAadhaarNudge) {
            add(ProfileNudge(l10n.getMessage("profile.nudge_pan_aadhaar_title", "Link your PAN with Aadhaar to reduce income tax"), type = "pan_aadhaar", icon = Res.drawable.ic_nudge_aadhaar))
        }
    }

    // Spotlight-nudge impression — fires once per distinct visible nudge set.
    val nudgeTypes = nudges.map { it.type }
    LaunchedEffect(nudgeTypes) {
        if (nudgeTypes.isNotEmpty()) onIntent(ProfileUiIntent.NudgesShown(nudgeTypes))
    }

    // The whole menu, as data — the single source of truth (see buildProfileSections).
    val sections = buildProfileSections(
        profile = profile,
        showEarnings = showEarnings,
        referralsV2Enabled = referralsV2Enabled,
        isDebug = isDebug,
        canEmergencyLogout = canEmergencyLogout,
        tieringEnabled = tieringEnabled,
        store = l10n,
        onIntent = onIntent,
    )

    val pullState = rememberPullToRefreshState()
    PullToRefreshBox(
        isRefreshing = isRefreshing,
        onRefresh = { onIntent(ProfileUiIntent.Refresh) },
        modifier = Modifier.fillMaxSize(),
        state = pullState,
        // Default indicator anchors at the top of the box, which sits BEHIND the
        // SnabbitScreen top nav (status-bar inset + nav height). Push it below the
        // nav so the spinner is actually visible (mirrors HomeScreen).
        indicator = {
            PullToRefreshDefaults.Indicator(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .windowInsetsPadding(WindowInsets.statusBars)
                    .padding(top = 72.dp),
                isRefreshing = isRefreshing,
                state = pullState,
            )
        },
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                top = contentPadding.calculateTopPadding() + ProfileTileDefaults.PageTitleTopGap,
                bottom = contentPadding.calculateBottomPadding() + 24.dp,
                start = 16.dp,
                end = 16.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.SectionGap),
        ) {
            // "Profile" heading (scrolls with content) + the header card, 16dp apart.
            item {
                Column(verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.PageTitleToContent)) {
                    SnabbitText(
                        text = title,
                        variant = SnabbitTextVariant.Heading2,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = ProfileTileDefaults.PageTitle,
                    )
                    // Header card + the "Improve Ratings" CTA sit tight together.
                    Column(verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.HeaderToImproveRatings)) {
                        ProfileHeader(
                            name = profile.name,
                            deliveryMethod = profile.deliveryMethod,
                            expertId = profile.displayId,
                            photoUrl = profile.photoUrl,
                            periodLeaveMax = periodLeave?.maxPeriodLeaves ?: 0,
                            periodLeaveTaken = periodLeave?.periodLeavesTaken ?: 0,
                            // Flutter parity (ECPO-930): a tiering runner's whole header card
                            // opens the tiers home webview (same as "View level"), not just that
                            // row; non-tiering keeps the legacy identity card.
                            onClick = if (tier != null) {
                                onTierClick
                            } else {
                                {
                                    onIntent(ProfileUiIntent.MenuItemTapped("view_tier", "header"))
                                    open(ProfileFlutterRoutes.IDENTITY_CARD)
                                }
                            },
                            tier = tier,
                            onTierClick = onTierClick,
                            onTierShown = onTierShown,
                        )
                        // Vishwaas rate-card banner (RC-gated; the VM resolves the per-language
                        // image URL and logs the impression). Sits below the header, above the CTA.
                        if (vishwaasBannerUrl != null) {
                            ProfileVishwaasBanner(
                                imageUrl = vishwaasBannerUrl,
                                onClick = { onIntent(ProfileUiIntent.VishwaasBannerClicked) },
                            )
                        }
                        // Rating value stays hidden; only the "improve" CTA is shown, when a
                        // rating exists. Colour softens once the runner is highly rated.
                        val rating = profile.currentMonthRating
                        if (rating != null) {
                            ProfileImproveRatingsBar(
                                highlyRated = rating >= ProfileTileDefaults.HighlyRatedThreshold,
                                onClick = { open(ProfileFlutterRoutes.PERFORMANCE) },
                                label = l10n.getMessage("profile.improve_ratings", "Improve Ratings"),
                            )
                        }
                    }
                }
            }

            // Udaan surface (intro banner pre-intro, or the "Play video" row after)
            // directly below the profile card. The LazyColumn's SectionGap (24dp)
            // supplies the ≥16dp margin above and below it.
            udaanSurface?.let { surface -> item(key = "udaan") { surface() } }

            if (nudges.isNotEmpty()) {
                item { ProfileNudgeCarousel(nudges = nudges) }
            }

            // Lazy over the sections (grows / backend-friendly); each card renders its
            // bounded rows eagerly. Keyed so tab-switch/recompose preserves item state.
            items(sections, key = { it.key }) { section ->
                ProfileSectionCard(section = section)
            }

            // Footer (brand label + app version + non-prod endpoint), below the sections.
            if (footer != null) {
                item(key = "footer") { ProfileFooter(data = footer) }
            }
        }
    }
}
