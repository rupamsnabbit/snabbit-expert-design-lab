package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.components.SnabbitButtonWithBadge
import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.features.gamification.presentation.ui.CtaBadgeChip
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.emergency_logout_bg
import org.jetbrains.compose.resources.painterResource
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutStrings
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutUiState

/**
 * Body of the emergency-logout confirm sheet (Figma 220:38847 / 222:43283).
 *
 * Three render states keyed off [EmergencyLogoutUiState]:
 *  - `isLoading == true` → centered spinner
 *  - `availability == null && errorMessage != null` → inline error + Retry CTA
 *  - else → title + (optional) period-leave row + Go back / Logout buttons row
 *
 * Gamification visuals — red-card / miss-shift / lose-₹ trio, "Shift ending"
 * pill, sheet warnings, red-card-chip on Logout — ship in the separate
 * gamification PR.
 */
@Composable
fun EmergencyLogoutSheet(
    state: EmergencyLogoutUiState,
    strings: EmergencyLogoutStrings,
    onTogglePeriodLeave: (Boolean) -> Unit,
    onGoBack: () -> Unit,
    onConfirm: () -> Unit,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
    // Gamification (KMP port): the decoded `cta_overrides[logout]` override drives
    // the consequence-card red-card count and the Logout CTA badge; the
    // earning-loss label drives the "Lose ₹X" tile. Threaded from the Koin-aware
    // host (`HomeTabContent`). Null → pre-port defaults (1 card, no chip/tile).
    logoutCta: CtaOverride? = null,
    earningLossLabel: String? = null,
) {
    when {
        state.isLoading -> LoadingBody(modifier = modifier)
        state.availability == null && state.errorType != null -> ErrorBody(
            message = strings.messageFor(state.errorType),
            retryLabel = strings.retry,
            onRetry = onRetry,
            modifier = modifier,
        )
        else -> ContentBody(
            state = state,
            strings = strings,
            onTogglePeriodLeave = onTogglePeriodLeave,
            onGoBack = onGoBack,
            onConfirm = onConfirm,
            modifier = modifier,
            logoutCta = logoutCta,
            earningLossLabel = earningLossLabel,
        )
    }
}

@Composable
private fun LoadingBody(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(160.dp),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = SnabbitTheme.colors.iconBrand)
    }
}

@Composable
private fun ErrorBody(
    message: String,
    retryLabel: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd, vertical = SnabbitTheme.spacing.componentPaddingLg),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        SnabbitText(
            text = message,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )
        SnabbitButton(
            text = retryLabel,
            onClick = onRetry,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.M,
        )
    }
}

@Composable
private fun ContentBody(
    state: EmergencyLogoutUiState,
    strings: EmergencyLogoutStrings,
    onTogglePeriodLeave: (Boolean) -> Unit,
    onGoBack: () -> Unit,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier,
    logoutCta: CtaOverride? = null,
    earningLossLabel: String? = null,
) {
    Box(modifier = modifier.fillMaxWidth()) {
        // Full-bleed gradient + shimmer header behind the content (Figma
        // 222:39909, 185dp). The DS panel already clips the rounded top corners.
        SnabbitImage(
            painter = painterResource(Res.drawable.emergency_logout_bg),
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .height(185.dp)
                .align(Alignment.TopCenter),
            contentScale = ContentScale.Crop,
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                // Figma 222:39908 — pt 40 / pb 36 (→ 32, nearest token) / px 16.
                .padding(
                    top = SnabbitTheme.spacing.`9`,
                    bottom = SnabbitTheme.spacing.`8`,
                    start = SnabbitTheme.spacing.componentPaddingMd,
                    end = SnabbitTheme.spacing.componentPaddingMd,
                ),
            horizontalAlignment = Alignment.CenterHorizontally,
            // 40dp between the title/cards group and the button row (Figma gap-40).
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`9`),
        ) {
            // Title + consequence cards — grouped with a 20dp gap (Figma gap-20).
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`6`),
            ) {
                SnabbitText(
                    text = strings.title,
                    variant = SnabbitTextVariant.Heading2,
                    fontWeight = FontWeight.SemiBold,
                    color = SnabbitTheme.colors.textPrimary,
                    textAlign = TextAlign.Center,
                )

                // Consequence cards — Red Card + Miss Full Shift + (optionally)
                // Lose ₹X. Red Card hides when period leave is selected, or when
                // the BE sends no red-card count at all (Dart parity — no default
                // card). The count comes from the decoded gamification
                // `cta_overrides[logout].red_cards`; the earning-loss tile appears
                // when the host supplies a label.
                EmergencyConsequenceCards(
                    redCardCount = logoutCta?.redCards ?: 0,
                    periodLeaveSelected = state.effectivePeriodLeave,
                    strings = strings,
                    earningLossLabel = earningLossLabel,
                )
            }

            if (state.showPeriodLeaveRow) {
                PeriodLeaveRow(
                    checked = state.periodLeaveChecked,
                    availableCount = state.periodLeave?.remaining ?: 0,
                    titleTemplate = strings.periodLeaveWithAvailableTemplate,
                    onCheckedChange = onTogglePeriodLeave,
                )
            }

            if (state.errorType != null) {
                SnabbitText(
                    text = strings.messageFor(state.errorType),
                    variant = SnabbitTextVariant.BodyMd,
                    color = SnabbitTheme.colors.textError,
                    textAlign = TextAlign.Center,
                )
            }

            // Use a plain Row + weight per child so each button claims half the
            // width. SnabbitButtonGroup(Row) + fullWidth=true on both children
            // made the first claim 100% and pushed Logout off-screen.
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
            ) {
                // Go back — outlined ghost button (white bg, gray-200 border,
                // gray-800 text).
                SnabbitButton(
                    text = strings.goBack,
                    onClick = onGoBack,
                    style = SnabbitButtonStyle.NeutralStroke,
                    size = SnabbitButtonSize.L,
                    enabled = !state.isSubmitting,
                    modifier = Modifier.weight(1f),
                )
                // Logout — carries the gamification red-card / coin badge inline
                // (Figma 220:38552 "Logout [1]") when cta_overrides[logout] has
                // one; plain Destructive button otherwise.
                if (logoutCta != null && (logoutCta.hasRedCardBadge || logoutCta.hasCoinBadge)) {
                    SnabbitButtonWithBadge(
                        text = strings.logout,
                        onClick = onConfirm,
                        style = SnabbitButtonStyle.Destructive,
                        size = SnabbitButtonSize.L,
                        enabled = state.canConfirm,
                        loading = state.isSubmitting,
                        modifier = Modifier.weight(1f),
                        // Figma 222:39966/39967 — Go back and Logout are both 174.5dp, i.e.
                        // each fills its half of the row. Explicit here even though the
                        // shim's badged path forces it, so the intent survives if that
                        // path is ever swapped for a real DS badge slot.
                        fullWidth = true,
                        badge = { CtaBadgeChip(cta = logoutCta) },
                    )
                } else {
                    SnabbitButton(
                        text = strings.logout,
                        onClick = onConfirm,
                        style = SnabbitButtonStyle.Destructive,
                        size = SnabbitButtonSize.L,
                        enabled = state.canConfirm,
                        loading = state.isSubmitting,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

