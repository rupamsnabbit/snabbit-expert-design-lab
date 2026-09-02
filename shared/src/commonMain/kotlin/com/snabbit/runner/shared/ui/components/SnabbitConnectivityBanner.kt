package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * SnabbitConnectivityBanner — full-width network-status strip (Expert App component).
 *
 * Figma: Design System 2.0 "Toast" set (state = "No internet" / "Bad Internet", style = "Middle").
 * A flush, edge-to-edge bar meant to sit **on top of** [SnabbitActionFooter] (which reads
 * [com.snabbit.runner.shared.core.connectivity.LocalConnectivityStatus] and renders this
 * automatically) — but usable standalone anywhere a status strip is needed.
 *
 * - [ConnectivityStatus.Online] renders **nothing** (the safe default — no strip).
 * - [ConnectivityStatus.Offline] → red wash (`bgErrorSubtle`) + `textError`, crossed signal bars.
 * - [ConnectivityStatus.BadConnection] → yellow wash (`bgWarningSubtle`) + `textWarning`, weak bars.
 *
 * Colors are DS **semantic** tokens; the icons are multi-color [AppIcons] glyphs rendered via
 * foundation [Image] (a single-tint `SnabbitIcon` would flatten them). Labels are parameters
 * (English defaults) so the host can pass server-driven copy.
 */
@Composable
fun SnabbitConnectivityBanner(
    status: ConnectivityStatus,
    modifier: Modifier = Modifier,
    offlineLabel: String = "No internet connection",
    badConnectionLabel: String = "Bad internet connection",
) {
    // Online → no strip. Early-return keeps callers free of null/visibility handling.
    if (status == ConnectivityStatus.Online) return
    val isOffline = status == ConnectivityStatus.Offline

    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isOffline) SnabbitTheme.colors.bgErrorSubtle else SnabbitTheme.colors.bgWarningSubtle,
            )
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            imageVector = if (isOffline) AppIcons.SignalOff else AppIcons.SignalWeak,
            contentDescription = null, // decorative — the label below carries the meaning
            // 32.dp matches the glyph's native 32×32 viewport (geometry verbatim from the Figma
            // "Toast" node); rendering smaller shrank the icon below the Figma spec (ECPO issue #3).
            modifier = Modifier.size(32.dp),
        )
        SnabbitText(
            text = if (isOffline) offlineLabel else badConnectionLabel,
            color = if (isOffline) SnabbitTheme.colors.textError else SnabbitTheme.colors.textWarning,
            fontSize = 20.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewSnabbitConnectivityBannerOffline() {
    SnabbitTheme {
        SnabbitConnectivityBanner(status = ConnectivityStatus.Offline)
    }
}

@Preview
@Composable
private fun PreviewSnabbitConnectivityBannerBadConnection() {
    SnabbitTheme {
        SnabbitConnectivityBanner(status = ConnectivityStatus.BadConnection)
    }
}
