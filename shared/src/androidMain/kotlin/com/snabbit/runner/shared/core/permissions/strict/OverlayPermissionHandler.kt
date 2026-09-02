package com.snabbit.runner.shared.core.permissions.strict

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/** `SYSTEM_ALERT_WINDOW` (draw-over-other-apps). */
internal class OverlayPermissionHandler(private val context: Context) : StrictPermissionHandler {

    override fun isGranted(): Boolean = Settings.canDrawOverlays(context)

    override fun settingsIntent(): Intent =
        Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        )
}
