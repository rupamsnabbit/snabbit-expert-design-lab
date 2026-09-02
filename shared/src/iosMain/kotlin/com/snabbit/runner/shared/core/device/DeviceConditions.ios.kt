package com.snabbit.runner.shared.core.device

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flow
import platform.Foundation.NSFileManager
import platform.Foundation.NSFileSystemFreeSize
import platform.Foundation.NSHomeDirectory
import platform.Foundation.NSNotificationCenter
import platform.Foundation.NSNumber
import platform.UIKit.UIDevice
import platform.UIKit.UIDeviceBatteryLevelDidChangeNotification

/**
 * Live `UIDevice.batteryLevel` (Float 0–1, -1 = unknown → null), parity with Android's live
 * callbackFlow: seed the current level, then re-emit on every battery-level change so the block/
 * sheet stays current instead of freezing on the first read (#R-battery).
 */
internal class IosBatteryMonitor : BatteryMonitor {
    override fun batteryPercent(): Flow<Int?> = callbackFlow {
        val device = UIDevice.currentDevice
        device.batteryMonitoringEnabled = true
        fun pct(): Int? {
            val level = device.batteryLevel
            return if (level < 0f) null else (level * 100).toInt()
        }
        trySend(pct())
        val observer = NSNotificationCenter.defaultCenter.addObserverForName(
            name = UIDeviceBatteryLevelDidChangeNotification,
            `object` = device,
            queue = null,
        ) { _ -> trySend(pct()) }
        awaitClose {
            NSNotificationCenter.defaultCenter.removeObserver(observer)
            device.batteryMonitoringEnabled = false
        }
    }
}

/** Free MB via `NSFileManager` `NSFileSystemFreeSize` on the home volume. */
@OptIn(ExperimentalForeignApi::class)
internal class IosStorageMonitor : StorageMonitor {
    override fun freeDiskMb(): Flow<Long?> = flow {
        emit(
            runCatching {
                val attrs = NSFileManager.defaultManager.attributesOfFileSystemForPath(NSHomeDirectory(), null)
                (attrs?.get(NSFileSystemFreeSize) as? NSNumber)?.longLongValue?.div(1024L * 1024L)
            }.getOrNull(),
        )
    }
}
