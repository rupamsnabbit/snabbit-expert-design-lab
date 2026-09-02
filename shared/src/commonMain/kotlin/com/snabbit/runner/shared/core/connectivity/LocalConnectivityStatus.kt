package com.snabbit.runner.shared.core.connectivity

import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.compositionLocalOf

/**
 * Ambient device [ConnectivityStatus] for the Compose tree. The host (e.g. `JobActivity`)
 * collects a [NetworkMonitor] and provides it here; components like
 * [com.snabbit.runner.shared.ui.components.SnabbitActionFooter] read it to show the
 * connectivity strip — so any footer becomes network-aware with no caller changes.
 *
 * Defaults to [ConnectivityStatus.Online] (no banner) so previews, tests, and any host
 * that doesn't provide it render exactly as before.
 */
val LocalConnectivityStatus: ProvidableCompositionLocal<ConnectivityStatus> =
    compositionLocalOf { ConnectivityStatus.Online }
