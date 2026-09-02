package com.snabbit.runner.shared.features.shift.lunch.domain.model

/**
 * Color band of the active-break countdown ring. For the live break, derived
 * in `HomeViewModel.breakColorFor` from the *fraction* of the break remaining
 * (< 30% red, < 50% amber, else green) — a simpler, self-contained rule than
 * the server-supplied threshold fields it replaced (see
 * [com.snabbit.runner.shared.features.shift.lunch.domain.model.LunchPhase.OnBreak]).
 *
 *  - [Initial] — the pre-start "starting soon" sub-window, not a break-remaining band.
 *  - [Green]   — ≥50% of the break remains.
 *  - [Amber]   — 30–50% remains.
 *  - [Red]     — <30% remains.
 *
 * Domain-level so the read model / VM stay free of Compose color tokens; the UI
 * maps each band to an `AppColors`/DS color.
 */
enum class BreakColorState { Initial, Green, Amber, Red }
