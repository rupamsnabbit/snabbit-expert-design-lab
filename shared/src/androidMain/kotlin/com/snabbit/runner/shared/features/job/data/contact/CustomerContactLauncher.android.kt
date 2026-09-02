package com.snabbit.runner.shared.features.job.data.contact

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Android [CustomerContactLauncher] — fires the platform `Intent`s. Holds the `Application` context
 * (bound in `platformModule`), so launches add `FLAG_ACTIVITY_NEW_TASK` (started from a non-Activity
 * context). Mirrors the Flutter `CallUtils` dialer fallback + `MapsNavigationService`.
 */
class AndroidCustomerContactLauncher(
    private val context: Context,
) : CustomerContactLauncher {

    override fun dial(phoneNumber: String) {
        // Guard a blank number (mirrors openMapsNavigation) — an empty tel: opens an empty dialer.
        if (phoneNumber.isBlank()) return
        // Every number here is SERVER-supplied and unvalidated — the customer's
        // `ph_no` from the envelope, or the helpline from `GET /runners/me/helpline`
        // (the delayed-check-in dial mode). `openMapsNavigation` below already
        // range-checks its server-supplied coordinates for the same reason.
        //
        // This deliberately rejects only what is not a phone number, chiefly the
        // MMI/USSD control characters ('*', '#') behind sequences like call
        // forwarding. It is NOT a defence against a hostile-but-well-formed number
        // — a compromised backend can always send a plausible attacker line — so it
        // stays permissive (separators stripped, 6–15 digits, optional '+') rather
        // than risking a runner being unable to call a customer mid-job because of
        // an unusual-but-legitimate format.
        val sanitized = phoneNumber.filterNot { it in PHONE_SEPARATORS }
        if (!DIALABLE.matches(sanitized)) return
        start(Intent.ACTION_DIAL, "tel:$sanitized")
    }

    override fun openMapsNavigation(latitude: Double, longitude: Double) {
        // Guard malformed coordinates (matches MapsNavigationService).
        if (latitude !in -90.0..90.0 || longitude !in -180.0..180.0) return
        // Google Maps turn-by-turn walking nav; browser fallback when Google Maps isn't installed.
        val opened = start(Intent.ACTION_VIEW, "google.navigation:q=$latitude,$longitude&mode=w")
        if (!opened) {
            start(
                Intent.ACTION_VIEW,
                "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking",
            )
        }
    }

    override fun openChat() {
        // TODO: customer chat — placeholder until the chat feature is wired (Flutter uses Stream Chat).
    }

    /** Fires [action] on [uri]; returns false when no activity can handle it (so callers can fall back). */
    private fun start(action: String, uri: String): Boolean = try {
        context.startActivity(
            Intent(action, Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    private companion object {
        /** Formatting a backend may include; stripped before validation. */
        val PHONE_SEPARATORS = setOf(' ', '-', '(', ')', '.')

        /** Optional leading '+' then 6–15 digits (E.164's max subscriber length). */
        val DIALABLE = Regex("^\\+?[0-9]{6,15}$")
    }
}
