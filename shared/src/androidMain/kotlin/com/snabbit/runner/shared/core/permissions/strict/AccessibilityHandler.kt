package com.snabbit.runner.shared.core.permissions.strict

import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Accessibility-service enablement.
 *
 * "Granted" here means at least one accessibility service **belonging to this app** is
 * enabled (detected from `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`). It cannot tell
 * which specific service — callers needing a specific component should verify it themselves.
 * The Settings intent opens the global Accessibility list (Android exposes no per-app deep link).
 */
internal class AccessibilityHandler(private val context: Context) : StrictPermissionHandler {

    override fun isGranted(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        val prefix = "${context.packageName}/"
        return enabled.split(':').any { it.startsWith(prefix) }
    }

    override fun settingsIntent(): Intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
}
