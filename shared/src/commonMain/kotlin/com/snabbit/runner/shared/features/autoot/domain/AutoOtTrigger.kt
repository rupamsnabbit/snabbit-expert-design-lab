package com.snabbit.runner.shared.features.autoot.domain

import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails

/**
 * Edge signal the `AutoOtCoordinator` derives from the runner-state stream; drives
 * whether Home mounts the Auto-OT sheet. Mirrors the Flutter orchestrator's
 * initialize / reset / preempt decisions (`auto_ot_orchestrator.dart`).
 */
sealed interface AutoOtTrigger {
    /** No active offer (never shown, or cleared / consumed). */
    data object None : AutoOtTrigger

    /** A fresh offer to present. */
    data class Offer(val details: AutoOtDetails) : AutoOtTrigger

    /**
     * A job / suspension widget preempts OT — dismiss any active offer with
     * `CANCELLED_DUE_TO_JOB_ASSIGNMENT` (Flutter `shouldDismissForJobAssignment`).
     */
    data object Preempt : AutoOtTrigger

    /**
     * The server cancelled the offer (`AUTO_OT_CANCELLED` push, bridged from Dart) — flip an
     * active offer to expired, mirroring Flutter `handleAutoOtCancellation` → `handleExpired`.
     */
    data object Cancelled : AutoOtTrigger
}
