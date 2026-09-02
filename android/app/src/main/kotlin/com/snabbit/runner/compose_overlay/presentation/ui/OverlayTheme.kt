package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.runner.R

/** Design tokens for the AWOL overlay UI — mirrors the Flutter-side AppColors. */
object OverlayColors {
    val n0 = Color(0xFFFFFFFF)
    val n20 = Color(0xFFF5F5F5)
    val n30 = Color(0xFFE6E8F0)
    val n80 = Color(0xFF525871)
    val n90 = Color(0xFF101840)

    val r10 = Color(0xFFF9DADA)
    val r20 = Color(0xFFF4B6B6)
    val r50 = Color(0xFFA73636)
    val r60 = Color(0xFF7D2828)

    val g20 = Color(0xFFA3E6CD)
    val g40 = Color(0xFF429777)

    val breachGradientStart = Color(0xFFFFE0DF)
    val reEnteredGradientStart = Color(0xFFE9FFDF)
    val darkText = Color(0xFF1F1F1F)
    val timerArc = Color(0xFFCC0700)

    // Traffic-light timer colors (for job AWOL)
    val g10 = Color(0xFFDCF2EA)
    val g30 = Color(0xFF52BD94)
    val g50 = Color(0xFF317159)
    val y10 = Color(0xFFFFEFD2)
    val y40 = Color(0xFFFFB020)
    val y60 = Color(0xFF66460D)
    val r40 = Color(0xFFD14343)
    val r70 = Color(0xFFC50F1F)

    // Mini overlay
    val miniTitle = Color(0xFF101828)
    val miniSubtext = Color(0xFF525871)
}

/** Layout dimensions for the overlay cards, buttons, and timers. */
object OverlayDimens {
    val cardRadius = 20.dp
    val horizontalPadding = 20.dp
    val buttonHeight = 47.dp
    val buttonRadius = 8.dp
    val mapHeight = 203.dp
    val timerSize = 160.dp
    val timerStroke = 8.dp
    val consequenceIconSize = 52.dp

    // Mini overlay
    val miniCardRadius = 18.dp
    val miniPadding = 16.dp
    val miniTimerSize = 56.dp
    val miniTimerStroke = 4.dp
}

/** Resolved timer colors for arc, text, and background ring. */
data class TimerColors(val arc: Color, val text: Color, val bg: Color)

/** Resolve timer colors based on progress and color mode. */
fun resolveTimerColors(progress: Float, timerColorMode: String): TimerColors {
    return if (timerColorMode == "traffic") {
        when {
            progress > 0.66f -> TimerColors(
                arc = OverlayColors.g30,
                text = OverlayColors.g50,
                bg = OverlayColors.g10,
            )
            progress > 0.33f -> TimerColors(
                arc = OverlayColors.y40,
                text = OverlayColors.y60,
                bg = OverlayColors.y10,
            )
            else -> TimerColors(
                arc = OverlayColors.r40,
                text = OverlayColors.r50,
                bg = OverlayColors.r70,
            )
        }
    } else {
        TimerColors(
            arc = OverlayColors.timerArc,
            text = OverlayColors.r60,
            bg = OverlayColors.r10,
        )
    }
}

val MetropolisFamily = FontFamily(
    Font(R.font.metropolis_regular, FontWeight.Normal),
    Font(R.font.metropolis_medium, FontWeight.Medium),
    Font(R.font.metropolis_semi_bold, FontWeight.SemiBold),
    Font(R.font.metropolis_bold, FontWeight.Bold),
    Font(R.font.metropolis_extra_bold, FontWeight.ExtraBold),
)
