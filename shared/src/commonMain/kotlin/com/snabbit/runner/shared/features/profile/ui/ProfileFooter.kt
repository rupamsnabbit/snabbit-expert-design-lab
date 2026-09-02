package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant

/**
 * Profile footer (drawer parity — `drawer_menu` bottom): the app version, and —
 * **non-prod only** — the current endpoint. Values come from the bridged
 * [NetworkConfig][com.snabbit.runner.shared.core.network.NetworkConfig] (see
 * [ProfileFooterData]); the endpoint line is hidden in production. `commonMain`.
 */
data class ProfileFooterData(
    /** Pre-formatted "App version X+Y" (Dart-computed via Shorebird + PackageInfo). */
    val appVersion: String,
    /** Base URL to show on non-prod builds; null in prod (line hidden). */
    val endpoint: String?,
    /** Non-prod only: live realtime status label ("Connected (MQTT)", "Degraded …"); null in prod. */
    val realtimeStatus: String? = null,
)

@Composable
fun ProfileFooter(
    data: ProfileFooterData,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.FooterLineGap),
    ) {
        if (data.appVersion.isNotBlank()) {
            SnabbitText(
                text = data.appVersion,
                variant = SnabbitTextVariant.Caption,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.Chevron,
                textAlign = TextAlign.Center,
            )
        }
        if (data.endpoint != null) {
            SnabbitText(
                text = "Endpoint - ${data.endpoint}",
                variant = SnabbitTextVariant.Caption,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.Chevron,
                textAlign = TextAlign.Center,
            )
        }
        if (data.realtimeStatus != null) {
            SnabbitText(
                text = "Realtime - ${data.realtimeStatus}",
                variant = SnabbitTextVariant.Caption,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.Chevron,
                textAlign = TextAlign.Center,
            )
        }
    }
}
