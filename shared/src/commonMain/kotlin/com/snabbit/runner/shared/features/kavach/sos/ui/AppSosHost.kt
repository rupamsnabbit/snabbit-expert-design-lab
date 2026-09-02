package com.snabbit.runner.shared.features.kavach.sos.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase
import com.snabbit.runner.shared.features.kavach.sos.ui.components.SosAlertSheetContent
import kotlinx.coroutines.launch
import org.koin.mp.KoinPlatform.getKoin

/**
 * App-scoped SOS UI host. SOS is job-independent (shield-sos-lifecycle-contract §3) and must be
 * usable + visible on ANY screen, so this single host lives at the shell level (BottomNavHost) and
 * drives the SOS alert + navigation off the process-scoped [SosCoordinator] — independent of which
 * tab/screen raised it.
 *
 * Any screen's SOS button just calls [SosCoordinator.raiseManual] (non-blocking, no job required);
 * this host renders the confirm/deny alert while phase is ALERT and pushes SosActive whenever the
 * SOS becomes ACTIVE (raise→confirm, FCM/notification action, or reconcile-restore). It is the SOLE
 * SOS nav/alert surface — screen ViewModels no longer host it — so there's no double-navigation.
 */
@Composable
fun AppSosHost() {
    val coordinator = remember { getKoin().get<SosCoordinator>() }
    val nav = remember { getKoin().get<NavigationController>() }
    val scope = rememberCoroutineScope()
    val sos by coordinator.state.collectAsState()

    // Confirm/deny alert while a raised SOS awaits resolution. Scrim / back = "I'm safe" (deny).
    SnabbitBottomSheet(
        visible = sos.phase == SosPhase.ALERT,
        onDismissRequest = { scope.launch { coordinator.deny() } },
    ) {
        SosAlertSheetContent(
            onConfirm = { scope.launch { coordinator.confirm() } },
            onDeny = { scope.launch { coordinator.deny() } },
        )
    }

    // Push the active-SOS screen whenever the SOS becomes ACTIVE (fires once per transition).
    LaunchedEffect(sos.phase) {
        if (sos.phase == SosPhase.ACTIVE) nav.navigate(SosActive)
    }
}
