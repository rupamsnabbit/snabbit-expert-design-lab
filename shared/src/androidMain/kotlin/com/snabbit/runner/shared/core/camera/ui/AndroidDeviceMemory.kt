package com.snabbit.runner.shared.core.camera.ui

import android.app.ActivityManager
import android.content.Context

/** Treat < 10% of device RAM free as "low" (in addition to the system flag). */
private const val LOW_MEM_RATIO = 0.10

/**
 * Android [DeviceMemory] backed by [ActivityManager.MemoryInfo].
 *
 * Bound in `platformModule` with the application [Context] (`androidContext()`).
 * Reads the system low-memory flag plus a "< 10% free" ratio check.
 */
class AndroidDeviceMemory(private val context: Context) : DeviceMemory {
    override fun isLow(): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        val lowByRatio = info.totalMem > 0 &&
            info.availMem.toDouble() / info.totalMem.toDouble() < LOW_MEM_RATIO
        return info.lowMemory || lowByRatio
    }
}
