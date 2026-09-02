package com.snabbit.runner.shared.core.navigation.tabs

import androidx.lifecycle.ViewModel

/**
 * Retains a [TabNavigatorState] across the shell entry leaving and re-entering composition.
 *
 * The bottom-nav shell is a single entry in the [SnabbitNavHost]'s `NavDisplay` back stack.
 * When another native destination is pushed on top of it — the Language screen, say — the
 * single-pane scene strategy stops composing the shell entry. A plain
 * `remember { TabNavigatorState(...) }` would then be disposed and, on return, re-seeded to
 * the start tab (the selected tab jumps back to Home).
 *
 * Holding the [TabNavigatorState] in this entry-scoped [ViewModel] (kept alive by
 * `rememberViewModelStoreNavEntryDecorator`, see [SnabbitNavHost]) preserves the selected
 * tab **and** each tab's saveable state for the whole life of the entry — obtain it via
 * `viewModel { }` inside the shell's `nativeScreen` registration.
 */
class TabNavigatorStateHolder<Tab>(val state: TabNavigatorState<Tab>) : ViewModel()
