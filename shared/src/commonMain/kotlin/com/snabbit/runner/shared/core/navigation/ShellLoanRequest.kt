package com.snabbit.runner.shared.core.navigation

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * A one-shot request from the deep-link bridge to the RUNNING root-shell: switch to the
 * Profile tab and open the native loan sheet.
 *
 * Why this exists: the native loan sheet lives inside the Profile tab's composition (its
 * `ProfileViewModel` is scoped to the tab's nav-entry and is unreachable from outside), and
 * the shell exposes no live "switch tab + act" channel — its only external input is the
 * cold-launch `initialTab`, which doesn't apply to an already-running shell. This
 * process-scoped holder is that channel: the bridge sets [pending] via [request]; the shell
 * observes it and switches to Profile; `ProfileTabContent` observes it, dispatches
 * `ProfileUiIntent.ShowLoanSheet` to its ViewModel, and calls [consume].
 *
 * Used only on the MQTT-cohort deep-link path (the shell is the foreground surface, guaranteed
 * by the router's cohort-hold gate). Non-cohort runners have no shell and show the Flutter loan
 * sheet instead. Loan-specific by design — generalise to a command bus only if a second such
 * "drive the running shell" action ever appears.
 */
class ShellLoanRequest {
    private val _pending = MutableStateFlow(false)

    /** True while a loan-sheet request is awaiting the Profile tab to consume it. */
    val pending: StateFlow<Boolean> = _pending.asStateFlow()

    /** Bridge → shell: request the Profile-tab loan sheet. */
    fun request() {
        _pending.value = true
    }

    /** Profile tab (or the shell, if it can't show it) → mark the request handled. */
    fun consume() {
        _pending.value = false
    }
}
