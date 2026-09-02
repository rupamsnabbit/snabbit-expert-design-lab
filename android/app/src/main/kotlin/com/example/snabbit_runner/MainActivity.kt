package com.snabbit.runner

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.example.snabbit_runner.RootChecker
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import com.snabbit.runner.compose_overlay.plugin.ComposeOverlayPlugin
import com.snabbit.runner.debug.ChuckerDebug
import com.snabbit.runner.kmp_bridge.AnalyticsPlugin
import com.snabbit.runner.kmp_bridge.AppConfigPlugin
import com.snabbit.runner.kmp_bridge.AuthPlugin
import com.snabbit.runner.kmp_bridge.CrashReporterPlugin
import com.snabbit.runner.kmp_bridge.DeeplinkPlugin
import com.snabbit.runner.kmp_bridge.JobScreenLauncherPlugin
import com.snabbit.runner.kmp_bridge.KmpHelloPlugin
import com.snabbit.runner.kmp_bridge.LanguagePlugin
import com.snabbit.runner.kmp_bridge.LocalizationPlugin
import com.snabbit.runner.kmp_bridge.NetworkConfigPlugin
import com.snabbit.runner.kmp_bridge.OverlayLauncherPlugin
import com.snabbit.runner.kmp_bridge.ProfileActionsPlugin
import com.snabbit.runner.kmp_bridge.ProfileSyncPlugin
import com.snabbit.runner.kmp_bridge.RealtimePlugin
import com.snabbit.runner.kmp_bridge.RunnerStatePlugin
import com.snabbit.runner.navigation.bridge.NavigationBridgePlugin
import com.snabbit.runner.remoteconfig.bridge.RemoteConfigBridgePlugin

class MainActivity: FlutterFragmentActivity() {
    private val FOREGROUND_CHANNEL = "com.snabbit.runner/foreground"
    private val PIP_CHANNEL = "com.snabbit.runner/pip"
    private val APP_CHECK_CHANNEL = "com.snabbit.runner/app_check"
    private var pipMethodChannel: MethodChannel? = null

    // PiP gate. Default false (fail-closed): PiP stays off until a cohort turns it on.
    // The Flutter cohort pushes true on home mount (PartnerHome); the MQTT/KMP cohort
    // leaves/forces it false — entering PiP on this Flutter Activity while the KMP host
    // (NavigationHostActivity) is alive fractures the task into two surfaces (ECPO-852).
    // Phase 2 will unify PiP across both hosts. Toggled from Dart via the `setPipEnabled`
    // method on PIP_CHANNEL; read only on the main thread (onUserLeaveHint / channel).
    private var pipEnabled: Boolean = false

    private val securityChannel = "com.snabbit.runner/security"
    private val qaProxyChannel = "com.snabbit.runner/qa_proxy"
    private lateinit var rootChecker: RootChecker

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Plugin registrations — kept directly under super so a future
        // reader can see at a glance which plugins this Activity wires
        // into the engine without scanning the rest of the method.
        ComposeOverlayPlugin.registerWith(flutterEngine, this)
        // KMP shared module — one plugin per concern. Koin is already
        // running (SnabbitRunnerApplication.onCreate ran before us), so
        // each plugin resolves its dependencies via `by inject()` on
        // attach.
        flutterEngine.plugins.add(KmpHelloPlugin())
        flutterEngine.plugins.add(NetworkConfigPlugin())
        flutterEngine.plugins.add(AuthPlugin())
        flutterEngine.plugins.add(LanguagePlugin())
        flutterEngine.plugins.add(LocalizationPlugin())
        flutterEngine.plugins.add(JobScreenLauncherPlugin())
        flutterEngine.plugins.add(OverlayLauncherPlugin())
        flutterEngine.plugins.add(AnalyticsPlugin())
        flutterEngine.plugins.add(CrashReporterPlugin())
        flutterEngine.plugins.add(DeeplinkPlugin())
        flutterEngine.plugins.add(RunnerStatePlugin())
        flutterEngine.plugins.add(RealtimePlugin())
        flutterEngine.plugins.add(RemoteConfigBridgePlugin())
        flutterEngine.plugins.add(ProfileActionsPlugin())
        flutterEngine.plugins.add(ProfileSyncPlugin())
        flutterEngine.plugins.add(AppConfigPlugin())
        flutterEngine.plugins.add(NavigationBridgePlugin())

        // Debug-only: bridge for the native Chucker button's "Flutter (Dio)" action → opens
        // chucker_flutter's inspector. No-op in release. #chucker
        ChuckerDebug.registerFlutterBridge(flutterEngine)

        // QA network debugging (Charles / Proxyman / mitmproxy): expose the device's
        // manual Wi-Fi proxy so debug builds can route Dart/Dio through it — Dart's
        // HttpClient ignores the system proxy + network-security-config (OkHttp/Ktor
        // pick it up automatically). Read via ProxySelector, the same source OkHttp
        // uses. Only the Dart side, in kDebugMode, calls this; an inert read in release.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, qaProxyChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getHttpProxy") {
                    val proxy: String? = try {
                        java.net.ProxySelector.getDefault()
                            ?.select(java.net.URI("https://runner-apis.snabbit.com"))
                            ?.firstOrNull { it.type() == java.net.Proxy.Type.HTTP }
                            ?.let { it.address() as? java.net.InetSocketAddress }
                            ?.let { addr ->
                                addr.hostString?.let { host -> "$host:${addr.port}" }
                            }
                    } catch (e: Exception) {
                        android.util.Log.w("MainActivity", "QA proxy read failed", e)
                        null
                    }
                    result.success(proxy)
                } else {
                    result.notImplemented()
                }
            }
        // core/permissions: Koin now starts in SnabbitRunnerApplication, so the
        // PermissionManager resolves. When a consumer (e.g. the location module) needs the
        // permission system, attach the Activity here so Grant's launcher + the strict-settings
        // launcher register (must run before STARTED), and detach in onDestroy:
        //     GlobalContext.getOrNull()?.get<ActivityAttachable>()?.attachActivity(this)  // onCreate
        //     GlobalContext.getOrNull()?.get<ActivityAttachable>()?.detach()              // onDestroy
        // Not wired yet — no native caller consumes permissions in this build.

        rootChecker = RootChecker(this)

        // Existing foreground channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToForeground" -> {
                    val success = bringAppToForeground()
                    result.success(success)
                }
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // App check channel - checks if specific packages are installed
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(isAppInstalled(packageName))
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // New PiP channel
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPiP" -> {
                    val success = startPictureInPictureMode()
                    result.success(success)
                }
                "setPipEnabled" -> {
                    // Cohort gate (Phase 1): Dart pushes false for the MQTT/KMP cohort
                    // and true for the Flutter cohort. Missing arg defaults to off.
                    pipEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(null)
                }
                "isPiPSupported" -> {
                    result.success(isPictureInPictureSupported())
                }
                "isPiPMode" -> {
                    result.success(isInPictureInPictureMode)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->

                if (call.method == "isRootedWithReason") {
                    val check = rootChecker.checkRootWithReason()
                    result.success(mapOf(
                        "is_rooted" to check.isRooted,
                        "reason" to check.reason
                    ))
                } else {
                    result.notImplemented()
                }
            }

        // Listen for overlay tap messages to bring app to foreground
        val overlayMessenger = BasicMessageChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "x-slayer/overlay_messenger",
            JSONMessageCodec.INSTANCE
        )
        overlayMessenger.setMessageHandler { message, reply ->
            if (message == "launch_main_app") {
                bringAppToForeground()
                reply.reply(null)
            } else {
                reply.reply(null)
            }
        }

    }

    private fun bringAppToForeground(): Boolean {
        return try {
            // Method 1: Use ActivityManager to bring app to front
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val appTasks = activityManager.appTasks
            if (appTasks.isNotEmpty()) {
                appTasks[0].moveToFront()
                return true
            }

            // Method 2: Use intent with reorder flags
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or 
                        Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // PiP-related methods
    private fun isPictureInPictureSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else {
            false
        }
    }

    private fun startPictureInPictureMode(): Boolean {
        // Single choke point for every PiP entry (onUserLeaveHint + the enterPiP
        // channel). When the cohort has disabled PiP, no-op so backgrounding never
        // fractures the task into a Flutter PiP window + a stranded KMP host surface.
        if (!pipEnabled) return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPictureInPictureSupported()) {
                // Check if activity is valid and not finishing/destroyed before entering PiP
                if (isFinishing || isDestroyed) {
                    return false
                }
                
                val aspectRatio = Rational(1, 1) // 1:1 aspect ratio for smaller, square PiP
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()
                
                enterPictureInPictureMode(params)
            } else {
                false
            }
        } catch (e: IllegalStateException) {
            // Activity is not available or in invalid state
            e.printStackTrace()
            false
        } catch (e: Exception) {
            // Handle any other exceptions
            e.printStackTrace()
            false
        }
    }

    // launchMode is singleTop, so a OneLink that opens the already-running app
    // arrives via onNewIntent. AppsFlyer's UDL reads the activity intent on the
    // next resume — without refreshing it here it reads the stale launch intent
    // and logs "No deep link detected". setIntent() hands UDL the fresh link.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        if (!isInPictureInPictureMode && !isFinishing && !isDestroyed) {
            // Defer requestLayout to the next frame to give the window manager
            // time to update dimensions after PiP exit. Works around timing
            // races where Flutter's viewport metrics haven't updated yet.
            window?.decorView?.let { decorView ->
                decorView.post {
                    if (!isDestroyed) {
                        decorView.requestLayout()
                    }
                }
            }
        }

        // Notify Flutter about PiP mode change
        pipMethodChannel?.invokeMethod("onPiPModeChanged", mapOf(
            "isInPiPMode" to isInPictureInPictureMode
        ))
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Auto-enter PiP when user presses home button
        // Only attempt if activity is valid and not finishing
        if (!isFinishing && !isDestroyed) {
            startPictureInPictureMode()
        }
    }

    // Check if a specific app is installed (requires <queries> in manifest)
    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

}

