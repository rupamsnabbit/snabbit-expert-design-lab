package com.snabbit.runner.shared.features.profile

/**
 * Opens an external URL (loan vendor page / ePAN portal) outside the app, returning
 * whether it actually launched — so the loan flow can log the real `success` and show a
 * snackbar on failure (Flutter parity). The Android impl uses an `ACTION_VIEW` intent
 * (see `profileAndroidModule`); iOS supplies its own when Profile ships there.
 */
fun interface ExternalUrlOpener {
    fun open(url: String): Boolean
}
