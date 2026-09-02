package com.snabbit.runner.shared.core.device

import kotlinx.coroutines.flow.Flow

/** Battery charge 0–100 (null = unknown). Reactive on Android; point-read on iOS. */
interface BatteryMonitor {
    fun batteryPercent(): Flow<Int?>
}

/** Free space (MB) on the volume that holds the app's recordings (null = unknown). */
interface StorageMonitor {
    fun freeDiskMb(): Flow<Long?>
}
