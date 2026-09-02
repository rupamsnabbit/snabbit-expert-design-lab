package com.snabbit.runner.shared.core.device

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.StatFs
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flow

/** Battery % from the sticky `ACTION_BATTERY_CHANGED` broadcast (seeded from the current sticky intent). */
internal class AndroidBatteryMonitor(private val app: Application) : BatteryMonitor {
    override fun batteryPercent(): Flow<Int?> = callbackFlow {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) { trySend(intent?.pct()) }
        }
        val sticky = app.registerReceiver(receiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        trySend(sticky?.pct())
        awaitClose { app.unregisterReceiver(receiver) }
    }

    private fun Intent.pct(): Int? {
        val level = getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        return if (level >= 0 && scale > 0) level * 100 / scale else null
    }
}

/** Free MB on the volume that holds the app's files (point-read via [StatFs]). */
internal class AndroidStorageMonitor(private val app: Application) : StorageMonitor {
    override fun freeDiskMb(): Flow<Long?> = flow {
        emit(
            runCatching {
                val stat = StatFs(app.filesDir.path)
                stat.availableBlocksLong * stat.blockSizeLong / (1024L * 1024L)
            }.getOrNull(),
        )
    }
}
