package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * A sheet-warning row from the top-level `sheet_warnings[]` envelope field — the
 * KMP port of Dart `lib/models/gamification/sheet_warning.dart`.
 *
 * Unlike [PreActionNudge], the UI never reads a label / icon from these rows: it
 * uses [lifecycleActionType] to match the right attendance / logout sheet and
 * [ctaOverrides] for button labels, badges, and red-card counts. Rows whose
 * [expiresAtMs] is in the past are dropped by the parser.
 */
data class SheetWarning(
    val lifecycleActionType: String,
    val ctaOverrides: List<CtaOverride>? = null,
    val expiresAtMs: Long? = null,
) {
    val hasCtaOverrides: Boolean get() = !ctaOverrides.isNullOrEmpty()
}
