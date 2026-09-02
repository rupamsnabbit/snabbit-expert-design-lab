package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.profile.LoanSheetState
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.loan_money
import com.snabbit.runner.shared.resources.loan_money_locked
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import org.jetbrains.compose.resources.painterResource
import org.koin.mp.KoinPlatform.getKoin

/**
 * The Get-loan bottom sheet (drawer parity — `showLoanUnifiedSheet`), rendered in the
 * vendored [SnabbitBottomSheet] (`com.snabbit.runner.shared.ui.components`, the M3
 * `ModalBottomSheet` used by the job / OT / support sheets — replaces the older DS
 * `organisms` sheet for a consistent look + IME handling). Shows one of the
 * [LoanSheetState] outcomes; the eligible/"happy" case never reaches here (the ViewModel
 * opens the vendor URL directly).
 */
@Composable
fun ProfileLoanSheet(
    state: LoanSheetState?,
    onDismiss: () -> Unit,
    onRetry: () -> Unit,
    onUnderstood: () -> Unit,
    onViewDetails: () -> Unit,
) {
    // Conditional-render (matches the OT / job sheets): the M3 sheet mounts when there's a
    // state and animates out on swipe/scrim/back; a button/programmatic dismiss removes it.
    if (state == null) return
    val l10n: LocalizationStore = getKoin().get()
    SnabbitBottomSheet(
        onDismissRequest = onDismiss,
        // Informational outcomes — close button only, no drag handle (parity with OT).
        draggable = false,
        // White card: the loan illustrations have a white backdrop, so the default gray-50
        // made them look "boxed". Matches the Flutter loan sheet (AppColors.n0). Loan-only —
        // the PAN sheet keeps the default gray-50.
        containerColor = SnabbitTheme.colors.bgPrimary,
    ) {
        // The vendored sheet's card supplies the content padding.
        Column(modifier = Modifier.fillMaxWidth()) {
            when (state) {
                LoanSheetState.Loading -> LoanLoading()
                LoanSheetState.Error -> LoanError(onRetry)
                LoanSheetState.EarlyPayout -> LoanOutcome(
                    imageEarlyPayout = true,
                    title = l10n.getMessage("loan_not_available_early_payout", "Loan not available as you have taken Early payout"),
                    subtitle = l10n.getMessage("loan_come_back_next_month", "Come back next month to take loan"),
                    buttonLabel = l10n.getMessage("understood", "Understood"),
                    preButtonGap = 56.dp, // Flutter parity (loan_bottom_sheets.dart)
                    onButton = onUnderstood,
                )
                is LoanSheetState.LoanProcessed -> LoanOutcome(
                    imageEarlyPayout = false,
                    title = l10n.getMessage("loan_already_processed", "Your loan has already been processed"),
                    subtitle = null,
                    buttonLabel = l10n.getMessage("profile.loan_view_details", "View Details"),
                    preButtonGap = 88.dp, // Flutter parity (loan_bottom_sheets.dart)
                    onButton = onViewDetails,
                )
            }
        }
    }
}

@Composable
private fun LoanLoading() {
    Box(
        modifier = Modifier.fillMaxWidth().height(200.dp),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = ProfileTileDefaults.NudgeButton)
    }
}

@Composable
private fun LoanError(onRetry: () -> Unit) {
    val l10n: LocalizationStore = getKoin().get()
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.ErrorOutline,
            contentDescription = null,
            tint = ProfileTileDefaults.LabelError,
            modifier = Modifier.height(56.dp),
        )
        SnabbitText(
            text = l10n.getMessage("loan_details_error", "Failed to load loan details"),
            // 24sp title = Flutter's headlineMedium in showLoanUnifiedSheet.
            variant = SnabbitTextVariant.Heading2,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = ProfileTileDefaults.PageTitle,
            textAlign = TextAlign.Center,
        )
        LoanPrimaryButton(label = l10n.getMessage("profile.cta_retry", "Retry"), onClick = onRetry)
    }
}

@Composable
private fun LoanOutcome(
    imageEarlyPayout: Boolean,
    title: String,
    subtitle: String?,
    buttonLabel: String,
    preButtonGap: Dp,
    onButton: () -> Unit,
) {
    // Explicit spacers mirror the Flutter sheet (image → 16 → title → 12 → subtitle →
    // preButtonGap → button), rather than a uniform arrangement.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(
            painter = painterResource(
                if (imageEarlyPayout) Res.drawable.loan_money_locked else Res.drawable.loan_money,
            ),
            contentDescription = null,
            modifier = Modifier.height(120.dp),
        )
        Box(modifier = Modifier.height(16.dp))
        SnabbitText(
            text = title,
            variant = SnabbitTextVariant.Heading2,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = ProfileTileDefaults.PageTitle,
            textAlign = TextAlign.Center,
        )
        if (subtitle != null) {
            Box(modifier = Modifier.height(12.dp))
            SnabbitText(
                text = subtitle,
                variant = SnabbitTextVariant.BodyLg,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.HeaderSubtitle,
                textAlign = TextAlign.Center,
            )
        }
        Box(modifier = Modifier.height(preButtonGap))
        LoanPrimaryButton(label = buttonLabel, onClick = onButton)
    }
}

/** Full-width DS primary (pink) button — matches the OT / job sheets' CTA. */
@Composable
private fun LoanPrimaryButton(label: String, onClick: () -> Unit) {
    SnabbitButton(
        text = label,
        onClick = onClick,
        style = SnabbitButtonStyle.Primary,
        size = SnabbitButtonSize.L,
        fullWidth = true,
    )
}
