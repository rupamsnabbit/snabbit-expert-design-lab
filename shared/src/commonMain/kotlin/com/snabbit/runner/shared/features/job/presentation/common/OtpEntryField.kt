package com.snabbit.runner.shared.features.job.presentation.common

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme

/** Figma "Container": 52dp cells with a 12dp gap; the focused cell gets a brand-pink border. */
private const val OTP_CELL_WIDTH_DP = 52
private const val OTP_CELL_HEIGHT_DP = 56
private const val OTP_CELL_GAP_DP = 12

/**
 * OTP entry cells + input capture, shared by the check-in ([CheckInSheet]) and checkout
 * ([CheckoutSheet]) sheets. A transparent [BasicTextField] is layered over the visible cells to catch
 * numeric keystrokes — `alpha(0f)` hides its own text/cursor without a raw `Color` (banned on
 * `:shared`); the visible digits are drawn in the cells below it. The field does NOT auto-focus — the
 * sheet opens with the keyboard down, which appears (and the focus ring lights) only when the runner
 * taps the cells (ECPO-860: no keyboard-on-open).
 *
 * The cells are rendered here rather than via the DS `SnabbitPinInput` because that molecule is
 * display-only with **no focused-cell state** — tapping the field must highlight the active cell with a
 * `borderBrand` (pink) ring (ECPO-860 #1). The active cell is the next empty one while the field holds
 * focus; resting cells use gray-300. TODO(DS): fold a `focusedIndex` param into `SnabbitPinInput`
 * and switch back once the design system ships it.
 *
 * Layout: the cell run is capped to its natural width (`n·52 + (n-1)·12`, per Figma) and centered; the
 * helper/error line renders below at full width.
 */
@Composable
internal fun OtpEntryField(
    otp: String,
    onOtpChange: (String) -> Unit,
    helperText: String,
    error: String?,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    length: Int = 3,
) {
    var isFocused by remember { mutableStateOf(false) }
    val cellRunWidth = (length * OTP_CELL_WIDTH_DP + (length - 1) * OTP_CELL_GAP_DP).dp
    // The active cell is the next empty one; clamped so a full code keeps the last cell highlighted.
    // -1 (no highlight) whenever the field isn't focused.
    val focusedIndex = if (isFocused) otp.length.coerceIn(0, length - 1) else -1

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(modifier = Modifier.width(cellRunWidth)) {
            Row(horizontalArrangement = Arrangement.spacedBy(OTP_CELL_GAP_DP.dp)) {
                repeat(length) { i ->
                    OtpCell(
                        char = otp.getOrNull(i),
                        focused = i == focusedIndex,
                        enabled = enabled,
                    )
                }
            }
            BasicTextField(
                value = otp,
                onValueChange = { raw -> onOtpChange(raw.filter(Char::isDigit).take(length)) },
                enabled = enabled,
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.NumberPassword,
                    imeAction = ImeAction.Done,
                ),
                modifier = Modifier
                    .matchParentSize()
                    .onFocusChanged { isFocused = it.isFocused }
                    .alpha(0f),
            )
        }

        SnabbitText(
            text = error ?: helperText,
            variant = SnabbitTextVariant.Caption,
            color = if (error != null) SnabbitTheme.colors.textError else SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** One OTP digit cell: a rounded box whose border turns brand-pink while [focused], holding [char]. */
@Composable
private fun OtpCell(char: Char?, focused: Boolean, enabled: Boolean) {
    val shape = RoundedCornerShape(12.dp)
    val borderColor = if (focused) SnabbitTheme.colors.borderBrand else SnabbitColorsLight.gray400
    Box(
        modifier = Modifier
            .size(OTP_CELL_WIDTH_DP.dp, OTP_CELL_HEIGHT_DP.dp)
            .clip(shape)
            .border(1.5.dp, borderColor, shape),
        contentAlignment = Alignment.Center,
    ) {
        if (char != null) {
            SnabbitText(
                text = char.toString(),
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                color = if (enabled) SnabbitTheme.colors.textPrimary else SnabbitTheme.colors.textSecondary,
            )
        }
    }
}
