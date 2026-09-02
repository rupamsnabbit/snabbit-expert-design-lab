package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent

/**
 * Suspended-runner takeover card (`RUNNER_SUSPENDED`) — the CMP port of Dart
 * `runner_suspended.dart`. Occupies the whole hero slot. Layout follows the
 * "Shift & Job Lifecycle DS" mockup (circular status icon → centered title →
 * filled primary CTA → outlined secondary), but the copy/actions mirror the
 * Dart widget verbatim (parity is the source of truth; the image is layout-only).
 *
 * Two variants keyed on [HomeCard.Suspended.isAadhaarRekyc]:
 *  - `false` → "Your documents are being verified" + "Come Back to Work"
 *    ([HomeUiIntent.RequestComeBack] → unsuspend POST). Once [submitted] the CTA
 *    locks to "Request submitted"; [comeBackLoading] shows the inline spinner.
 *  - `true`  → "…Aadhaar verification is incomplete" + "Update Aadhaar"
 *    ([HomeUiIntent.UpdateAadhaar] → bridge to the Dart re-KYC page).
 *
 * Both variants also show the outlined "Go to Earnings" secondary
 * ([HomeUiIntent.TapGoToEarnings]).
 */
@Composable
fun SuspendedCard(
    card: HomeCard.Suspended,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    submitted: Boolean = false,
    comeBackLoading: Boolean = false,
) {
    val cardShape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(SnabbitTheme.colors.bgPrimary, cardShape)
            .border(width = 2.dp, color = SnabbitTheme.colors.borderDefault, shape = cardShape)
            .padding(SnabbitTheme.spacing.componentPaddingLg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`6`),
    ) {
        // Circular status badge — amber warning, parity with Dart
        // `Icons.warning_amber_outlined` and the Figma icon slot: DS Warning glyph
        // (iconWarning) on a soft amber disc (bgWarningSubtle).
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgWarningSubtle),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitIcon(
                name = SnabbitIconName.Warning,
                size = 48.dp,
                color = SnabbitTheme.colors.iconWarning,
            )
        }

        SnabbitText(
            text = if (card.isAadhaarRekyc) strings.suspendedTitleAadhaar else strings.suspendedTitle,
            variant = SnabbitTextVariant.Heading2,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
        )

        // Primary CTA — variant-specific.
        if (card.isAadhaarRekyc) {
            SnabbitButton(
                text = strings.suspendedUpdateAadhaarCta,
                onClick = { onIntent(HomeUiIntent.UpdateAadhaar) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
            )
        } else {
            SnabbitButton(
                text = if (submitted) strings.suspendedRequestSubmittedCta else strings.suspendedComeBackCta,
                onClick = { onIntent(HomeUiIntent.RequestComeBack) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                // Locked once the request resolved (Dart parity: the button
                // becomes non-interactive "Request submitted").
                enabled = !submitted,
                loading = comeBackLoading,
            )
        }

        // Secondary — "Go to Earnings" (outlined ghost, Dart OutlinedButton parity).
        SnabbitButton(
            text = strings.suspendedGoToEarningsCta,
            onClick = { onIntent(HomeUiIntent.TapGoToEarnings) },
            style = SnabbitButtonStyle.NeutralStroke,
            size = SnabbitButtonSize.L,
            fullWidth = true,
        )
    }
}
