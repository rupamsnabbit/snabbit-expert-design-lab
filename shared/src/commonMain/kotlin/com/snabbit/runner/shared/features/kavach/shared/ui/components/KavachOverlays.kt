package com.snabbit.runner.shared.features.kavach.shared.ui.components

import androidx.compose.runtime.Composable
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeIntent
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetyHomeUiState
import com.snabbit.runner.shared.features.kavach.shared.ui.contracts.SafetySheet
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult
import com.snabbit.runner.shared.features.kavach.sos.ui.components.SosAlertSheetContent
import com.snabbit.runner.shared.ui.components.SnabbitBottomSheet as ForcedBottomSheet

/**
 * The Kavach overlay sheets — condition/consent, the SOS-trigger alert, and the permission-blocked
 * dialog. Shared by the standalone `SafetyHomeScreen` and the in-progress job screen (spec 2) so both
 * host identical Kavach chrome. State-driven (D2); actions routed via [onIntent].
 */
@Composable
fun KavachOverlaySheets(
    uiState: SafetyHomeUiState,
    onIntent: (SafetyHomeIntent) -> Unit,
    // false where the app-scoped AppSosHost renders the SOS alert (job/home embeds) — avoids a
    // duplicate alert. Defaults true for the standalone SafetyHome screen.
    showSosAlert: Boolean = true,
) {
    // Condition (keep-phone / battery-low) + consent sheet.
    SnabbitBottomSheet(
        visible = uiState.sheet != null,
        onDismissRequest = { onIntent(SafetyHomeIntent.DismissSheet) },
    ) {
        when (uiState.sheet) {
            SafetySheet.KEEP_PHONE -> KeepPhoneSheetContent(onConfirm = { onIntent(SafetyHomeIntent.ConfirmKeepPhone) })
            SafetySheet.BATTERY_LOW -> BatteryLowSheetContent(onDismiss = { onIntent(SafetyHomeIntent.DismissSheet) })
            null -> Unit
        }
    }

    // SOS-trigger alert — only when this composable owns SOS UI (standalone screen). On the job/home
    // embeds the app-scoped AppSosHost renders it (showSosAlert=false), so there's no duplicate.
    if (showSosAlert) {
        SnabbitBottomSheet(
            visible = uiState.sosAlertVisible,
            onDismissRequest = { onIntent(SafetyHomeIntent.DenySos) },
        ) {
            SosAlertSheetContent(
                onConfirm = { onIntent(SafetyHomeIntent.ConfirmSos) },
                onDeny = { onIntent(SafetyHomeIntent.DenySos) },
            )
        }
    }

    // Manual-activate permission dialog (mic+location). Scrim / back = "Not now".
    SnabbitBottomSheet(
        visible = uiState.permissionResult != null,
        onDismissRequest = { onIntent(SafetyHomeIntent.PermissionBlockShown) },
    ) {
        uiState.permissionResult?.let { result ->
            PermissionSheetContent(
                result = result,
                onRetry = { onIntent(SafetyHomeIntent.RetryPermission) },
                onOpenSettings = { onIntent(SafetyHomeIntent.OpenAppSettings) },
                onDismiss = { onIntent(SafetyHomeIntent.PermissionBlockShown) },
            )
        }
    }
}

/**
 * Mandatory mic gate (spec 1a): a non-dismissable sheet routing to Settings, shown while a job-start
 * Kavach launch is blocked on a missing mic grant. No "Not now" / scrim / back exit — the only way out
 * is granting the permission (the coordinator's foreground recheck then launches). Distinct from the
 * manual-activate dialog above, which IS dismissable.
 */
@Composable
fun KavachMicBlockSheet(visible: Boolean, onOpenSettings: () -> Unit) {
    if (!visible) return
    ForcedBottomSheet(
        onDismissRequest = {},
        dismissible = false,
        draggable = false,
        showCloseButton = false,
    ) {
        PermissionSheetContent(
            result = KavachPermissionResult.NeedsSettings,
            onRetry = {},
            onOpenSettings = onOpenSettings,
            onDismiss = {},
            dismissible = false,
        )
    }
}
