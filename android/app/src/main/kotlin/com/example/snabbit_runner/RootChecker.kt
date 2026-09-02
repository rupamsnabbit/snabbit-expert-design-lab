package com.example.snabbit_runner

import android.content.Context
import android.os.Build
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class RootChecker(private val context: Context) {

 data class RootStatusResult(
        val isRooted: Boolean,
        val reason: String?
    )

    fun checkRootWithReason(): RootStatusResult {
        checkBuildTagsReason()?.let { return RootStatusResult(true, it) }
        checkSuExistsReason()?.let { return RootStatusResult(true, it) }
        checkDangerousAppsReason()?.let { return RootStatusResult(true, it) }
        checkSELinuxReason()?.let { return RootStatusResult(true, it) }
        checkSystemWritableReason()?.let { return RootStatusResult(true, it) }
        checkBusyBoxReason()?.let { return RootStatusResult(true, it) }
        return RootStatusResult(false, null)
    }
    private fun checkBuildTagsReason(): String? {
        val buildTags = Build.TAGS ?: return null
        return if (buildTags.contains("test-keys")) {
            "Build tags contain 'test-keys': $buildTags"
        } else null
    }
    private fun checkSuExistsReason(): String? {
        val paths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su-backup",
            "/system/xbin/mu"
        )
        val foundPath = paths.firstOrNull { File(it).exists() }
        return foundPath?.let { "su binary found at: $it" }
    }
    private fun checkDangerousAppsReason(): String? {
        val packages = arrayOf(
            "com.noshufou.android.su",
            "com.thirdparty.superuser",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.topjohnwu.magisk"
        )
        val pm = context.packageManager
        for (pkg in packages) {
            try {
                pm.getPackageInfo(pkg, 0)
                return "Root-related package installed: $pkg"
            } catch (_: Exception) {
                // keep checking
            }
        }
        return null
    }
    private fun checkSELinuxReason(): String? {
        return try {
            val process = Runtime.getRuntime().exec("getenforce")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val res = reader.readLine()
            // If it's not enforcing, consider it rooted
            if (res != null && res != "Enforcing") {
                "SELinux not enforcing: $res"
            } else null
        } catch (_: Exception) {
            null
        }
    }
    private fun checkSystemWritableReason(): String? {
        return if (File("/system").canWrite()) {
            "/system is writable"
        } else null
    }
    private fun checkBusyBoxReason(): String? {
        val paths = arrayOf(
            "/system/bin/busybox",
            "/system/xbin/busybox",
            "/sbin/busybox",
            "/system/sd/xbin/busybox",
            "/system/bin/failsafe/busybox",
            "/data/local/xbin/busybox",
            "/data/local/bin/busybox",
            "/data/local/busybox"
        )
        paths.firstOrNull { File(it).exists() }?.let { found ->
            return "busybox found at: $found"
        }
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "busybox"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val whichOutput = reader.readLine()
            whichOutput?.let { out ->
                if (out.isNotBlank()) "busybox in PATH: $out" else null
            }
        } catch (_: Exception) {
            null
        }
    }
}