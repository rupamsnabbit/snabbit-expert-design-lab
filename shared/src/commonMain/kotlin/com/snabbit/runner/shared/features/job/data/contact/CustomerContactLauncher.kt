package com.snabbit.runner.shared.features.job.data.contact

/**
 * Platform seam for the navigation-card contact launches — the masked-call **dialer fallback** and
 * **Google Maps** navigation. Android fires `Intent`s ([AndroidCustomerContactLauncher], bound in
 * `platformModule`); other targets fall back to [NoOpCustomerContactLauncher] (the app is
 * Android-only, mirroring the connectivity seam). Chat is a placeholder for now.
 */
interface CustomerContactLauncher {
    /** Opens the platform phone dialer for [phoneNumber] (the masked-call fallback). */
    fun dial(phoneNumber: String)

    /**
     * Opens Google Maps **walking** navigation to [latitude],[longitude] from the device's current
     * location (Maps supplies the origin). Mirrors the Flutter `MapsNavigationService`.
     */
    fun openMapsNavigation(latitude: Double, longitude: Double)

    /** Opens the customer chat. **Placeholder** — no-op until the chat feature is wired. */
    fun openChat()
}

/** No-op launcher — the default when no platform launcher is bound (iOS, previews, tests). */
object NoOpCustomerContactLauncher : CustomerContactLauncher {
    override fun dial(phoneNumber: String) = Unit
    override fun openMapsNavigation(latitude: Double, longitude: Double) = Unit
    override fun openChat() = Unit
}
