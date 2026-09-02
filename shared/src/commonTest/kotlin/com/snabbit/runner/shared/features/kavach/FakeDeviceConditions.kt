package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.device.BatteryMonitor
import com.snabbit.runner.shared.core.device.StorageMonitor
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

class FakeBatteryMonitor(pct: Int? = null) : BatteryMonitor {
    val flow = MutableStateFlow(pct)
    override fun batteryPercent(): Flow<Int?> = flow
}

class FakeStorageMonitor(freeMb: Long? = null) : StorageMonitor {
    val flow = MutableStateFlow(freeMb)
    override fun freeDiskMb(): Flow<Long?> = flow
}
