package com.snabbit.runner.shared.core.permissions.strict

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

/** Battery-optimization exemption (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). */
internal class BatteryOptHandler(private val context: Context) : StrictPermissionHandler {

    private val powerManager: PowerManager =
        context.getSystemService(Context.POWER_SERVICE) as PowerManager

    override fun isGranted(): Boolean =
        powerManager.isIgnoringBatteryOptimizations(context.packageName)

    // The direct-request intent needs the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission,
    // which the app already declares. Lint flags this action as Play-policy sensitive — the
    // app's use is a legitimate foreground/location runner case.
    @SuppressLint("BatteryLife")
    override fun settingsIntent(): Intent =
        Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${context.packageName}"),
        )
}
