package com.snabbit.runner.awol

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.snabbit.runner.shared.features.awol.presentation.AwolEffect

private const val TAG = "AwolDirections"

/**
 * FR-04: open the maps app routed to the destination — the universal
 * Google-Maps-URL idiom (resolves to the app when installed, browser
 * otherwise). Never throws: a missing handler is logged, the alert stays up.
 * Shared by every AWOL surface host ([AwolOverlaySpec], the home-card
 * platform view) so both CTAs take the same path.
 */
internal fun openAwolDirections(context: Context, effect: AwolEffect.OpenDirections) {
    try {
        val uri = Uri.parse(
            "https://www.google.com/maps/dir/?api=1&destination=" +
                "${effect.latitude},${effect.longitude}",
        )
        context.startActivity(
            Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    } catch (e: Exception) {
        Log.e(TAG, "Failed to open directions", e)
    }
}
