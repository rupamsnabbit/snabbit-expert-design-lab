package com.snabbit.runner.shared.features.shift.core.domain.model

/**
 * Shift phase — drives the background archetype and which cards the VM emits.
 *
 * Only [PreShift] and [SearchingForJobs] are implemented in this slice. Future
 * phases land alongside their cards (AttendanceMarked, JobAssigned, ShiftActive,
 * OnLeave, ...) — adding one is a sealed-arm + `bg()` arm + composable.
 */
enum class ShiftPhase {
    PreShift,
    SearchingForJobs,
    /** End-of-shift: BE pushes `RUNNER_LOGOUT`. Same Map archetype as
     *  SearchingForJobs (full-bleed bg + floating widget) — only the
     *  widget variant differs (Logout vs Searching). */
    Logout,
    // AttendanceMarked, JobAssigned, ShiftActive, OnLeave — land per-PR
}
