package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.features.profile.PanSheetState
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet
import org.koin.mp.KoinPlatform.getKoin

/**
 * The PAN-update bottom sheet (drawer parity — `UploadPanModalSheetV2`), in the vendored
 * [SnabbitBottomSheet] (`com.snabbit.runner.shared.ui.components`, the M3 `ModalBottomSheet`
 * used by the job / OT / support sheets): PAN field (max 10, upper-cased) → "Continue" (POST),
 * plus a "Create ePAN" link that opens the income-tax portal externally. Continue is enabled
 * only for a valid PAN (Flutter parity — no inline validation error; the server message shows
 * under the field). The M3 sheet lifts above the keyboard for the PAN field.
 */
@Composable
fun ProfilePanSheet(
    state: PanSheetState?,
    onDismiss: () -> Unit,
    onInputChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCreateEpan: () -> Unit,
) {
    if (state == null) return
    // Block dismissal (swipe / scrim / back / close) while the submit is in flight — the
    // vendored sheet's `dismissible = false` covers all three paths (the DS sheet only guarded
    // onDismissRequest). No drag handle; close button hidden mid-submit.
    SnabbitBottomSheet(
        onDismissRequest = { if (!state.isSubmitting) onDismiss() },
        showCloseButton = !state.isSubmitting,
        dismissible = !state.isSubmitting,
        draggable = false,
    ) {
        PanSheetContent(
            state = state,
            onInputChange = onInputChange,
            onSubmit = onSubmit,
            onCreateEpan = onCreateEpan,
        )
    }
}

@Composable
private fun PanSheetContent(
    state: PanSheetState,
    onInputChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCreateEpan: () -> Unit,
) {
    val l10n: LocalizationStore = getKoin().get()
    // The vendored sheet's card supplies the content padding.
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.Start,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SnabbitText(
            text = l10n.getMessage("profile.pan_sheet_title", "PAN card details"),
            // 24sp title matches Flutter's headlineSmall in UploadPanModalSheetV2.
            variant = SnabbitTextVariant.Heading2,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = ProfileTileDefaults.PageTitle,
        )
        SnabbitText(
            text = l10n.getMessage("profile.pan_number_label", "PAN card number"),
            variant = SnabbitTextVariant.BodyMd,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = ProfileTileDefaults.HeaderSubtitle,
        )
        OutlinedTextField(
            value = state.panInput,
            onValueChange = onInputChange,
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isSubmitting,
            singleLine = true,
            isError = state.error != null,
            textStyle = SnabbitTheme.typography.bodyLg.copy(fontWeight = FontWeight.Medium),
            // No DS text field exists yet (DS ships only SnabbitPhoneInput) — theme the
            // material3 field with DS tokens so it reads as brand-consistent: brand focus
            // border + cursor, DS neutral/error borders, white field on the gray card.
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = SnabbitTheme.colors.textPrimary,
                unfocusedTextColor = SnabbitTheme.colors.textPrimary,
                focusedContainerColor = SnabbitTheme.colors.bgPrimary,
                unfocusedContainerColor = SnabbitTheme.colors.bgPrimary,
                errorContainerColor = SnabbitTheme.colors.bgPrimary,
                cursorColor = SnabbitTheme.colors.textBrand,
                errorCursorColor = SnabbitTheme.colors.textError,
                focusedBorderColor = SnabbitTheme.colors.borderBrand,
                unfocusedBorderColor = SnabbitTheme.colors.borderDefault,
                errorBorderColor = SnabbitTheme.colors.borderError,
            ),
            placeholder = {
                SnabbitText(
                    text = l10n.getMessage("profile.pan_number_hint", "Enter your PAN Card number"),
                    variant = SnabbitTextVariant.BodyLg,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    color = ProfileTileDefaults.Chevron,
                )
            },
        )
        Row {
            SnabbitText(
                text = l10n.getMessage("profile.pan_no_pan", "Don't have a PAN ? "),
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.HeaderSubtitle,
            )
            SnabbitText(
                text = l10n.getMessage("profile.create_epan", "Create ePAN"),
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.BadgeText,
                textDecoration = TextDecoration.Underline,
                modifier = Modifier.clickable(onClick = onCreateEpan),
            )
        }
        if (state.error != null) {
            SnabbitText(
                text = state.error,
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.LabelError,
            )
        }
        // DS primary CTA — handles the enabled/disabled content colour + the in-flight
        // spinner itself (fixes the old raw-Button "Continue" rendering black when enabled).
        SnabbitButton(
            text = l10n.getMessage("continue", "Continue"),
            onClick = onSubmit,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = state.isPanValid && !state.isSubmitting,
            loading = state.isSubmitting,
        )
    }
}
